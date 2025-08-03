// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Token
 * @dev CoreLiquid Protocol Token with advanced features
 */
contract Token is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ERC20Permit, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 100 million tokens
    
    // Token distribution
    uint256 public constant TEAM_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant ECOSYSTEM_ALLOCATION = 300_000_000 * 10**18; // 30%
    uint256 public constant TREASURY_ALLOCATION = 200_000_000 * 10**18; // 20%
    uint256 public constant LIQUIDITY_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant STAKING_REWARDS_ALLOCATION = 200_000_000 * 10**18; // 20%
    
    // Vesting and lock periods
    uint256 public constant TEAM_VESTING_DURATION = 4 * 365 days; // 4 years
    uint256 public constant TEAM_CLIFF_DURATION = 365 days; // 1 year cliff
    uint256 public constant ECOSYSTEM_VESTING_DURATION = 3 * 365 days; // 3 years
    
    // Addresses for token distribution
    address public teamWallet;
    address public ecosystemWallet;
    address public treasuryWallet;
    address public liquidityWallet;
    address public stakingRewardsWallet;
    
    // Vesting tracking
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revoked;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public isVestingBeneficiary;
    
    // Transfer restrictions
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isWhitelisted;
    bool public transferRestrictionsEnabled = false;
    
    // Fee mechanism
    uint256 public transferFee = 0; // Basis points (0 = no fee)
    uint256 public constant MAX_TRANSFER_FEE = 1000; // 10% max
    address public feeRecipient;
    mapping(address => bool) public feeExempt;
    
    // Staking integration
    address public stakingContract;
    mapping(address => uint256) public stakedBalances;
    
    // Events
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    );
    
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unreleased);
    event TransferFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event TransferRestrictionsToggled(bool enabled);
    event StakingContractUpdated(address oldContract, address newContract);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol,
        address _teamWallet,
        address _ecosystemWallet,
        address _treasuryWallet,
        address _liquidityWallet,
        address _stakingRewardsWallet
    ) ERC20(name, symbol) ERC20Permit(name) {
        require(_teamWallet != address(0), "Token: invalid team wallet");
        require(_ecosystemWallet != address(0), "Token: invalid ecosystem wallet");
        require(_treasuryWallet != address(0), "Token: invalid treasury wallet");
        require(_liquidityWallet != address(0), "Token: invalid liquidity wallet");
        require(_stakingRewardsWallet != address(0), "Token: invalid staking rewards wallet");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        
        teamWallet = _teamWallet;
        ecosystemWallet = _ecosystemWallet;
        treasuryWallet = _treasuryWallet;
        liquidityWallet = _liquidityWallet;
        stakingRewardsWallet = _stakingRewardsWallet;
        
        feeRecipient = _treasuryWallet;
        
        // Mint initial supply to deployer
        _mint(msg.sender, INITIAL_SUPPLY);
        
        // Set up vesting schedules
        _setupVestingSchedules();
        
        // Exempt system addresses from fees
        feeExempt[msg.sender] = true;
        feeExempt[_treasuryWallet] = true;
        feeExempt[_liquidityWallet] = true;
        feeExempt[_stakingRewardsWallet] = true;
    }
    
    /**
     * @dev Mint tokens (only minters)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Token: exceeds max supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens from specific account (only burners)
     */
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
    
    /**
     * @dev Release vested tokens for a beneficiary
     */
    function releaseVestedTokens(address beneficiary) external nonReentrant {
        require(isVestingBeneficiary[beneficiary], "Token: not a vesting beneficiary");
        
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "Token: vesting revoked");
        
        uint256 releasableAmount = _calculateReleasableAmount(beneficiary);
        require(releasableAmount > 0, "Token: no tokens to release");
        
        schedule.releasedAmount += releasableAmount;
        _mint(beneficiary, releasableAmount);
        
        emit TokensReleased(beneficiary, releasableAmount);
    }
    
    /**
     * @dev Revoke vesting schedule (admin only)
     */
    function revokeVesting(address beneficiary) external onlyRole(ADMIN_ROLE) {
        require(isVestingBeneficiary[beneficiary], "Token: not a vesting beneficiary");
        
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "Token: already revoked");
        
        uint256 releasableAmount = _calculateReleasableAmount(beneficiary);
        uint256 unreleased = schedule.totalAmount - schedule.releasedAmount - releasableAmount;
        
        schedule.revoked = true;
        
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            _mint(beneficiary, releasableAmount);
            emit TokensReleased(beneficiary, releasableAmount);
        }
        
        emit VestingRevoked(beneficiary, unreleased);
    }
    
    /**
     * @dev Stake tokens
     */
    function stake(uint256 amount) external nonReentrant {
        require(stakingContract != address(0), "Token: staking not available");
        require(amount > 0, "Token: invalid amount");
        require(balanceOf(msg.sender) >= amount, "Token: insufficient balance");
        
        _transfer(msg.sender, stakingContract, amount);
        stakedBalances[msg.sender] += amount;
        
        emit TokensStaked(msg.sender, amount);
    }
    
    /**
     * @dev Unstake tokens (called by staking contract)
     */
    function unstake(address user, uint256 amount) external {
        require(msg.sender == stakingContract, "Token: only staking contract");
        require(stakedBalances[user] >= amount, "Token: insufficient staked balance");
        
        stakedBalances[user] -= amount;
        _transfer(stakingContract, user, amount);
        
        emit TokensUnstaked(user, amount);
    }
    
    /**
     * @dev Get releasable vested amount
     */
    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _calculateReleasableAmount(beneficiary);
    }
    
    /**
     * @dev Get vesting schedule info
     */
    function getVestingSchedule(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revoked
    ) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.cliffDuration,
            schedule.revoked
        );
    }
    
    /**
     * @dev Set transfer fee
     */
    function setTransferFee(uint256 _transferFee) external onlyRole(ADMIN_ROLE) {
        require(_transferFee <= MAX_TRANSFER_FEE, "Token: fee too high");
        uint256 oldFee = transferFee;
        transferFee = _transferFee;
        emit TransferFeeUpdated(oldFee, _transferFee);
    }
    
    /**
     * @dev Set fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Token: invalid recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }
    
    /**
     * @dev Set fee exemption status
     */
    function setFeeExempt(address account, bool exempt) external onlyRole(ADMIN_ROLE) {
        feeExempt[account] = exempt;
    }
    
    /**
     * @dev Update blacklist status
     */
    function setBlacklisted(address account, bool blacklisted) external onlyRole(ADMIN_ROLE) {
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }
    
    /**
     * @dev Update whitelist status
     */
    function setWhitelisted(address account, bool whitelisted) external onlyRole(ADMIN_ROLE) {
        isWhitelisted[account] = whitelisted;
        emit WhitelistUpdated(account, whitelisted);
    }
    
    /**
     * @dev Toggle transfer restrictions
     */
    function setTransferRestrictionsEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        transferRestrictionsEnabled = enabled;
        emit TransferRestrictionsToggled(enabled);
    }
    
    /**
     * @dev Set staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyRole(ADMIN_ROLE) {
        address oldContract = stakingContract;
        stakingContract = _stakingContract;
        if (_stakingContract != address(0)) {
            feeExempt[_stakingContract] = true;
        }
        emit StakingContractUpdated(oldContract, _stakingContract);
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Override transfer function to include fees and restrictions
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        // Check restrictions
        if (transferRestrictionsEnabled) {
            require(!isBlacklisted[from] && !isBlacklisted[to], "Token: blacklisted address");
            if (!isWhitelisted[from] && !isWhitelisted[to]) {
                require(isWhitelisted[from] || isWhitelisted[to], "Token: not whitelisted");
            }
        }
        
        // Handle fees for regular transfers (not minting/burning)
        if (from != address(0) && to != address(0) && transferFee > 0 && !feeExempt[from] && !feeExempt[to]) {
            uint256 fee = (value * transferFee) / 10000;
            if (fee > 0) {
                super._update(from, feeRecipient, fee);
                value -= fee;
            }
        }
        
        super._update(from, to, value);
    }
    
    /**
     * @dev Calculate releasable vested amount
     */
    function _calculateReleasableAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        
        if (schedule.revoked || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        uint256 elapsedTime = block.timestamp - schedule.startTime;
        if (elapsedTime >= schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }
        
        uint256 vestedAmount = (schedule.totalAmount * elapsedTime) / schedule.duration;
        return vestedAmount - schedule.releasedAmount;
    }
    
    /**
     * @dev Setup initial vesting schedules
     */
    function _setupVestingSchedules() internal {
        // Team vesting: 4 years with 1 year cliff
        _createVestingSchedule(
            teamWallet,
            TEAM_ALLOCATION,
            block.timestamp,
            TEAM_VESTING_DURATION,
            TEAM_CLIFF_DURATION
        );
        
        // Ecosystem vesting: 3 years, no cliff
        _createVestingSchedule(
            ecosystemWallet,
            ECOSYSTEM_ALLOCATION,
            block.timestamp,
            ECOSYSTEM_VESTING_DURATION,
            0
        );
        
        // Immediate allocations (no vesting)
        _mint(treasuryWallet, TREASURY_ALLOCATION);
        _mint(liquidityWallet, LIQUIDITY_ALLOCATION);
        _mint(stakingRewardsWallet, STAKING_REWARDS_ALLOCATION);
    }
    
    /**
     * @dev Create vesting schedule
     */
    function _createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) internal {
        require(beneficiary != address(0), "Token: invalid beneficiary");
        require(totalAmount > 0, "Token: invalid amount");
        require(duration > 0, "Token: invalid duration");
        require(cliffDuration <= duration, "Token: cliff too long");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revoked: false
        });
        
        isVestingBeneficiary[beneficiary] = true;
        
        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            duration,
            cliffDuration
        );
    }
    
    /**
     * @dev Emergency function to recover stuck tokens
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(this), "Token: cannot withdraw own tokens");
        IERC20(token).transfer(to, amount);
    }
    
    /**
     * @dev Get circulating supply (total supply minus locked tokens)
     */
    function getCirculatingSupply() external view returns (uint256) {
        uint256 lockedTokens = 0;
        
        // Add unvested tokens
        if (isVestingBeneficiary[teamWallet]) {
            VestingSchedule storage teamSchedule = vestingSchedules[teamWallet];
            if (!teamSchedule.revoked) {
                lockedTokens += teamSchedule.totalAmount - teamSchedule.releasedAmount;
            }
        }
        
        if (isVestingBeneficiary[ecosystemWallet]) {
            VestingSchedule storage ecosystemSchedule = vestingSchedules[ecosystemWallet];
            if (!ecosystemSchedule.revoked) {
                lockedTokens += ecosystemSchedule.totalAmount - ecosystemSchedule.releasedAmount;
            }
        }
        
        return totalSupply() - lockedTokens;
    }
}
