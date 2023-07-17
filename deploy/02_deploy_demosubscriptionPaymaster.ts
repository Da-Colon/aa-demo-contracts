// Importing necessary libraries and types
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;  // Destructuring necessary variables from Hardhat runtime
  const { deploy } = deployments;  // Destructuring the "deploy" function from deployments

  const { deployer } = await getNamedAccounts();  // Fetching the deployer's account

  // Goerli testnet EntryPoint address for UserOperations
  const entryPointAddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

  // Deploying the ERC20 Token Contract "MakoShard" from deployer account
  const erc20Token = await deploy('MakoShard', {
    from: deployer,
    log: true,
  });

  // Deploying the "MakoAccountFactory" contract, passing the EntryPoint address as an argument to the constructor
  const smartAccount = await deploy('MakoAccountFactory', {
    from: deployer,
    args: [entryPointAddress],
    log: true,
  });

  // Setting the cost of subscription in ether
  const subscriptionCost = ethers.utils.parseEther("3");

  // Deploying the "SubscriptionPaymaster" contract, passing the EntryPoint, ERC20 token addresses, and subscription cost as arguments to the constructor
  const subscriptionPaymaster = await deploy('SubscriptionPaymaster', {
    from: deployer,
    args: [entryPointAddress, erc20Token.address, subscriptionCost],
    log: true,
  });

  // Getting an instance of the "SubscriptionPaymaster" contract
  const subscriptionPaymasterInstance = await ethers.getContractAt('SubscriptionPaymaster', subscriptionPaymaster.address);

  // Making an initial deposit to the SubscriptionPaymaster contract
  const initialDeposit = ethers.utils.parseEther("0.1");
  await (await subscriptionPaymasterInstance.deposit({ value: initialDeposit })).wait();

  // Adding a stake to the SubscriptionPaymaster contract
  const oneWeekInSeconds = 604800;
  await (await subscriptionPaymasterInstance.addStake(oneWeekInSeconds, { value: initialDeposit })).wait();

  // Logging the addresses of the deployed contracts
  console.log("MakoShard deployed to:", erc20Token.address);
  console.log("MakoAccountFactory deployed to:", smartAccount.address);
  console.log("SubscriptionPaymaster deployed to:", subscriptionPaymaster.address);
};

// Tags used for organizing and filtering deployment scripts
func.tags = ['SubscriptionPaymaster', 'MakoEnergy'];

// Exporting the deployment function as default
export default func;
