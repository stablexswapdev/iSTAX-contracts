// SPDX-License-Identifier: MIT
// A modification to the original Sushichef contract that mints and distributes stax, 
// and adapts it for use for distribution of rewards from a static treasury wallet that 
// has already goven allowance to this contract to distribute


pragma solidity ^0.6.12;

import "./StaxToken.sol";
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
                         
contract StaxIssuer is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Staxs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accStaxPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws Deposits tokens to a pool. Here's what happens:
        //   1. The pool's `accStaxPerShare` (and `latestRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Deposit token must be IERC20 compatible
    // Info of each pool.
    struct PoolInfo {
        IERC20 depositToken;           // Address of deposit token contract.
        uint256 allocPoint;       // How many allocation points (distribution weight) assigned to this pool.
        uint256 latestRewardBlock;  // Latest block number that Staxs distribution occurs.
        uint256 accStaxPerShare; // Accumulated Staxs per share, times 1e12. See below.
    }

    // The Stax TOKEN!
    StaxToken public Stax;
    // Dev address.
    address public devaddr;
    // Block number when first bonus Stax period ends.
    uint256 public firstBonusEndBlock;
    // Base Stax tokens created per block.
    uint256 public StaxPerBlock;
    // min Stax tokens created per block 
      uint256 public MinStaxPerBlock;
    // Bonus muliplier for early Stax earners.
    uint256 public constant INITIAL_BONUS_MULTIPLIER = 4;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes Deposits tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Stax mining starts.
    uint256 public startBlock;
    // The number of blocks between halvings
    uint256 public halvingDuration;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        StaxToken _Stax,
        address _devaddr,
        uint256 _StaxPerBlock,
        uint256 _MinStaxPerBlock,
        uint256 _startBlock,
        uint256 _firstBonusEndBlock,
        uint256 _halvingDuration
        // bool _isLive  // is not necessary at this time because we can set all the pool weights to 0 if we need to pause the rewards accrual

    ) public {
        Stax = _Stax;
        devaddr = _devaddr;
        StaxPerBlock = _StaxPerBlock;
        MinStaxPerBlock = _MinStaxPerBlock;
        firstBonusEndBlock = _firstBonusEndBlock;
        halvingDuration = _halvingDuration;
        startBlock = _startBlock;
        // isLive = _isLive;
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
        uint256 latestRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            // Update Pool Logic
            depositToken: _depositToken,
            allocPoint: _allocPoint,
            latestRewardBlock: latestRewardBlock,
            accStaxPerShare: 0
        }));
    }

    // Update the given pool's Stax allocation points. Can only be called by the owner.
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
            return _to.sub(_from).mul(INITIAL_BONUS_MULTIPLIER);
        }
        else {
            uint currentMultiplier = INITIAL_BONUS_MULTIPLIER;
            uint prevEpochBlock = firstBonusEndBlock;
            uint accruedBlockCredit = 0;
            uint periods = _to.sub(_from).mod(halvingDuration).div(halvingDuration);
            // halvingDuration is equivalent to the length of the period
            // Here we iterate through the chunked periods and their corresponding multipliers to get a summation of the credits
            // If periods is not at least 1, we skip directly to calculate the partial period duration
            if (periods >= 1) {
                for (uint i=0; i < periods; i++) {
                    accruedBlockCredit = accruedBlockCredit.add(currentMultiplier.mul(halvingDuration));
                    // Reduce the Multiplier by half if it's not already at the min
                    // This assumes that the initial bonus multiplier is a factor of two, otherwise there may be some weird division errors
                    // This is why our initial bonus multiplier is 8
                    if (currentMultiplier > MinStaxPerBlock) {
                        currentMultiplier.div(2);
                    }
                    // This increments the counter for the prevEpochblock to calculate the remainder
                    prevEpochBlock = prevEpochBlock.add(halvingDuration);
                    }
            }
            // Finally add the remainder blocks at the last currentMultiplier   
            // the difference between _to and prevEpochBlock is the remainder blocks
            // If periods wasn't long enough, we go straight here to calculate the accrued Credit
            accruedBlockCredit = accruedBlockCredit.add(currentMultiplier.mul(_to.sub(prevEpochBlock)));
            return accruedBlockCredit;
            }
    }

    // View function to see pending Staxs on frontend.
    function pendingStax(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accStaxPerShare = pool.accStaxPerShare;
        uint256 DepositsSupply = pool.depositToken.balanceOf(address(this));
        if (block.number > pool.latestRewardBlock && DepositsSupply != 0) {
            uint256 multiplier = getMultiplier(pool.latestRewardBlock, block.number);
            uint256 StaxReward = multiplier.mul(StaxPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accStaxPerShare = accStaxPerShare.add(StaxReward.mul(1e12).div(DepositsSupply));
        }
        return user.amount.mul(accStaxPerShare).div(1e12).sub(user.rewardDebt);
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
        uint256 DepositsSupply = pool.depositToken.balanceOf(address(this));
        if (DepositsSupply == 0) {
            pool.latestRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.latestRewardBlock, block.number);
        uint256 StaxReward = multiplier.mul(StaxPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        // removed the mint additional token to dev because this is already done in the original distributor
        // Stax.mint(devaddr, StaxReward.div(8));

        // Instead of mint, we withdraw tokens from stax
        // Stax.mint(address(this), StaxReward);
        // Transfers tokens from the devaddr 
        // (Dev Address must approve this distributor to allow for these tokens to be sent to the Chef)
        require(Stax.allowance(devaddr,address(this)) > StaxReward, "dev not enough allowance");
        Stax.transferFrom(devaddr, address(this), StaxReward);
          
        pool.accStaxPerShare = pool.accStaxPerShare.add(StaxReward.mul(1e12).div(DepositsSupply));
        pool.latestRewardBlock = block.number;
    }

    // Deposit Deposits tokens to StaxIssuer for Stax allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accStaxPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                // Give user their accrued mined Stax tokens on deposit
                safeStaxTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.depositToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accStaxPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw Deposits or other tokens from Staxissuer.
    // Fixed to prevent reentrancy
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accStaxPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeStaxTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.depositToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accStaxPerShare).div(1e12);
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

    // Function to withdraw any Stax that may be erroneously drawn from the dev in case of some error, 
    // so that the dev can still reclaim tokens and redistribute in case of a pause or other situation
    // This function is quite powerful, so it is important to make this a multisig devaddr, so that only via 
    // a committee's vote can this be called. 
    function emergencyRewardsWithdraw() public {
        require(msg.sender == devaddr, "only dev");  
        uint256 StaxBal = Stax.balanceOf(address(this));      
        Stax.transfer(devaddr, StaxBal);
    }
    // Safe Stax transfer function, just in case if rounding error causes pool to not have enough Staxs.
    // Warning, in case stax pool doesn't have enough tokens, it could potentially transfer nothing
    function safeStaxTransfer(address _to, uint256 _amount) internal {
        uint256 StaxBal = Stax.balanceOf(address(this));
        if (_amount > StaxBal) {
            Stax.transfer(_to, StaxBal);
        } else {
            Stax.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}