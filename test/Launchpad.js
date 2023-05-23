const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const hre = require("hardhat");
const ethers = hre.ethers;

describe("Launchpad", function () {
    async function deployLaunchpadFixture() {

        const [owner, userOne, userTwo, userThree] = await ethers.getSigners();

        const amountToMint = 100000;

        const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken", owner);
        const launchpadToken = await LaunchpadToken.deploy(owner.address, amountToMint);
        await launchpadToken.deployed();

        const TokenFactory = await ethers.getContractFactory("TokenFactory", owner);
        const tokenFactory = await TokenFactory.deploy();
        await tokenFactory.deployed();

        const LaunchpadStaking = await ethers.getContractFactory("LaunchpadStaking", owner);
        const launchpadStaking = await LaunchpadStaking.deploy(launchpadToken.address);
        await launchpadStaking.deployed();

        const TokenMinter = await ethers.getContractFactory("TokenMinter", owner);
        const tokenMinter = await TokenMinter.deploy(launchpadToken.address, tokenFactory.address, launchpadStaking.address);
        await tokenMinter.deployed();

        const FundraiseFactory = await ethers.getContractFactory("FundraiseFactory", owner);
        const fundraiseFactory = await FundraiseFactory.deploy(launchpadStaking.address);
        await fundraiseFactory.deployed();

        const ScheduleVestingFactory = await ethers.getContractFactory("ScheduleVestingFactory", owner);
        const scheduleVestingFactory = await ScheduleVestingFactory.deploy();
        await scheduleVestingFactory.deployed();

        const LinearVestingFactory = await ethers.getContractFactory("LinearVestingFactory", owner);
        const linearVestingFactory = await LinearVestingFactory.deploy();
        await linearVestingFactory.deployed();

        const LiquidityRouter = await ethers.getContractFactory("LiquidityRouter", owner);
        const liquidityRouter = await LiquidityRouter.deploy(launchpadToken.address, launchpadToken.address);
        await liquidityRouter.deployed();

        const LiquidityVault = await ethers.getContractFactory("LiquidityVault", owner);
        const liquidityVault = await LiquidityVault.deploy(liquidityRouter.address);
        await liquidityVault.deployed();

        const VestingOperator = await ethers.getContractFactory("VestingOperator", owner);
        const vestingOperator = await VestingOperator.deploy(
            launchpadToken.address,
            fundraiseFactory.address,
            scheduleVestingFactory.address,
            linearVestingFactory.address,
            tokenFactory.address,
            liquidityVault.address,
            launchpadStaking.address
        );
        await vestingOperator.deployed();

        const BaseOperator = await ethers.getContractFactory("BaseOperator", owner);
        const baseOperator = await BaseOperator.deploy(
            launchpadToken.address,
            fundraiseFactory.address,
            vestingOperator.address,
            liquidityVault.address,
            launchpadStaking.address,
            tokenMinter.address
        );
        await baseOperator.deployed();

        const LaunchpadDAO = await ethers.getContractFactory("LaunchpadDAO", owner);
        const launchpadDAO = await LaunchpadDAO.deploy(
            launchpadToken.address,
            launchpadStaking.address,
            tokenMinter.address,
            liquidityVault.address
        );
        await launchpadDAO.deployed();

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
        //----------------------------------------


        /*
      const mintValue = 500;
  
      await token.connect(user).approve(tokenMinter.address, mintValue);
  
      await tokenMinter.connect(user).createToken(
          "fuck", 
          "fuck u",
          0,
          0,
          1999,
          false
      );
  
      const newTokenAddress = await tokenMinter.allNotSupportedTokens(0);
      console.log('Minted token address = ', newTokenAddress);
  
      const tokenMinterContract = await ethers.getContractAt("ERC20Token", newTokenAddress);
  
  
      const tokenMinterTokenBalance = await token.balanceOf(tokenMinter.address);
      console.log('Token minter token balance = ', tokenMinterTokenBalance);
  
      const newTokenUserBalance = await tokenMinterContract.balanceOf(user.address);
      console.log('newTokenUserBalance = ', newTokenUserBalance);*/

        return {
            owner, userOne, userTwo, userThree, launchpadToken, tokenFactory,
            launchpadStaking, tokenMinter, fundraiseFactory, scheduleVestingFactory,
            linearVestingFactory, liquidityRouter, liquidityVault, vestingOperator,
            baseOperator, launchpadDAO, amountToMint
        };
    }

    describe("Deposit", function () {
        it("Should mint the right amount", async function () {
            const { owner, launchpadToken, amountToMint } = await loadFixture(deployLaunchpadFixture);

            expect(await launchpadToken.balanceOf(owner.address)).to.equal(amountToMint);
        });

    });
})