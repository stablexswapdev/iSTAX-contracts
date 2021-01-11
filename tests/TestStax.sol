pragma solidity >=0.4.25 <0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MetaCoin.sol";


// STAX
// Todos: Test minting, check if coin is mintable, owner is set properly

// iSTAX
// testchef minting capabilities
// Check issuance logic

// Test withdrawal of tokens from pools
// Check if rewards are received
// Check if EmergencyWithdraw works


// Check 

// Check timelength of the lock works at correct blockheights
// Make sure early withdrawals are not possible
// Consider adding code for early withdrawal with penalty.


// Insurance Contracts:
// Check if deposits work to top up 
// Check if user cannot withdraw when there's no reward
// // Check if balance can be found after allowance is given from the chef wallet to top up in case of payout

// Check if payout function works

// 

// 
contract TestiStaxCoin {
  function testInitialBalanceUsingDeployedContract(address) {
    MetaCoin meta = MetaCoin(DeployedAddresses.MetaCoin());

    address expectedAddress = ;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  }

  function testInitialBalanceWithNewMetaCoin() {
    MetaCoin meta = new MetaCoin();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  }
}

DeployedAddresses.<contract name>();






contract TestHooks {
  uint someValue;

  function beforeEach() {
    someValue = 5;
  }

  function beforeEachAgain() {
    someValue += 1;
  }

  function testSomeValueIsSix() {
    uint expected = 6;

    Assert.equal(someValue, expected, "someValue should have been 6");
  }
}