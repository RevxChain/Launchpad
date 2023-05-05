const hre = require("hardhat");
const ethers = hre.ethers;
const { mine } = require("@nomicfoundation/hardhat-network-helpers");
const helpers = require("@nomicfoundation/hardhat-network-helpers");



async function balanceOf(address, msg = '') {
    const balanceOf = await ethers.provider.getBalance(address);
    console.log(msg, ethers.utils.formatEther(balanceOf));
}

async function main() {
  
  

  const [signer] = await ethers.getSigners();


  const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken", signer);
  const token = await LaunchpadToken.deploy(signer.address, 10000);
  await token.deployed();
  console.log(`${token.address}`);

  console.log(token.address);



  const launchpadTokenAddress = token.address;

  await balanceOf(token.address, 'Ether LaunchpadToken balance: ');
  await balanceOf(signer.address, 'Ether Signer balance: ');

  const actualTime = await token.checkTime();
  console.log(actualTime);

  // advance time by one hour and mine a new block
  //await helpers.time.increase(3600);

  // mine a new block with timestamp `newTimestamp`
  //await helpers.time.increaseTo(newTimestamp);

  // set the timestamp of the next block but don't mine a new block
  //await helpers.time.setNextBlockTimestamp(newTimestamp);

  await mine(10); // 1 block == 1 second

  const actualTime2 = await token.checkTime();
  console.log(actualTime2);

  await helpers.time.increase(3600);

  const actualTime3 = await token.checkTime();
  console.log(actualTime3);

  


 

}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
