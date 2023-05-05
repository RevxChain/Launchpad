const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {

  const [signer] = await ethers.getSigners();
  const deployerAddress = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

  console.log(signer);

  const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken", signer);
  const token = await LaunchpadToken.deploy(deployerAddress, 10000);
  await token.deployed();
  console.log(`${token.address}`);

  const launchpadTokenAddress = token.address;

  //const tokenSupply = await token.totalSupply(); to test {
  //console.log(tokenSupply);
  //console.log(deployerAddress); }

  const TokenFactory = await ethers.getContractFactory("TokenFactory", signer);
  const tokenFactory = await TokenFactory.deploy();
  await tokenFactory.deployed();
  console.log(`${tokenFactory.address}`);

  const LaunchpadStaking = await ethers.getContractFactory("LaunchpadStaking", signer);
  const launchpadStaking = await LaunchpadStaking.deploy(token.address);
  await launchpadStaking.deployed();
  console.log(`${launchpadStaking.address}`);

  const TokenMinter = await ethers.getContractFactory("TokenMinter", signer);
  const tokenMinter = await TokenMinter.deploy(token.address, tokenFactory.address, launchpadStaking.address);
  await tokenMinter.deployed();
  console.log(`${tokenMinter.address}`);

  const FundraiseFactory = await ethers.getContractFactory("FundraiseFactory", signer);
  const fundraiseFactory = await FundraiseFactory.deploy(launchpadStaking.address);
  await fundraiseFactory.deployed();
  console.log(`${fundraiseFactory.address}`);

  const ScheduleVestingFactory = await ethers.getContractFactory("ScheduleVestingFactory", signer);
  const scheduleVestingFactory = await ScheduleVestingFactory.deploy();
  await scheduleVestingFactory.deployed();
  console.log(`${scheduleVestingFactory.address}`); 

  const LinearVestingFactory = await ethers.getContractFactory("LinearVestingFactory", signer);
  const linearVestingFactory = await LinearVestingFactory.deploy();
  await linearVestingFactory.deployed();
  console.log(`${linearVestingFactory.address}`);  

  const LiquidityRouter = await ethers.getContractFactory("LiquidityRouter", signer);
  const liquidityRouter = await LiquidityRouter.deploy(token.address, token.address);
  await liquidityRouter.deployed();
  console.log(`${liquidityRouter.address}`);

  const LiquidityVault = await ethers.getContractFactory("LiquidityVault", signer);
  const liquidityVault = await LiquidityVault.deploy(liquidityRouter.address);
  await liquidityVault.deployed();
  console.log(`${liquidityVault.address}`);

  const VestingOperator = await ethers.getContractFactory("VestingOperator", signer);
  const vestingOperator = await VestingOperator.deploy(
    token.address, 
    fundraiseFactory.address, 
    scheduleVestingFactory.address, 
    linearVestingFactory.address,
    tokenFactory.address,
    liquidityVault.address,
    launchpadStaking.address
  );
  await vestingOperator.deployed();
  console.log(`${vestingOperator.address}`);

  const BaseOperator = await ethers.getContractFactory("BaseOperator", signer);
  const baseOperator = await BaseOperator.deploy(
    token.address, 
    fundraiseFactory.address, 
    vestingOperator.address,
    liquidityVault.address,
    launchpadStaking.address,
    tokenMinter.address
  );
  await baseOperator.deployed();
  console.log(`${baseOperator.address}`);

  const LaunchpadDAO = await ethers.getContractFactory("LaunchpadDAO", signer);
  const launchpadDAO = await LaunchpadDAO.deploy(
    token.address, 
    launchpadStaking.address,
    tokenMinter.address,
    liquidityVault.address
  );
  await launchpadDAO.deployed();
  console.log(`${launchpadDAO.address}`);

  tokenFactory.setupOperator(tokenMinter.address);
  launchpadStaking.setupOperator(baseOperator.address);
  fundraiseFactory.setupOperator(baseOperator.address);
  tokenMinter.setupOperator(baseOperator.address);
  scheduleVestingFactory.setupOperator(vestingOperator.address);
  linearVestingFactory.setupOperator(vestingOperator.address);
  liquidityRouter.setupOperator(liquidityVault.address);
  liquidityVault.setupOperator(baseOperator.address);
  liquidityVault.setDAORole(launchpadDAO.address);
  vestingOperator.setupOperator(baseOperator.address);
  tokenMinter.setDAORole(launchpadDAO.address);
  
  

  



















} 




main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

