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
  const oneyearStake = await stakingToken.deployed();

// Already Deployed addresses input here
const stakingTokenAddress1 = twoWeekStake.address;
const stakingTokenAddress2 = oneMonthStake.address;
const stakingTokenAddress3 = oneyearStake.address;

// Deploy Insurance Dummy Tokens
// stablecoin peg protection
await deployer.deploy(iStaxMarketToken), 'iStax DAIUP Insurance', 'iSTAXDAIUP', numAsHex)
const daiUpToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax DAIDOWN Insurance', 'iSTAXDAIDOWN', numAsHex)
const daiUpToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax USDTUP Insurance', 'iSTAXUSDTUP', numAsHex)
const daiUpToken = await iStaxMarketToken.deployed();
await deployer.deploy(iStaxMarketToken), 'iStax USDTDOWN Insurance', 'iSTAXUSDTDOWN', numAsHex)
const daiUpToken = await iStaxMarketToken.deployed();


const staxAddress = '0x0Da6Ed8B13214Ff28e9Ca979Dd37439e8a88F6c4' // This is only for mainnet, may need to toggle for testnet

// Launch First pool
const poolWeight = 300; // Adjust if necessary for different pool weight multipliers.
  await iStaxChef.add(poolWeight, stakingTokenAddress1, True)
// Deploy market/staking contract 
  await deployer.deploy(iStaxMarket, iStaxChefAddress, staxAddress ,iStaxAddress , stakingTokenAddress1,'1903600', '2306800','0')
  const sousChef1 = await iStaxMarket.deployed();
// const stakingToken1 = await stakingToken.at(stakingTokenAddress1)
// Deposit 1 wei from owner to pool to initiate pool for mining rewards - not necessary if the weight = 0;
  await twoweekStake.mint(sousChef1.address, '1')
  await sousChef1.depositToChef('1')


  

}



// todo: open ended distribution
