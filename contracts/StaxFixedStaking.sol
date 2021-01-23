// SPDX-License-Identifier: MIT


pragma solidity 0.6.12;

import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import './iStaxIssuer.sol';
import './lib/EnumerableSet.sol';

// Issuer is the Chefcontract for which this contract earns rewards for.
// poolId is from this this Issuer as well

contract StaxFixedStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public poolId;

    iStaxIssuer public issuer;
    IERC20 public stax;
    IERC20 public iStax;
    IERC20 public stakingToken;

    uint256 public poolAmount;
    uint256 public totalReward;

    mapping (address => uint256) public poolsInfo;
    mapping (address => uint256) public preRewardAllocation;
    // EnumerableSet public addressSet;

    // Declare a set state variable
    EnumerableSet.AddressSet private addressSet;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event EmergencyErc20Retrieve(address indexed user, uint256 amount);

    constructor(
        iStaxIssuer _issuer,
        IERC20 _stax,
        IERC20 _iStax,
        IERC20 _stakingToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _poolId
    ) public {
        issuer = _issuer;
        stax = _stax;
        iStax = _iStax;
        stakingToken = _stakingToken;
        endBlock = _endBlock;
        startBlock = _startBlock;
        poolId = _poolId;
    }

    // View function to see pending earned Tokens on frontend.
    // Please ignore the compile warning on this.
    function pendingReward(address _user) external view returns (uint256) {
        uint256 amount = poolsInfo[msg.sender];
        if (block.number < startBlock) {
            return 0;
        }
        if (block.number > endBlock && amount > 0 && totalReward == 0) {
            uint256 pending = issuer.pendingiStax(poolId, address(this));
            return pending.mul(amount).div(poolAmount);
        }
        if (block.number > endBlock && amount > 0 && totalReward > 0) {
            return totalReward.mul(amount).div(poolAmount);
        }
        if (totalReward == 0 && amount > 0) {
            uint256 pending = issuer.pendingiStax(poolId, address(this));
            return pending.mul(amount).div(poolAmount);
        }
        return 0;
    }


    // Deposit stax tokens for Locked Reward allocation.
    function deposit(uint256 _amount) public {
        require (block.number < startBlock, 'not deposit time');
        stax.safeTransferFrom(address(msg.sender), address(this), _amount);
        if (poolsInfo[msg.sender] == 0) {
            addressSet.add(address(msg.sender));
        }
        poolsInfo[msg.sender] = poolsInfo[msg.sender].add(_amount);
        preRewardAllocation[msg.sender] = preRewardAllocation[msg.sender].add((startBlock.sub(block.number)).mul(_amount));
        poolAmount = poolAmount.add(_amount);
        issuer.deposit(poolId, 0);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw staking tokens from iStaxissuer.
    function withdraw() public {
        require (block.number > endBlock, 'not withdraw time');
        if (totalReward == 0) {
            totalReward = issuer.pendingiStax(poolId, address(this));
            // Claim rewards into the pool
            issuer.deposit(poolId, 0);
        }

        uint256 reward = poolsInfo[msg.sender].mul(totalReward).div(poolAmount);
        uint256 depositAmount = poolsInfo[msg.sender];
        poolAmount = poolAmount.sub(depositAmount);
        poolsInfo[msg.sender] = 0;
        totalReward = totalReward.sub(reward);
        // returns the initial deposited STAX
        stax.safeTransfer(address(msg.sender), depositAmount);
        // distributes the iSTAX reward to the user
        iStax.safeTransfer(address(msg.sender), reward);
        emit Withdraw(msg.sender, reward);
    }

    // EMERGENCY ONLY. 
    function emergencyWithdraw(uint256 _amount) public onlyOwner {
        stax.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

        // EMERGENCY ERC20 Rescue ONLY - withdraw all erroneous tokens sent in to this address. 
    // cannot withdraw STAX in the contract that users deposit
    function emergencyErc20Retrieve(address token) external onlyOwner {
        require(token != address(stax), "can't withdraw stax"); // only allow retrieval for nonSTAX tokens
        IERC20(token).safeTransfer(address(msg.sender), IERC20(token).balanceOf(address(this))); // helps remove all 
        emit EmergencyErc20Retrieve(address(msg.sender), IERC20(token).balanceOf(address(this)));
    }

    function depositToissuer(uint256 _amount) public onlyOwner {
        stakingToken.safeApprove(address(issuer), _amount);
        issuer.deposit(poolId, _amount);
    }

    function harvestFromissuer() public onlyOwner {
        issuer.deposit(poolId, 0);
        
    }
    }