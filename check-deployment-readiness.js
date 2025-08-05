#!/usr/bin/env node

/**
 * CoreLiquid Deployment Readiness Checker
 * Memverifikasi semua konfigurasi sebelum deployment ke Vercel
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class DeploymentChecker {
  constructor() {
    this.projectRoot = __dirname;
    this.errors = [];
    this.warnings = [];
    this.checks = [];
  }

  printHeader() {
    console.log('\n🔍 ===== CoreLiquid Deployment Readiness Check =====');
    console.log('🎯 Verifying configuration for Vercel deployment\n');
  }

  addCheck(name, status, message = '') {
    this.checks.push({ name, status, message });
    const icon = status === 'pass' ? '✅' : status === 'warn' ? '⚠️' : '❌';
    console.log(`${icon} ${name}${message ? ': ' + message : ''}`);
  }

  addError(message) {
    this.errors.push(message);
  }

  addWarning(message) {
    this.warnings.push(message);
  }

  checkFileExists(filePath, description) {
    const exists = fs.existsSync(filePath);
    this.addCheck(
      description,
      exists ? 'pass' : 'fail',
      exists ? 'Found' : 'Missing'
    );
    return exists;
  }

  checkPackageJson() {
    console.log('\n📦 Package Configuration');
    
    const packagePath = path.join(this.projectRoot, 'package.json');
    if (!this.checkFileExists(packagePath, 'package.json')) {
      this.addError('package.json is required for deployment');
      return;
    }

    try {
      const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      
      // Check required scripts
      const requiredScripts = ['build', 'start', 'dev'];
      requiredScripts.forEach(script => {
        if (packageJson.scripts && packageJson.scripts[script]) {
          this.addCheck(`Script: ${script}`, 'pass');
        } else {
          this.addCheck(`Script: ${script}`, 'fail', 'Missing');
          this.addError(`Missing required script: ${script}`);
        }
      });

      // Check Next.js dependency
      const hasNext = packageJson.dependencies?.next || packageJson.devDependencies?.next;
      this.addCheck('Next.js dependency', hasNext ? 'pass' : 'fail');
      
      if (!hasNext) {
        this.addError('Next.js dependency is required');
      }

    } catch (error) {
      this.addCheck('package.json parsing', 'fail', error.message);
      this.addError('Invalid package.json format');
    }
  }

  checkNextConfig() {
    console.log('\n⚙️  Next.js Configuration');
    
    const nextConfigPath = path.join(this.projectRoot, 'next.config.mjs');
    if (this.checkFileExists(nextConfigPath, 'next.config.mjs')) {
      try {
        const configContent = fs.readFileSync(nextConfigPath, 'utf8');
        
        // Check for important configurations
        if (configContent.includes('eslint')) {
          this.addCheck('ESLint configuration', 'pass');
        } else {
          this.addCheck('ESLint configuration', 'warn', 'Not configured');
        }

        if (configContent.includes('typescript')) {
          this.addCheck('TypeScript configuration', 'pass');
        } else {
          this.addCheck('TypeScript configuration', 'warn', 'Not configured');
        }

      } catch (error) {
        this.addCheck('next.config.mjs reading', 'fail', error.message);
      }
    }
  }

  checkVercelConfig() {
    console.log('\n🚀 Vercel Configuration');
    
    const vercelConfigPath = path.join(this.projectRoot, 'vercel.json');
    if (this.checkFileExists(vercelConfigPath, 'vercel.json')) {
      try {
        const vercelConfig = JSON.parse(fs.readFileSync(vercelConfigPath, 'utf8'));
        
        // Check framework
        if (vercelConfig.framework === 'nextjs') {
          this.addCheck('Framework setting', 'pass', 'Next.js');
        } else {
          this.addCheck('Framework setting', 'warn', vercelConfig.framework || 'Not set');
        }

        // Check build command
        if (vercelConfig.buildCommand) {
          this.addCheck('Build command', 'pass', vercelConfig.buildCommand);
        } else {
          this.addCheck('Build command', 'warn', 'Using default');
        }

        // Check environment variables
        if (vercelConfig.env || vercelConfig.build?.env) {
          this.addCheck('Environment variables config', 'pass');
        } else {
          this.addCheck('Environment variables config', 'warn', 'Not configured in vercel.json');
        }

      } catch (error) {
        this.addCheck('vercel.json parsing', 'fail', error.message);
        this.addError('Invalid vercel.json format');
      }
    } else {
      this.addWarning('vercel.json not found - Vercel will use defaults');
    }
  }

  checkEnvironmentVariables() {
    console.log('\n🔧 Environment Variables');
    
    const envFiles = ['.env', '.env.local', '.env.example'];
    let hasEnvFile = false;

    envFiles.forEach(envFile => {
      const envPath = path.join(this.projectRoot, envFile);
      if (fs.existsSync(envPath)) {
        hasEnvFile = true;
        this.addCheck(`${envFile}`, 'pass', 'Found');
        
        // Check critical environment variables
        const envContent = fs.readFileSync(envPath, 'utf8');
        
        const criticalVars = [
          'NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID',
          'NEXT_PUBLIC_CORE_RPC_URL',
          'NEXT_PUBLIC_CORE_CHAIN_ID'
        ];

        criticalVars.forEach(varName => {
          if (envContent.includes(varName)) {
            // Check if it has a value (not just the key)
            const match = envContent.match(new RegExp(`${varName}=(.+)`));
            if (match && match[1] && match[1].trim() && !match[1].includes('your_')) {
              this.addCheck(`${varName}`, 'pass', 'Configured');
            } else {
              this.addCheck(`${varName}`, 'warn', 'Needs value');
              this.addWarning(`${varName} needs a real value`);
            }
          } else {
            this.addCheck(`${varName}`, 'fail', 'Missing');
            this.addError(`Missing critical environment variable: ${varName}`);
          }
        });
      } else {
        this.addCheck(`${envFile}`, 'warn', 'Not found');
      }
    });

    if (!hasEnvFile) {
      this.addError('No environment files found');
    }
  }

  checkGitConfiguration() {
    console.log('\n🌿 Git Configuration');
    
    try {
      // Check if in git repo
      execSync('git status', { stdio: 'pipe', cwd: this.projectRoot });
      this.addCheck('Git repository', 'pass');

      // Check current branch
      const currentBranch = execSync('git branch --show-current', { 
        encoding: 'utf8', 
        cwd: this.projectRoot 
      }).trim();
      
      this.addCheck('Current branch', 'pass', currentBranch);
      
      if (currentBranch === 'implementation') {
        this.addCheck('Target branch', 'pass', 'On implementation branch');
      } else {
        this.addCheck('Target branch', 'warn', 'Not on implementation branch');
        this.addWarning('Consider switching to implementation branch for deployment');
      }

      // Check for uncommitted changes
      try {
        execSync('git diff --exit-code', { stdio: 'pipe', cwd: this.projectRoot });
        execSync('git diff --cached --exit-code', { stdio: 'pipe', cwd: this.projectRoot });
        this.addCheck('Working directory', 'pass', 'Clean');
      } catch (error) {
        this.addCheck('Working directory', 'warn', 'Has uncommitted changes');
        this.addWarning('Consider committing changes before deployment');
      }

      // Check remote
      try {
        const remotes = execSync('git remote -v', { encoding: 'utf8', cwd: this.projectRoot });
        if (remotes.includes('github.com')) {
          this.addCheck('GitHub remote', 'pass');
        } else {
          this.addCheck('GitHub remote', 'warn', 'No GitHub remote found');
          this.addWarning('Vercel works best with GitHub repositories');
        }
      } catch (error) {
        this.addCheck('Git remote', 'fail', 'No remotes configured');
      }

    } catch (error) {
      this.addCheck('Git repository', 'fail', 'Not a git repository');
      this.addError('Project must be in a git repository for Vercel deployment');
    }
  }

  checkBuildProcess() {
    console.log('\n🏗️  Build Process');
    
    try {
      console.log('   Testing build process...');
      execSync('npm run build', { 
        stdio: 'pipe', 
        cwd: this.projectRoot,
        timeout: 120000 // 2 minutes timeout
      });
      this.addCheck('Build process', 'pass', 'Successful');
      
      // Check if .next directory was created
      const nextDir = path.join(this.projectRoot, '.next');
      if (fs.existsSync(nextDir)) {
        this.addCheck('Build output', 'pass', '.next directory created');
      } else {
        this.addCheck('Build output', 'fail', '.next directory not found');
      }
      
    } catch (error) {
      this.addCheck('Build process', 'fail', 'Failed');
      this.addError('Build process failed - fix build errors before deployment');
      console.log('   Build error details:', error.message);
    }
  }

  checkDependencies() {
    console.log('\n📚 Dependencies');
    
    try {
      console.log('   Checking dependencies...');
      execSync('npm ls --depth=0', { 
        stdio: 'pipe', 
        cwd: this.projectRoot 
      });
      this.addCheck('Dependencies', 'pass', 'All installed');
    } catch (error) {
      this.addCheck('Dependencies', 'warn', 'Some issues found');
      this.addWarning('Run npm install to fix dependency issues');
    }

    // Check for security vulnerabilities
    try {
      execSync('npm audit --audit-level=high', { 
        stdio: 'pipe', 
        cwd: this.projectRoot 
      });
      this.addCheck('Security audit', 'pass', 'No high-risk vulnerabilities');
    } catch (error) {
      this.addCheck('Security audit', 'warn', 'Vulnerabilities found');
      this.addWarning('Run npm audit fix to address security issues');
    }
  }

  printSummary() {
    console.log('\n📊 ===== SUMMARY =====');
    
    const passCount = this.checks.filter(c => c.status === 'pass').length;
    const warnCount = this.checks.filter(c => c.status === 'warn').length;
    const failCount = this.checks.filter(c => c.status === 'fail').length;
    
    console.log(`✅ Passed: ${passCount}`);
    console.log(`⚠️  Warnings: ${warnCount}`);
    console.log(`❌ Failed: ${failCount}`);
    
    if (this.errors.length > 0) {
      console.log('\n🚨 CRITICAL ISSUES:');
      this.errors.forEach(error => console.log(`   ❌ ${error}`));
    }
    
    if (this.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS:');
      this.warnings.forEach(warning => console.log(`   ⚠️  ${warning}`));
    }
    
    console.log('\n🎯 DEPLOYMENT READINESS:');
    if (this.errors.length === 0) {
      console.log('✅ READY FOR DEPLOYMENT!');
      console.log('\n📖 Next steps:');
      console.log('   1. Run: node setup-vercel-deployment.js');
      console.log('   2. Follow VERCEL_DEPLOYMENT_MANUAL.md');
      console.log('   3. Deploy to Vercel!');
    } else {
      console.log('❌ NOT READY - Fix critical issues first');
      console.log('\n🔧 Recommended actions:');
      console.log('   1. Fix all critical issues listed above');
      console.log('   2. Run this check again');
      console.log('   3. Proceed with deployment when ready');
    }
  }

  async run() {
    this.printHeader();
    
    this.checkPackageJson();
    this.checkNextConfig();
    this.checkVercelConfig();
    this.checkEnvironmentVariables();
    this.checkGitConfiguration();
    this.checkDependencies();
    this.checkBuildProcess();
    
    this.printSummary();
    
    // Exit with error code if there are critical issues
    if (this.errors.length > 0) {
      process.exit(1);
    }
  }
}

if (require.main === module) {
  const checker = new DeploymentChecker();
  checker.run();
}

module.exports = DeploymentChecker;