import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const entryPointAddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

  console.log("Starting deployment...");

  // Deploying the contracts
  console.log("Deploying MakoEnergy...");
  const makoEnergy = await deploy('MakoEnergy', {
    from: deployer,
    log: true,
  });

  console.log("Deploying MakoShard...");
  const makoShard = await deploy('MakoShard', {
    from: deployer,
    log: true,
  });

  console.log("Deploying MakoAccountFactory...");
  const makoAccountFactory = await deploy('MakoAccountFactory', {
    from: deployer,
    args: [entryPointAddress],
    log: true,
  });

  console.log("Deploying TokenPaymaster...");
  const tokenPaymaster = await deploy('TokenPaymaster', {
    from: deployer,
    args: [entryPointAddress, makoShard.address],
    log: true,
  });

  console.log("Deploying SubscriptionPaymaster...");
  const subscriptionCost = ethers.utils.parseEther("3");
  const subscriptionPaymaster = await deploy('SubscriptionPaymaster', {
    from: deployer,
    args: [entryPointAddress, makoShard.address, subscriptionCost],
    log: true,
  });

  console.log("All contracts have been deployed...");

  // Creating contract instances
  console.log("Creating contract instances...");
  const tokenPaymasterInstance = await ethers.getContractAt('TokenPaymaster', tokenPaymaster.address);
  const subscriptionPaymasterInstance = await ethers.getContractAt('SubscriptionPaymaster', subscriptionPaymaster.address);

  console.log("Contract instances created...");

  // Making initial deposits and adding stakes
  console.log("Making initial deposits and adding stakes...");
  const initialDeposit = ethers.utils.parseEther("0.1");

  await (await tokenPaymasterInstance.deposit({ value: initialDeposit })).wait();
  await (await tokenPaymasterInstance.addStake(604800, { value: initialDeposit })).wait();

  await (await subscriptionPaymasterInstance.deposit({ value: initialDeposit })).wait();
  await (await subscriptionPaymasterInstance.addStake(604800, { value: initialDeposit })).wait();

  console.log("Deposits and stakes added...");

  // Logging the addresses of the deployed contracts
  console.log("MakoEnergy deployed to:", makoEnergy.address);
  console.log("MakoShard deployed to:", makoShard.address);
  console.log("MakoAccountFactory deployed to:", makoAccountFactory.address);
  console.log("TokenPaymaster deployed to:", tokenPaymaster.address);
  console.log("SubscriptionPaymaster deployed to:", subscriptionPaymaster.address);
};

func.tags = ['Full-Deployment'];
export default func;
