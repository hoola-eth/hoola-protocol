
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 const { task } = require("hardhat/config");
 require("hardhat/config");
 require("@tenderly/hardhat-tenderly");
 require("dotenv").config();
 require("@nomiclabs/hardhat-etherscan");
 require("@nomiclabs/hardhat-ethers");
 require("hardhat-deploy-ethers");
 require("@openzeppelin/hardhat-upgrades");

const ETH = "0x0000000000000000000000000000000000000000";
const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f";
const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
const USDT = "0xdac17f958d2ee523a2206206994597c13d831ec7";
const TUSD = "0x0000000000085d4780B73119b644AE5ecd22b376";
const BUSD = "0x4fabb145d64652a948d72533023f6e7a623c7c53";
const WBTC = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";
const COMP = "0xc00e94Cb662C3520282E6f5717214004A7f26888";   /// TODO
const AAVE = "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9"; 
const cETH = "0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5";


/**
 * @task Task can be call to deploy and upgrade contracts
 * see the README for deployment instructions
 */

task("deploy", "ETHEARN & cHACK NFTs", async (_, { network, ethers, upgrades }) => {
  //IMPERSONATE (UNLOCK AN ACCOUNT)
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x0000006daea1723962647b7e189d311d757Fb793"],
  });
  console.log("Impersonated");
  const signer = await ethers.provider.getSigner(
    "0x0000006daea1723962647b7e189d311d757Fb793"
  );

  // SEEDS YOUR ACCOUNT WITH FUNDS
  console.log("Seeding the account")
  let dai = await ethers.getContractAt("ERC20", DAI,signer);
  let balance = await dai.balanceOf(process.env.IMPERSONATED)
  console.log("BALANCE OF IMPERSONATED ACCOUNT: ",balance.toString())
  await dai.transfer(process.env.MYADDRESS,balance.toString())
  balance = await dai.balanceOf(process.env.MYADDRESS)
  console.log("BALANCE TRANSFERRED TO YOUR LOCAL ACCOUNT: ",balance.toString())

  // DEPLOY THE LOOP PROXY
  let artifact = await ethers.getContractFactory("ETHEARN");
  let ETHEARN = await upgrades.deployProxy(artifact, [
    "ETHEARN Token",
    "ETHEARN",
    800,
    process.env.MYADDRESS,
  ]);

  await ETHEARN.deployed();
  console.log("LOOP ADDRESS :", ETHEARN.address);

  console.log('Registering assets')
  await ETHEARN.registerAsset(ETH);
  await ETHEARN.registerAsset(DAI);
  await ETHEARN.registerAsset(USDC);
  await ETHEARN.registerAsset(TUSD);
  await ETHEARN.registerAsset(USDT);
  await ETHEARN.registerAsset(WBTC);
  await ETHEARN.registerAsset(BUSD);
  await ETHEARN.registerAsset(COMP);
  await ETHEARN.registerAsset(AAVE);

  // DEPLOY THE LoopCompNFT
  artifact = await ethers.getContractFactory("cHack");
  let cHack = await upgrades.deployProxy(artifact, [
    "ETHEARN Compound Hackathon NFT",
    "cHack",
    800,
    "ipfs://bafybeighkisracdra4apgrtbypj5sadjcqz27hbrtsmigmzyawmhyxvmzi/",
    ETHEARN.address,
  ],{ initializer: 'LoopInitialize' });

  await cHack.deployed();
  console.log("cHack Address :", cHack.address);


  console.log("Entering Compound markets...");
  console.log("ETH Market...");
  await cHack._enterCompMarket(ETH,cETH);

  console.log("adding cHACK Vault");
  await ETHEARN.addNFTVault(cHack.address);

  console.log("Minting cHACK NFT");
  options = {value : '1000000000000000000'}
  await ETHEARN.buyVaultNft(1, process.env.MYADDRESS,options)

  console.log("Checking balance of cHack");
  balance =  await cHack.balanceOf(process.env.MYADDRESS);
  console.log("cHack balance :", balance.toString())


  let amount = '1000000000000000000000';
  console.log("Depositing "+ amount+" Dai on the ETHEARN");
  dai = await ethers.getContractAt("ERC20", DAI);
  await dai.approve(ETHEARN.address,amount)
  receipt =  await ETHEARN.deposit(DAI,amount);

  // WE HAVE 1000 DAI on the loop

  console.log('Creating a swappable order of 500 Dai / 500 USDC')
  await ETHEARN.createLoopOrder(DAI,'500000000000000000000', USDC, '500000000', true)


  console.log('Checking my available balance')
  let availableBalance = await ETHEARN.availableBalance(DAI,process.env.MYADDRESS)
  console.log('ON DEX DAI BALANCE',availableBalance.toString())

  console.log('Checking my OrderBook balance')
  let liquidityBalance = await ETHEARN.loopOrderBalance(DAI,process.env.MYADDRESS)
  console.log('IN LIQUIDITY POSITION',liquidityBalance.toString())

  // console.log("Withdrawing "+ amount +" Dai from the LOOP");
  // dai = await ethers.getContractAt("ERC20", DAI);
  // receipt =  await LOOP.withdraw(DAI,amount);
})




task("deployAave", "Deploying LOOP & AaveNft", async (_, { network, ethers, upgrades }) => {
  //IMPERSONATE (UNLOCK AN ACCOUNT)
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x0000006daea1723962647b7e189d311d757Fb793"],
  });
  console.log("Impersonated");
  const signer = await ethers.provider.getSigner(
    "0x0000006daea1723962647b7e189d311d757Fb793"
  );

  // SEEDS YOUR ACCOUNT WITH FUNDS
  console.log("Seeding the account")
  let dai = await ethers.getContractAt("ERC20", DAI,signer);
  let balance = await dai.balanceOf(process.env.IMPERSONATED)
  console.log("BALANCE OF IMPERSONATED ACCOUNT: ",balance.toString())
  await dai.transfer(process.env.MYADDRESS,balance.toString())
  balance = await dai.balanceOf(process.env.MYADDRESS)
  console.log("BALANCE TRANSFERRED TO YOUR LOCAL ACCOUNT: ",balance.toString())

  // DEPLOY THE LOOP PROXY
  let artifact = await ethers.getContractFactory("LOOP");
  let LOOP = await upgrades.deployProxy(artifact, [
    "LOOP DEFI",
    "LOOP",
    800,
    process.env.MYADDRESS,
  ]);

  await LOOP.deployed();
  console.log("LOOP ADDRESS :", LOOP.address);

  console.log('Registering assets')
  await LOOP.registerAsset(ETH);
  await LOOP.registerAsset(DAI);
  await LOOP.registerAsset(USDC);
  await LOOP.registerAsset(TUSD);
  await LOOP.registerAsset(USDT);
  await LOOP.registerAsset(WBTC);
  await LOOP.registerAsset(BUSD);
  await LOOP.registerAsset(COMP);
  await LOOP.registerAsset(AAVE);

  // DEPLOY THE LoopCompNFT
  artifact = await ethers.getContractFactory("LoopNFT");
  let aHack = await upgrades.deployProxy(artifact, [
    "LOOP Aave Hackathon NFT",
    "aHack",
    800,
    "ipfs://bafybeighkisracdra4apgrtbypj5sadjcqz27hbrtsmigmzyawmhyxvmzi/",
    LOOP.address,
  ], { initializer: 'LoopInitialize' });

  await aHack.deployed();
  console.log("aHack Address :", aHack.address);

  console.log("adding aHACK Vault");
  await LOOP.addNFTVault(aHack.address);

  console.log("Minting aHACK NFT");
  options = {value : '1000000000000000000'}
  await LOOP.buyVaultNft(1, process.env.MYADDRESS,options)

  console.log("Checking balance of aHack");
  balance =  await aHack.balanceOf(process.env.MYADDRESS);
  console.log("aHack balance :", balance.toString())


  let amount = '1000000000000000000000';
  console.log("Depositing "+ amount+" Dai on the LOOP");
  dai = await ethers.getContractAt("ERC20", DAI);
  await dai.approve(LOOP.address,amount)
  receipt =  await LOOP.deposit(DAI,amount);

  // WE HAVE 1000 DAI on the loop

  console.log('Creating a swappable order of 500 Dai / 500 USDC')
  await LOOP.createLoopOrder(DAI,'500000000000000000000', USDC, '500000000', true)


  console.log('Checking my available balance')
  let availableBalance = await LOOP.availableBalance(DAI,process.env.MYADDRESS)
  console.log('ON DEX DAI BALANCE',availableBalance.toString())

  console.log('Checking my OrderBook balance')
  let liquidityBalance = await LOOP.loopOrderBalance(DAI,process.env.MYADDRESS)
  console.log('IN LIQUIDITY POSITION',liquidityBalance.toString())

  // console.log("Withdrawing "+ amount +" Dai from the LOOP");
  // dai = await ethers.getContractAt("ERC20", DAI);
  // receipt =  await LOOP.withdraw(DAI,amount);
})





 module.exports = {
  defaultNetwork: "local",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/" + process.env.ALCHEMY_KEY,
        blockNumber: 12647372,
      },
    },
    // rinkeby: {
    //   url: "https://eth-rinkeby.alchemyapi.io/v2/" + process.env.ALCHEMY_KEY,
    //   accounts: { mnemonic: process.env.MNEMONIC },
    // },
    // kovan: {
    //   url: "https://kovan.infura.io/v3/" + process.env.INFURA_ID,
    //   accounts: { mnemonic: process.env.MNEMONIC },
    // },
    local: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337 
    },
    // binance: {
    //   url: "https://data-seed-prebsc-1-s1.binance.org:8545",
    //   chainId: 97,
    //   gasPrice: 20000000000,
    //   accounts: {mnemonic: process.env.MNEMONIC}
    // },
  },
  // etherscan: {
  //   // Your API key for Etherscan
  //   // Obtain one at https://etherscan.io/
  //   apiKey: process.env.ETHERSCAN,
  // },
  tenderly: {
    project: "project",
    username: "loop-defi",
},
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    // script: "./script"
  },
  mocha: {
    timeout: 2000000,
  },
};

//npx hardhat verify --network rinkeby <implementation address>