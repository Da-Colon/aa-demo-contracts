import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const entryPointaddress = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789" // (goerli)

  const erc20Token = await deploy('MakoShard', {
    from: deployer,
    log: true,
  });

  const tokenPaymaster = await deploy('TokenPaymaster', {
    from: deployer,
    args: [entryPointaddress, erc20Token.address],
    log: true,
  });

  const tokenPaymasterInstance = await ethers.getContractAt('TokenPaymaster', tokenPaymaster.address);
  const initialDeposit = ethers.utils.parseEther("0.1");

  await (await tokenPaymasterInstance.deposit({ value: initialDeposit })).wait();

  const oneWeekInSeconds = 604800;
  await (await tokenPaymasterInstance.addStake(oneWeekInSeconds, { value: initialDeposit })).wait();

  console.log("MakoShard deployed to:", erc20Token.address);
  console.log("TokenPaymaster deployed to:", tokenPaymaster.address);
};

func.tags = ['TokenPaymaster', 'MakoShard'];
export default func;
