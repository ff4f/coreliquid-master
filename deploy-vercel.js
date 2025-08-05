#!/usr/bin/env node

/**
 * CoreLiquid Vercel Deployment Script
 * Script otomatis untuk deploy ke Vercel menggunakan branch advantage
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class VercelDeployer {
  constructor() {
    this.projectRoot = __dirname;
    this.targetBranch = 'advantage';
    this.envPath = path.join(__dirname, '.env');
    this.vercelEnvPath = path.join(__dirname, '.env.vercel');
  }

  printHeader() {
    console.log('\n🚀 ===== CoreLiquid Vercel Deployment =====');
    console.log(`🌿 Deploying branch: ${this.targetBranch}`);
    console.log('🎯 Target: Production deployment untuk hackathon\n');
  }

  checkPrerequisites() {
    console.log('📋 Checking Prerequisites...');
    
    // Check if we're in git repo
    try {
      execSync('git status', { stdio: 'pipe', cwd: this.projectRoot });
      console.log('✅ Git repository OK');
    } catch (error) {
      throw new Error('❌ Not in a git repository!');
    }
    
    // Check if Vercel CLI is installed
    try {
      execSync('vercel --version', { stdio: 'pipe' });
      console.log('✅ Vercel CLI OK');
    } catch (error) {
      console.log('📦 Installing Vercel CLI...');
      execSync('npm install -g vercel', { stdio: 'inherit' });
      console.log('✅ Vercel CLI installed');
    }
    
    // Check environment files
    if (!fs.existsSync(this.envPath)) {
      throw new Error('❌ File .env tidak ditemukan! Jalankan setup-walletconnect.js dulu.');
    }
    
    if (!fs.existsSync(this.vercelEnvPath)) {
      throw new Error('❌ File .env.vercel tidak ditemukan! Jalankan setup-walletconnect.js dulu.');
    }
    
    console.log('✅ Environment files OK');
  }

  getCurrentBranch() {
    try {
      const branch = execSync('git branch --show-current', { 
        encoding: 'utf8', 
        cwd: this.projectRoot 
      }).trim();
      return branch;
    } catch (error) {
      throw new Error('❌ Failed to get current branch');
    }
  }

  switchToTargetBranch() {
    const currentBranch = this.getCurrentBranch();
    console.log(`\n🌿 Current branch: ${currentBranch}`);
    
    if (currentBranch === this.targetBranch) {
      console.log(`✅ Already on ${this.targetBranch} branch`);
      return;
    }
    
    console.log(`🔄 Switching to ${this.targetBranch} branch...`);
    
    try {
      // Check if target branch exists
      execSync(`git show-ref --verify --quiet refs/heads/${this.targetBranch}`, { 
        stdio: 'pipe', 
        cwd: this.projectRoot 
      });
      
      // Branch exists, switch to it
      execSync(`git checkout ${this.targetBranch}`, { 
        stdio: 'inherit', 
        cwd: this.projectRoot 
      });
      
    } catch (error) {
      // Branch doesn't exist, create it
      console.log(`🆕 Creating new branch: ${this.targetBranch}`);
      execSync(`git checkout -b ${this.targetBranch}`, { 
        stdio: 'inherit', 
        cwd: this.projectRoot 
      });
    }
    
    console.log(`✅ Switched to ${this.targetBranch} branch`);
  }

  updateVercelConfig() {
    console.log('\n⚙️  Updating Vercel configuration...');
    
    // Create/update vercel.json
    const vercelConfig = {
      "name": "coreliquid-protocol",
      "version": 2,
      "framework": "nextjs",
      "buildCommand": "npm run build",
      "outputDirectory": ".next",
      "installCommand": "npm install",
      "devCommand": "npm run dev",
      "env": {
        "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID": "@walletconnect_project_id",
        "NEXT_PUBLIC_ENVIRONMENT": "production",
        "CORE_TESTNET_RPC_URL": "@core_testnet_rpc",
        "CORE_RPC_URL": "@core_mainnet_rpc"
      },
      "build": {
        "env": {
          "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID": "@walletconnect_project_id",
          "NEXT_PUBLIC_ENVIRONMENT": "production"
        }
      },
      "functions": {
        "app/api/**/*.js": {
          "maxDuration": 30
        }
      },
      "headers": [
        {
          "source": "/api/(.*)",
          "headers": [
            {
              "key": "Access-Control-Allow-Origin",
              "value": "*"
            },
            {
              "key": "Access-Control-Allow-Methods",
              "value": "GET, POST, PUT, DELETE, OPTIONS"
            },
            {
              "key": "Access-Control-Allow-Headers",
              "value": "Content-Type, Authorization"
            }
          ]
        }
      ],
      "rewrites": [
        {
          "source": "/api/(.*)",
          "destination": "/api/$1"
        }
      ]
    };
    
    fs.writeFileSync(
      path.join(this.projectRoot, 'vercel.json'), 
      JSON.stringify(vercelConfig, null, 2)
    );
    
    console.log('✅ vercel.json updated');
    
    // Create/update .vercelignore
    const vercelIgnore = `# Vercel Ignore
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Testing
coverage/
.nyc_output/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Build outputs
.next/
out/
build/
dist/

# Foundry
cache/
out/
broadcast/

# Hardhat
artifacts/
cache/

# Local development
.env.vercel
wallet-info.json
setup-walletconnect.js
test-ui-ux.js
deploy-vercel.js
`;
    
    fs.writeFileSync(
      path.join(this.projectRoot, '.vercelignore'), 
      vercelIgnore
    );
    
    console.log('✅ .vercelignore updated');
  }

  commitChanges() {
    console.log('\n📝 Committing changes...');
    
    try {
      // Add all changes
      execSync('git add .', { stdio: 'inherit', cwd: this.projectRoot });
      
      // Check if there are changes to commit
      try {
        execSync('git diff --cached --exit-code', { stdio: 'pipe', cwd: this.projectRoot });
        console.log('ℹ️  No changes to commit');
        return;
      } catch (error) {
        // There are changes, proceed with commit
      }
      
      // Commit changes
      const commitMessage = `feat: setup for vercel deployment on ${this.targetBranch} branch

- Add vercel.json configuration
- Add .vercelignore file
- Setup environment variables for production
- Ready for hackathon deployment`;
      
      execSync(`git commit -m "${commitMessage}"`, { 
        stdio: 'inherit', 
        cwd: this.projectRoot 
      });
      
      console.log('✅ Changes committed');
      
    } catch (error) {
      console.log('⚠️  Commit failed, but continuing...');
    }
  }

  pushToRemote() {
    console.log('\n📤 Pushing to remote repository...');
    
    try {
      execSync(`git push origin ${this.targetBranch}`, { 
        stdio: 'inherit', 
        cwd: this.projectRoot 
      });
      console.log(`✅ Pushed to origin/${this.targetBranch}`);
    } catch (error) {
      console.log('⚠️  Push failed, but continuing with deployment...');
    }
  }

  printEnvironmentSetup() {
    console.log('\n🔧 ===== VERCEL ENVIRONMENT SETUP =====');
    console.log('\n📋 Copy these environment variables to Vercel Dashboard:');
    console.log('   👉 https://vercel.com/dashboard > Project > Settings > Environment Variables\n');
    
    try {
      const vercelEnvContent = fs.readFileSync(this.vercelEnvPath, 'utf8');
      const envLines = vercelEnvContent.split('\n')
        .filter(line => line.trim() && !line.startsWith('#'))
        .map(line => {
          const [key, ...valueParts] = line.split('=');
          const value = valueParts.join('=');
          return `   ${key}=${value}`;
        });
      
      console.log('🔑 Environment Variables:');
      envLines.forEach(line => console.log(line));
      
    } catch (error) {
      console.log('❌ Failed to read .env.vercel file');
    }
    
    console.log('\n⚠️  IMPORTANT:');
    console.log('   1. Set all variables as "Production" environment');
    console.log('   2. Make sure NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID is correct');
    console.log('   3. Verify all contract addresses are for Core Testnet\n');
  }

  deployToVercel() {
    console.log('\n🚀 Deploying to Vercel...');
    
    try {
      // Login to Vercel (if not already logged in)
      try {
        execSync('vercel whoami', { stdio: 'pipe' });
        console.log('✅ Already logged in to Vercel');
      } catch (error) {
        console.log('🔐 Please login to Vercel...');
        execSync('vercel login', { stdio: 'inherit' });
      }
      
      // Deploy to production
      console.log('🚀 Starting production deployment...');
      execSync('vercel --prod --yes', { 
        stdio: 'inherit', 
        cwd: this.projectRoot 
      });
      
      console.log('\n🎉 Deployment completed!');
      
    } catch (error) {
      throw new Error(`❌ Deployment failed: ${error.message}`);
    }
  }

  printSuccessMessage() {
    console.log('\n🏆 ===== DEPLOYMENT SUCCESS! =====');
    console.log('\n✅ CoreLiquid berhasil di-deploy ke Vercel!');
    console.log(`🌿 Branch: ${this.targetBranch}`);
    console.log('🌐 Production URL akan muncul di output Vercel\n');
    
    console.log('🎯 NEXT STEPS untuk Hackathon:');
    console.log('1. 🧪 Test semua fitur di production URL');
    console.log('2. 🔗 Connect wallet ke Core Testnet');
    console.log('3. 💰 Lakukan real transactions');
    console.log('4. 📸 Screenshot/record demo');
    console.log('5. 📝 Submit ke hackathon dengan live URL\n');
    
    console.log('🔗 Useful Links:');
    console.log('   📊 Vercel Dashboard: https://vercel.com/dashboard');
    console.log('   🌐 Core Testnet Explorer: https://scan.test2.btcs.network');
    console.log('   💰 Core Testnet Faucet: https://scan.test2.btcs.network/faucet');
    console.log('   🏆 Hackathon: https://dorahacks.io/hackathon/core-connect-global-buildathon\n');
    
    console.log('🎉 Siap untuk memenangkan hackathon! 🏆');
  }

  async run() {
    try {
      this.printHeader();
      this.checkPrerequisites();
      this.switchToTargetBranch();
      this.updateVercelConfig();
      this.commitChanges();
      this.pushToRemote();
      this.printEnvironmentSetup();
      
      // Ask for confirmation before deploying
      console.log('\n❓ Ready to deploy to Vercel?');
      console.log('   Make sure you have set up environment variables in Vercel Dashboard first!');
      
      const readline = require('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      rl.question('\n🚀 Proceed with deployment? (y/N): ', (answer) => {
        rl.close();
        
        if (answer.toLowerCase() === 'y') {
          this.deployToVercel();
          this.printSuccessMessage();
        } else {
          console.log('\n⏸️  Deployment cancelled.');
          console.log('   Run this script again when ready to deploy.');
        }
      });
      
    } catch (error) {
      console.error('❌ Deployment failed:', error.message);
      process.exit(1);
    }
  }
}

// Run if called directly
if (require.main === module) {
  const deployer = new VercelDeployer();
  deployer.run();
}

module.exports = VercelDeployer;