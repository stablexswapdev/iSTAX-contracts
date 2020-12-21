
// SPDX-License-Identifier: MIT
// A modification to the original Sushichef Type contract


pragma solidity ^0.6.12;

import ".ERC20TokenToken.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";


interface IMigratorChef {
    // Perform Deposits token migration for any future StableXswap upgrades if they may occur
    // Take the current Deposits token address and return the new Deposits token address.
    // Migrator should have full access to the caller's Deposits token.
    // Return the new Deposits token address.
    //
    // Migrator must have allowance access to Old StableXswap tokens.
    // the new Swap's Deposits must mint EXACTLY the same amount of Deposits tokens or
    // else something bad will happen. 
    function migrate(IERC20 token) external returns (IERC20);
}
                         

contract ERC20TokenIssuer is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ERC20Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accERC20TokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws Deposits tokens to a pool. Here's what happens:
        //   1. The pool's `accERC20TokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 depositToken;           // Address of deposit token contract.
        uint256 allocPoint;       // How many allocation points (distribution weight) assigned to this pool.
        uint256 lastRewardBlock;  // Last block number that ERC20Tokens distribution occurs.
        uint256 accERC20TokenPerShare; // Accumulated ERC20Tokens per share, times 1e12. See below.
    }

    // The ERC20Token TOKEN!
    ERC20TokenToken public ERC20Token;
    // Dev address.
    address public devaddr;
    // Block number when first bonus ERC20Token period ends.
    uint256 public firstBonusEndBlock;
    // ERC20Token tokens created per block.
    uint256 public ERC20TokenPerBlock;
    // min ERC20Token tokens created per block 
      uint256 public MinERC20TokenPerBlock;
    // Bonus muliplier for early ERC20Token earners.
    uint256 public constant BONUS_MULTIPLIER = 8;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes Deposits tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ERC20Token mining starts.
    uint256 public startBlock;
    // The number of blocks between halvings
    uint256 public halvingDuration;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ERC20TokenToken _ERC20Token,
        address _devaddr,
        uint256 _ERC20TokenPerBlock,
        uint256 _MinERC20TokenPerBlock,
        uint256 _startBlock,
        uint256 _firstBonusEndBlock,
        uint256 _halvingDuration
    ) public {
        ERC20Token = _ERC20Token;
        devaddr = _devaddr;
        ERC20TokenPerBlock = _ERC20TokenPerBlock;
        MinERC20TokenPerBlock = _MinERC20TokenPerBlock;
        firstBonusEndBlock = _firstBonusEndBlock;
        halvingDuration = _halvingDuration;
        startBlock = _startBlock;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate Deposits token to another Deposits contract. Can be called by anyone. We trust that migrator contract is good.
    // This is only relevant for Depositss if StableXswap features an upgrade in the future.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 depositToken = pool.depositToken;
        uint256 bal = depositToken.balanceOf(address(this));
        depositToken.safeApprove(address(migrator), bal);
        IERC20 newdepositToken = migrator.migrate(depositToken);
        // Modified to allow the migration to happen if the new balances are more than before
        require(bal <= newdepositToken.balanceOf(address(this)), "migrate failure, not enough tokens");
        pool.depositToken = newdepositToken;
    }

    // useful to check how many pools exist
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new Token to the pool. Can only be called by the owner.
    // XXX DO NOT add the same Deposits token more than once. Rewards will be messed up if you do and split
    function add(uint256 _allocPoint, IERC20 _depositToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            // Update Pool Logic
            depositToken: _depositToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accERC20TokenPerShare: 0
        }));
    }

    // Update the given pool's ERC20Token allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    // Modified from original sushiswap code to allow for halving logic
        function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= firstBonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        }
        else {
            uint currentMultiplier = BONUS_MULTIPLIER;
            uint prevEpochBlock = firstBonusEndBlock;
            uint accruedBlockCredit = 0;
            while (currentMultiplier >= MinERC20TokenPerBlock) {
                uint periods = _to.sub(_from).mod(halvingDuration).div(halvingDuration);
                for (uint i=0; i < periods; i++) {
                    accruedBlockCredit = accruedBlockCredit.add(currentMultiplier.mul(halvingDuration));
                    // Reduce the Multiplier by half
                    currentMultiplier.div(2);
                    prevEpochBlock = prevEpochBlock.add(halvingDuration);
                    }
                }
            accruedBlockCredit = accruedBlockCredit.add(currentMultiplier.mul(_to.sub(prevEpochBlock)));
            return accruedBlockCredit;
            }
    }

    // View function to see pending ERC20Tokens on frontend.
    function pendingERC20Token(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accERC20TokenPerShare = pool.accERC20TokenPerShare;
        uint256 DepositsSupply = pool.depositToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && DepositsSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 ERC20TokenReward = multiplier.mul(ERC20TokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accERC20TokenPerShare = accERC20TokenPerShare.add(ERC20TokenReward.mul(1e12).div(DepositsSupply));
        }
        return user.amount.mul(accERC20TokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 DepositsSupply = pool.depositToken.balanceOf(address(this));
        if (DepositsSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 ERC20TokenReward = multiplier.mul(ERC20TokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        // removed the mint additional token to dev because this is already done in the original distributor
        // ERC20Token.mint(devaddr, ERC20TokenReward.div(8));

        // Instead of mint, we withdraw tokens from ERC20Token
        // ERC20Token.mint(address(this), ERC20TokenReward);
        // Transfers tokens from the devaddr (Dev Address must approve this distributor to allow for these tokens to be sent to the Chef)
        ERC20Token.transferFrom(devaddr, address(this), ERC20TokenReward);
          
        pool.accERC20TokenPerShare = pool.accERC20TokenPerShare.add(ERC20TokenReward.mul(1e12).div(DepositsSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit Deposits tokens to ERC20TokenIssuer for ERC20Token allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accERC20TokenPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                // Give user their accrued mined ERC20Token tokens on deposit
                safeERC20TokenTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.depositToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accERC20TokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw Deposits or other tokens from ERC20Tokenissuer.
    // Fixed to prevent reentrancy
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accERC20TokenPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeERC20TokenTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.depositToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accERC20TokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    // Updated to prevent reentrancy by first saving and updating all state variables before the safeTransfer
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.depositToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        
    }

    // Safe ERC20Token transfer function, just in case if rounding error causes pool to not have enough ERC20Tokens.
    function safeERC20TokenTransfer(address _to, uint256 _amount) internal {
        uint256 ERC20TokenBal = ERC20Token.balanceOf(address(this));
        if (_amount > ERC20TokenBal) {
            ERC20Token.transfer(_to, ERC20TokenBal);
        } else {
            ERC20Token.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}