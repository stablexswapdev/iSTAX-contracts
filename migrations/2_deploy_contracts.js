const iStaxToken = artifacts.require("iStaxToken");
const iStaxIssuer = artifacts.require("iStaxIssuer");
const stakingToken = artifacts.require("stakingToken");
const iStaxMarket = artifacts.require("iStaxMarket");
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

// 

//   Sample: deploys three different durations of staking dummy tokens, and mints 1 wei to the owner
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX2W', numAsHex)
  const twoWeekStake = await stakingToken.deployed();
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX1M', numAsHex)
  const oneMonthStake = await stakingToken.deployed();
  await deployer.deploy(stakingToken, 'StableX Staking Token', 'STAX1Y', numAsHex)
  const oneyearStake = await stakingToken.deployed();


// Already Deployed addresses input here
const stakingDurationTokenAddress = twoWeekStake.address;
const staxAddress = '0x0Da6Ed8B13214Ff28e9Ca979Dd37439e8a88F6c4' // This is only for mainnet, may need to toggle for testnet
const iStaxAddress = ''

  await deployer.deploy(iStaxMarket, iStaxIssuerAddress, staxAddress ,iStaxAddress , stakingDurationTokenAddress,'1903600', '2306800','5')
  const chef1 = await iStaxMarket.deployed();
  const stakingToken1 = await stakingToken.at(stakingDurationTokenAddress)
  await stakingToken1.mint(chef1.address, '1')
  await chef1.depositToChef('1')

}


