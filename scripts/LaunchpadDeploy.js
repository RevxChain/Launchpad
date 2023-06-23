const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {

    const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken");
    const token = await LaunchpadToken.deploy(deployerAddress, 10000);
    await token.deployed();
    console.log("LaunchpadToken= ", token.address);

    const TokenFactory = await ethers.getContractFactory("TokenFactory");
    const tokenFactory = await TokenFactory.deploy();
    await tokenFactory.deployed();
    console.log("TokenFactory= ", tokenFactory.address);

    const LaunchpadStaking = await ethers.getContractFactory("LaunchpadStaking");
    const launchpadStaking = await LaunchpadStaking.deploy(token.address);
    await launchpadStaking.deployed();
    console.log("LaunchpadStaking= ", launchpadStaking.address);

    const TokenMinter = await ethers.getContractFactory("TokenMinter");
    const tokenMinter = await TokenMinter.deploy(token.address, tokenFactory.address, launchpadStaking.address);
    await tokenMinter.deployed();
    console.log("TokenMinter= ", tokenMinter.address);

    const FundraiseFactory = await ethers.getContractFactory("FundraiseFactory");
    const fundraiseFactory = await FundraiseFactory.deploy(launchpadStaking.address);
    await fundraiseFactory.deployed();
    console.log("FundraiseFactory= ", fundraiseFactory.address);

    const ScheduleVestingFactory = await ethers.getContractFactory("ScheduleVestingFactory");
    const scheduleVestingFactory = await ScheduleVestingFactory.deploy();
    await scheduleVestingFactory.deployed();
    console.log("ScheduleVestingFactory= ", scheduleVestingFactory.address);

    const LinearVestingFactory = await ethers.getContractFactory("LinearVestingFactory");
    const linearVestingFactory = await LinearVestingFactory.deploy();
    await linearVestingFactory.deployed();
    console.log("LinearVestingFactory= ", linearVestingFactory.address);

    const LiquidityRouter = await ethers.getContractFactory("LiquidityRouter");
    const liquidityRouter = await LiquidityRouter.deploy(token.address, token.address);
    await liquidityRouter.deployed();
    console.log("LiquidityRouter= ", liquidityRouter.address);

    const LiquidityVault = await ethers.getContractFactory("LiquidityVault");
    const liquidityVault = await LiquidityVault.deploy(liquidityRouter.address);
    await liquidityVault.deployed();
    console.log("LiquidityVault= ", liquidityVault.address);

    const VestingOperator = await ethers.getContractFactory("VestingOperator");
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
    console.log("VestingOperator= ", vestingOperator.address);

    const BaseOperator = await ethers.getContractFactory("BaseOperator");
    const baseOperator = await BaseOperator.deploy(
        token.address,
        fundraiseFactory.address,
        vestingOperator.address,
        liquidityVault.address,
        launchpadStaking.address,
        tokenMinter.address
    );
    await baseOperator.deployed();
    console.log("BaseOperator= ", baseOperator.address);

    const LaunchpadDAO = await ethers.getContractFactory("LaunchpadDAO");
    const launchpadDAO = await LaunchpadDAO.deploy(
        token.address,
        launchpadStaking.address,
        tokenMinter.address,
        liquidityVault.address
    );
    await launchpadDAO.deployed();
    console.log("LaunchpadDAO= ", launchpadDAO.address);

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

    console.log("gemacht");

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

