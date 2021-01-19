// SPDX-License-Identifier: MIT
// In this contract we create a new Issuer contract that mints and distributes the new iSTAX token
// To users who stake tokens into (mainly) fixed term liquidity pools
pragma solidity ^0.6.12;

import "./lib/IERC20.sol";
import "./lib/Math.sol";
import "./lib/SafeMath.sol";
import "./iStaxToken.sol";
import "./lib/Ownable.sol";
import "./lib/SafeERC20.sol";


interface IMigratorChef {
    // Perform LP token migration for any future StableXswap upgrades if they may occur
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // Migrator must have allowance access to Old StableXswap tokens.
    // the new Swap's LP must mint EXACTLY the same amount of LP tokens or
    // else something bad will happen. 
    function migrate(IERC20 token) external returns (IERC20);
}
                         

contract iStaxIssuer is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of iStaxs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.acciStaxPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `acciStaxPerShare` (and `latestRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 depositToken;           // Address of deposit token contract.
        uint256 allocPoint;       // How many allocation points (distribution weight) assigned to this pool.
        uint256 latestRewardBlock;  // Last block number that iStaxs distribution occurs.
        uint256 acciStaxPerShare; // Accumulated iStaxs per share, times 1e12. See below.
    }

    // The iStax TOKEN!
    iStaxToken public iStax;
    // Dev address.
    address public devaddr;
    // Block number when first bonus iStax period ends.
    uint256 public firstBonusEndBlock;
    // iStax tokens created per block.
    uint256 public iStaxPerBlock;
    // min iSTAX tokens created per block 
      uint256 public MiniStaxPerBlock;
    // Bonus muliplier for early iStax earners.
    uint256 public constant BONUS_MULTIPLIER = 8;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when iStax mining starts & protocol is
    uint256 public startBlock;
    // The number of blocks between halvings
    uint256 public halvingDuration;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        iStaxToken _iStax,
        address _devaddr,
        uint256 _iStaxPerBlock,
        uint256 _MiniStaxPerBlock,
        uint256 _startBlock,
        uint256 _firstBonusEndBlock,
        uint256 _halvingDuration
    ) public {
        iStax = _iStax;
        devaddr = _devaddr;
        iStaxPerBlock = _iStaxPerBlock;
        MiniStaxPerBlock = _MiniStaxPerBlock;
        firstBonusEndBlock = _firstBonusEndBlock;
        halvingDuration = _halvingDuration;
        startBlock = _startBlock;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    // This is only relevant for LPs if StableXswap features an upgrade in the future.
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
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do and split
    function add(uint256 _allocPoint, IERC20 _depositToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        
        uint256 latestRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        
            // Update Pool Logic
        poolInfo.push(PoolInfo({
            depositToken: _depositToken,
            allocPoint: _allocPoint,
            latestRewardBlock: latestRewardBlock,
            acciStaxPerShare: 0
        }));

    }

    // Update the given pool's iStax allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }
   // Return reward multiplier over the given _from to _to block.
    // Modified from original sushiswap code to allow for halving logic
      function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256 accuredAmount) {

          uint256 currStart = Math.max(_from, startBlock); // if startBlock is less than _from, start from _from to accrue value.
          uint256 currEnd = firstBonusEndBlock; // first page
          uint256 currMultiplier = BONUS_MULTIPLIER;
          uint256 currAmount = 0;
          uint finalEnd = Math.min(_to, block.number);
          bool isDone = false; //

          if (currStart < currEnd) {
              isDone, currAmount += _getMultiplierHelperFunction(currStart, currEnd, finalEnd, currMultiplier);
              if (isDone) { return; }
              currStart = firstBonusEndBlock;
              currEnd = firstBonusEndBlock.add(halvingDuration).sub(1)b;
              accruedAmount = accruedAmount.add(currAmount);
          }

          while(!isDone) {
              isDone, accruedAmount = _getMultiplierHelperFunction(currStart, currEnd, finalEnd, currMultiplier);
              currMultiplier = currMultiplier.div(2);
              currStart = currStart.add(halvingDuration);
              currEnd = currMultiplier == 1 ? finalEnd : currEnd.add(halvingDuration);
              accruedAmount += currAmount;
          }

          return 
      }

      function _getMultiplierHelperFunction(uint256 _currStart, uint256 _currEnd, uint256 _finalEnd, uint256 _multiplier) internal view returns (bool, uint) {
        //   currEnd + 
          return (
            _currEnd >= _finalEnd,
            Math.min(_currEnd, _finalEnd).sub(_currStart).mul(_multiplier)
          )
      }
        

    // View function to see pending iStaxs on frontend.
    function pendingiStax(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 acciStaxPerShare = pool.acciStaxPerShare;
        uint256 lpSupply = pool.depositToken.balanceOf(address(this));
        if (block.number > pool.latestRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.latestRewardBlock, block.number);
            uint256 iStaxReward = multiplier.mul(iStaxPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            acciStaxPerShare = acciStaxPerShare.add(iStaxReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(acciStaxPerShare).div(1e12).sub(user.rewardDebt);
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
        if (block.number <= pool.latestRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.depositToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.latestRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.latestRewardBlock, block.number);
        uint256 iStaxReward = multiplier.mul(iStaxPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        iStax.mint(devaddr, iStaxReward.div(8));
        iStax.mint(address(this), iStaxReward);
        pool.acciStaxPerShare = pool.acciStaxPerShare.add(iStaxReward.mul(1e12).div(lpSupply));
        pool.latestRewardBlock = block.number;
    }

    // Deposit LP tokens to iStaxIssuer for iStax allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.acciStaxPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                // Give user their accrued mined iSTAX tokens on deposit
                safeiStaxTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.depositToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.acciStaxPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP or other tokens from iSTAXissuer.
    // Fixed to prevent reentrancy
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.acciStaxPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeiStaxTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.depositToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.acciStaxPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.depositToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        
    }

    // Safe iStax transfer function, just in case if rounding error causes pool to not have enough iStaxs.
    function safeiStaxTransfer(address _to, uint256 _amount) internal {
        uint256 iStaxBal = iStax.balanceOf(address(this));
        if (_amount > iStaxBal) {
            iStax.transfer(_to, iStaxBal);
        } else {
            iStax.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}