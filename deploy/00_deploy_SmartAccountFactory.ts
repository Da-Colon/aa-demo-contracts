import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import 'hardhat-deploy';
// @note this deployment script
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  try {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;

    await deploy('MakoAccountFactory', {
      from: deployer,
      args: ["0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"],
      log: true,
    });

  } catch (e) {
    console.error(e);
    process.exitCode = 1;
  }
};

func.tags = ['MakoAccountFactory'];
export default func;