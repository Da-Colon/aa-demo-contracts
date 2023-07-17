import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const entryPointAddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"; // (goerli)

  const erc20Token = await deploy('MakoShard', {
    from: deployer,
    log: true,
  });

  const smartAccount = await deploy('SmartAccountFactory', {
    from: deployer,
    args: [entryPointAddress],
    log: true,
  });
  const subsciptionCost = ethers.utils.parseEther("3");
  const subscriptionPaymaster = await deploy('SubscriptionPaymaster', {
    from: deployer,
    args: [entryPointAddress, erc20Token.address, subsciptionCost],
    log: true,
  });

  const subscriptionPaymasterInstance = await ethers.getContractAt('SubscriptionPaymaster', subscriptionPaymaster.address);
  const initialDeposit = ethers.utils.parseEther("0.1");

  await (await subscriptionPaymasterInstance.deposit({ value: initialDeposit })).wait();

  const oneWeekInSeconds = 604800;
  await (await subscriptionPaymasterInstance.addStake(oneWeekInSeconds, { value: initialDeposit })).wait();

  console.log("MakoShard deployed to:", erc20Token.address);
  console.log("SmartAccountFactory deployed to:", smartAccount.address);
  console.log("SubscriptionPaymaster deployed to:", subscriptionPaymaster.address);
};

func.tags = ['SubscriptionPaymaster', 'DemoNFT'];
export default func;
