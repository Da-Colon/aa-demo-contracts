import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;  // Destructuring necessary variables from Hardhat runtime
  const { deploy } = deployments;  // Destructuring the "deploy" function from deployments

  const { deployer } = await getNamedAccounts();  // Fetching the deployer's account

  // Goerli testnet EntryPoint address for UserOperations
  const entryPointaddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"

  // Deploying the ERC20 Token Contract "MakoShard" from deployer account
  const erc20Token = await deploy('MakoShard', {
    from: deployer,
    log: true,
  });

  // Deploying the "TokenPaymaster" contract, passing the EntryPoint and ERC20 token addresses as arguments to the contract's constructor
  const tokenPaymaster = await deploy('TokenPaymaster', {
    from: deployer,
    args: [entryPointaddress, erc20Token.address],
    log: true,
  });

  // Getting an instance of the "TokenPaymaster" contract
  const tokenPaymasterInstance = await ethers.getContractAt('TokenPaymaster', tokenPaymaster.address);

  // Making an initial deposit to the TokenPaymaster contract
  const initialDeposit = ethers.utils.parseEther("0.1");
  await (await tokenPaymasterInstance.deposit({ value: initialDeposit })).wait();

  // Adding a stake to the TokenPaymaster contract
  const oneWeekInSeconds = 604800;
  await (await tokenPaymasterInstance.addStake(oneWeekInSeconds, { value: initialDeposit })).wait();

  // Logging the addresses of the deployed contracts
  console.log("MakoShard deployed to:", erc20Token.address);
  console.log("TokenPaymaster deployed to:", tokenPaymaster.address);
};

// Tags used for organizing and filtering deployment scripts
func.tags = ['TokenPaymaster', 'MakoShard'];

// Exporting the deployment function as default
export default func;
