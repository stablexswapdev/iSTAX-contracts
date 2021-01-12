const  startCoverageTime = '5500000'
const endCoverageTime = '5500050'


const iStaxToken = artifacts.require("iStaxToken");
const iStaxIssuer = artifacts.require("iStaxIssuer");
const stakingToken = artifacts.require("stakingToken");
const iStaxMarket = artifacts.require("iStaxMarket");
const iStaxMarketToken = artifacts.require("iStaxMarketToken");
const devAddress = "0x7323B13669028780c6450A620064E30654a5Be2c" // To Update when testing

module.exports = async function(deployer) {
  const num = 1 * Math.pow(10, 18);
  const numAsHex = "0x" + num.toString(16);
//  Deploy iStax Token 
await deployer.deploy(iStaxToken)
const iStax = await iStaxToken.deployed();
const iStaxAddress = iStax.address;

// Depoly iStaxIssuer
await deployer.deploy(iStaxIssuer, iStaxAddress, devAddress, 8, 1, 250000, 250005, 5)
const iStaxChef = await iStaxIssuer.deployed();
const iStaxChefAddress = iStaxChef.address;

//   Sample: deploys three different durations of staking dummy tokens, and mints 1 wei to the owner
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX2W', numAsHex)
  const twoWeekStake = await stakingToken.deployed();
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX1M', numAsHex)
  const oneMonthStake = await stakingToken.deployed();
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX1Y', numAsHex)
  const oneYearStake = await stakingToken.deployed();

// Already Deployed addresses input here
const stakingTokenAddress1 = twoWeekStake.address;
const stakingTokenAddress2 = oneMonthStake.address;
const stakingTokenAddress3 = oneYearStake.address;

// Deploy Insurance Dummy Tokens
// stablecoin peg protection
await deployer.deploy(iStaxMarketToken), 'iStax DAIUP Insurance', 'iSTAXDAIUP', numAsHex)
const daiUpToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax DAIDOWN Insurance', 'iSTAXDAIDOWN', numAsHex)
const daiDownToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax USDTUP Insurance', 'iSTAXUSDTUP', numAsHex)
const usdtUpToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax USDTDOWN Insurance', 'iSTAXUSDTDOWN', numAsHex)
const usdtDownToken = await iStaxMarketToken.deployed();
// Smart Contract Insurance
await deployer.deploy(iStaxMarketToken), 'iStax Swap Smart Contract Insurance', 'iSTAXSWAPSC', numAsHex)
const istaxSwapToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax Staking Smart Contract Insurance', 'iSTAXSTAKESC', numAsHex)
const istaxStakeToken = await iStaxMarketToken.deployed();


const iTokenAddress1 = daiUpToken.address;
const iTokenAddress2 = daiDownToken.address;
const iTokenAddress3 = usdtUpToken.address;
const iTokenAddress4 = usdtDownToken.address;

const iTokenAddress5 = istaxSwapToken.address;
const iTokenAddress6 = istaxStakeToken.address;


const staxAddress = '0x0Da6Ed8B13214Ff28e9Ca979Dd37439e8a88F6c4' // This is only for mainnet, may need to toggle for testnet

// Launch First pool
const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
  await iStaxChef.add(poolWeight, stakingTokenAddress1, True)
// Deploy market/staking contract 
  await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , stakingTokenAddress1, startCoverageTime,  endCoverageTime,'0')
  const sousChef0 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
  await twoWeekStake.mint(sousChef0.address, '1')
  await sousChef0.depositToChef('1')

  // Repeat for the next 2 staking durations
  const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
  await iStaxChef.add(poolWeight, stakingTokenAddress2, True)
// Deploy market/staking contract 
  await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , stakingTokenAddress2, startCoverageTime,  endCoverageTime,'1')
  const sousChef1 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
  await oneMonthStake.mint(sousChef1.address, '1')
  await sousChef1.depositToChef('1')


  const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
  await iStaxChef.add(poolWeight, stakingTokenAddress3, True)
// Deploy market/staking contract 
// Adjust blocktimes for start and end as necessary
  await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , stakingTokenAddress3, startCoverageTime,  endCoverageTime,'2')

  const sousChef2 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
  await oneYearStake.mint(sousChef2.address, '1')
  await sousChef2.depositToChef('1')


// Deploy the insurance pools

  const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
  await iStaxChef.add(poolWeight, iTokenAddress1, True)
// Deploy market/staking contract 
  await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress1, startCoverageTime,  endCoverageTime,'3')
  const sousChef3 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
  await daiUpToken.mint(sousChef3.address, '1')
  await sousChef3.depositToChef('1')



const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
await iStaxChef.add(poolWeight, iTokenAddress2, True)
// Deploy market/staking contract 
await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress2, startCoverageTime,  endCoverageTime,'4')
const sousChef4 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
await daiDownToken.mint(sousChef4.address, '1')
await sousChef4.depositToChef('1')


const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
await iStaxChef.add(poolWeight, iTokenAddress3, True)
// Deploy market/staking contract 
await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress3, startCoverageTime,  endCoverageTime,'5')
const sousChef5 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
await usdtUpToken.mint(sousChef5.address, '1')
await sousChef5.depositToChef('1')


const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
await iStaxChef.add(poolWeight, iTokenAddress4, True)
// Deploy market/staking contract 
await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress4, startCoverageTime,  endCoverageTime,'6')
const sousChef6 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
await usdtDownToken.mint(sousChef6.address, '1')
await sousChef6.depositToChef('1')

const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
await iStaxChef.add(poolWeight, iTokenAddress5, True)
// Deploy market/staking contract 
await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress5, startCoverageTime,  endCoverageTime,'7')
const sousChef7 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
await istaxSwapToken.mint(sousChef7.address, '1')
await sousChef7.depositToChef('1')
  

const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
await iStaxChef.add(poolWeight, iTokenAddress6, True)
// Deploy market/staking contract 
await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , iTokenAddress6, startCoverageTime,  endCoverageTime,'8')
const sousChef8 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
await istaxStakeToken.mint(sousChef8.address, '1')
await sousChef8.depositToChef('1')
  
  

}



// todo: open ended distribution
