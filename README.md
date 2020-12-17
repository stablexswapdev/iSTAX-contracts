# iSTAX Insurance Contracts repo

We spent a significant chunk of our hackathon time preparing the framework for the FIRST native-insurance protocol built into the StableXSwap ecosystem, and plan to make this a full suite to allow other projects to offer insurance on their projects denominated in their own asset, and help drive volume on future low-impermanent loss pools for governance/insurance token pairs which should be correlated and thus have low IL!

For a full write up on our insurancep plans, please visit:
https://docs.google.com/document/d/1tS28BwJYZkF4blpnlQGCSqNeQXEz7OmNAoJbQTm9t0c/edit


<img src="https://github.com/stablexswapdev/insuranceRepo/raw/main/new_insurance_preview.png"> 

Front End available here: (work in progress)
https://github.com/stablexswapdev/insFrontend

In this repo, we build a staking-native insurance product with a multi-sig enforcable resolution of the prediction market-style insurance product.

We essentially modified our old fixed-duration staking contracts to create contracts for binary outcome prediction markets. 
Users are able to earn iSTAX tokens through a liquidity mining mechanism for depositing liquidity into the core stablexswap, and then my proceed to allocate these iSTAX tokens to any of the eligible insurance market outcomes. For example, a user worried about smart contract risk can stake into the SWAPSC market, which pays out 1 STAX for every iSTAX staked in to it if the contract indeed gets exploited. 
On the backend, the smart contract has a fundStax function that allows a multisig such as the community treasury to send in STAX to provide liquidity in case of hack.

We can also do other binary markets such as StableXSwap reaching at least 4/6 of its items on its roadmap for the end of 2020! 
The possibilities are endless. 

The iSTAX insurance staking front end is still a work in progress, but the underlying contracts for the following have been deployed on testnet:


StaxToken
0x869446a92293DE6cEbb1b71CfcA6bd48f6bef6fC

iStaxToken
0x29f5b2959c1b0FE96985799Bd2E6c36187A16Ff1

IStaxIssuer
0xF6086E6f4272032B463fcA37c9C74568e58cA85C

ISTAXMarketToken Contracts
0x128CD4C86b64b62a360c5bb0d52AA3F932b17337,
0x9944bbB265661304c25B1b5aDd13d86adB470C11,
0x4492544060C5Ec18E0E6a744B666bcE3D8FF260E,
0x4492544060C5Ec18E0E6a744B666bcE3D8FF260E,
0xb0E38B2569220F5E33eBFF6E6D1Bff28914AaAc6,
0x91242B317F5791574AE617513A2c580c09Bb9C39

ISTAXMarket Contracts
0x2e19c7f6131Bf3d6fb15efF18c1CDC2f2Ee437dc,
0x5a7b1Feb1A9EB1623C8e5b6E264BDf6566c0eDDA,
0x258f24C7A4a4feE9914b3B491B35A906dEB6CC60,
0x81a23af0DbA6A5D949Ed39D48a2351D2012f3704,
0x97EA061ac2Ee2f1E7B76282Fd5257E5cF900C82A,
0x8A3Bf6e901B7Ed8f5d674378aeE4be5aaa2DEDa5,
0x7E0B639B81375788c681a2054BD8d9C9ce804f20
