import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-deploy';
import "@nomiclabs/hardhat-ethers";
import 'hardhat-gas-reporter';
import '@typechain/hardhat';
import 'solidity-coverage';
import "@nomiclabs/hardhat-etherscan";
declare const config: HardhatUserConfig;
export default config;
