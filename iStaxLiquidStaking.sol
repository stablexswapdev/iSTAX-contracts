// SPDX-License-Identifier: MIT

// This contract is used 
pragma solidity 0.6.12;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import './iStaxIssuer.sol';
import './EnumerableSet.sol';

contract iStaxLiquidStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public startCoverageBlock;
    uint256 public matureBlock;
    uint256 public poolId;

    iStaxIssuer public issuer;
    IERC20 public stax;
    IERC20 public iStax;
    IERC20 public iStaxMarketToken;

    uint256 public totalDeposited;
    uint256 public coverageOutstanding;

    mapping (address => uint256) public poolsInfo;
    mapping (address => uint256) public preRewardAllocation;

    EnumerableSet.AddressSet private addressSet;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    event FundStax(address indexed user, uint256 amount);
    event Cash(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        iStaxIssuer _issuer,
        IERC20 _Stax,
        IERC20 _iStax,
        IERC20 _iStaxMarketToken,
        uint256 _startCoverageBlock,
        uint256 _matureBlock,
        uint256 _poolId
    ) public {
        issuer = _issuer;
        stax = _Stax;
        iStax = _iStax;
        iStaxMarketToken = _iStaxMarketToken;
        matureBlock = _matureBlock;
        startCoverageBlock = _startCoverageBlock;
        poolId = _poolId;
    }
    // There are not rewards to capture 
    // View function to see pending Tokens on frontend.

        function pendingExercisableCoverage(address _user) external view returns (uint256) {
            uint256 amount = poolsInfo[msg.sender];
            if (block.number < startCoverageBlock) {
                return 0;
            }
            if (coverageOutstanding > 0 && amount > 0) {
                 // Check if user has a claimable amount here
                return amount.mul(coverageOutstanding).div(totalDeposited);
            }
            return 0;
        }
  
    // Deposit iStax tokens for participation in insurance staking
    // Depositing gives a user a claim for specific outcome, which will be redeemable for 0 or 1 STAX dependong on the outcome
    // Tokens are not refundable once deposited. All sales final.
    function deposit(uint256 _amount) public {
        require (block.number < startCoverageBlock, 'not deposit time');
        iStax.safeTransferFrom(address(msg.sender), address(this), _amount);
        // This adds the users to the claims list (an enumerable set)
        if (poolsInfo[msg.sender] == 0) {
            addressSet.add(address(msg.sender));
        }
        poolsInfo[msg.sender] = poolsInfo[msg.sender].add(_amount);

        // We may not need to incentivise users for participating ahead of the deadline, since they are covered or incentivised to participate in the earliest active contract
        preRewardAllocation[msg.sender] = preRewardAllocation[msg.sender].add((startCoverageBlock.sub(block.number)).mul(_amount));
        totalDeposited = totalDeposited.add(_amount);
        issuer.deposit(poolId, 0);
        emit Deposit(msg.sender, _amount);
    }
    // This function is not needed because iSTAX staking will only earn iSTAX, not STAX.
    // This function is onlyOwner to prevent someone else from sending a small amount to make other redeems possible
    // Allow the owner multisig to deposit in a certain reward token, currently STAX, to pay for future claims
    // function fundStax(uint256 _amount) public onlyOwner {
    //     // Transfer user's funds to this account
    //     stax.safeTransferFrom(address(msg.sender), address(this), _amount);
    //     // This updates the coverageOutstanding to calculate the total amount ready to distribute to users for payout
    //     coverageOutstanding = coverageOutstanding.add(_amount);
 
    //     emit FundStax(msg.sender, _amount);
    // }

    // A redeem function to wipe out staked insurance token and redeem for rewards token from issuer.
    function redeem() public {
        // Cannot redeem if this market has no value of coverage - paid by fundStax
        require (coverageOutstanding > 0, 'no redemption value');
        // require (block.number > matureBlock, 'not redemption time');
        // Amount that can be claimed from the contract needs to be reduced by the amount redeemed
        uint256 claim = poolsInfo[msg.sender];
        uint256 currentTotal = totalDeposited;
        uint256 currentCoverage = coverageOutstanding;
        totalDeposited = totalDeposited.sub(poolsInfo[msg.sender]);
        // wipes users valid iSTAX balance clean since they are redeeming it up now
        poolsInfo[msg.sender] = 0;
        // First reduce this claim from the total claims owed
        coverageOutstanding = coverageOutstanding.sub(claim);
        // combines principal and rewards into one sen
        // sends STAX tokens to redeemer of claim 
        //    In future, if there's a different conversion ratio than 1:1, can be added here
         stax.safeTransfer(address(msg.sender), claim.mul(currentCoverage).div(currentTotal));
        
        emit Redeem(msg.sender, claim.mul(currentCoverage).div(currentTotal));
    }
    // This contract does not have a withdraw because users would be able to stake directly and liquidly iSTAX,
    //  so the contract owner should not have access to withdraw these funds wahtsoever
    // Function for the multisig to cash in the deposited iSTAX Insurance tokens and simultaneously burn half
    // Important, only the multisig Owner can call this function, otherwise other people could get the iSTAX.
    // function cash(uint256 _amount) public onlyOwner {
    //     // Require the cash amount to be less than the amount totally deposited
    //     require(totalDeposited >= _amount, "cash too large");
    //     // Split the _amount to be cashed out in half.
    //     uint256 burnAmount = _amount.div(2);
    //     // Check if we need a spend allowance from this contract, but should be OK
    //     iStax.safeTransfer(address(msg.sender), burnAmount);
    //     // This Burns the remaining half of the amount
    //     iStax.safeTransfer(address(0), burnAmount);
    //     emit Cash(msg.sender, _amount);
    // }

    // EMERGENCY ONLY - withdraw any stax sent in to this address. 
    // Note to owner: Please make sure not to send in any assets that are not STAX
    function emergencyWithdraw(uint256 _amount) public onlyOwner {
        stax.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    function depositToissuer(uint256 _amount) public onlyOwner {
        iStaxMarketToken.safeApprove(address(issuer), _amount);
        issuer.deposit(poolId, _amount);
    }

    // This is to allow Issuer to collect the rewards for the issuer? 
    function harvestFromissuer() public onlyOwner {
        issuer.deposit(poolId, 0);
        
    }
    }