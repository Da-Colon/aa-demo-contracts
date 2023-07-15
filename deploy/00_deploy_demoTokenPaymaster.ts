// Importing the ethers.js library which provides functionalities for interacting with Ethereum
import { ethers } from 'ethers';

// Importing Hardhat runtime environment (HRE), which is a development tool for Ethereum software
const hre = require("hardhat");

async function main() {

  // Fetch accounts from the local Ethereum node. These could be the accounts you have set up in your hardhat network or your metamask accounts.
  const accounts = await hre.ethers.getSigners();

  // Define the addresses of your custom contract dependencies. These values should be replaced with actual contract addresses deployed on the blockchain.
  const token = "0xYourTokenAddress";
  const entryPoint = "0xYourEntryPointAddress";
  const wrappedNative = "0xYourWrappedNativeAddress";
  const uniswap = "0xYourUniswapRouterAddress";

  // Define the configurations for the TokenPaymaster contract. These settings configure things like price markup, minimum balance etc.
  const tokenPaymasterConfig = {
    "priceMarkup": 1000000,  // 100% markup
    "minEntryPointBalance": 50000000000000000,  // 0.05 ETH (or other native token)
    "refundPostopCost": 21000,  // cost of a standard Ethereum transaction
    "priceMaxAge": 60 * 60 * 24  // 24 hours
  }

  // Define configurations for the oracle helper. This includes addresses for the token and native oracles and other settings.
  const oracleHelperConfig = {
    tokenOracle: "0xYourTokenOracleAddress",
    nativeOracle: "0xYourNativeOracleAddress",
    tokenToNativeOracle: true,
    tokenOracleReverse: false,
    nativeOracleReverse: false,
    priceUpdateThreshold: 0.01 * 1e6, // 1% threshold
    cacheTimeToLive: 60 * 60 * 24, // 24 hours
  };

  // Define configurations for the Uniswap helper. This includes settings like the minimum swap amount, pool fee and slippage.
  const uniswapHelperConfig = {
    minSwapAmount: ethers.utils.parseEther('0.01'), // Minimum of 0.01 ETH
    uniswapPoolFee: 3000, // Uniswap pool fee of 0.3%
    slippage: 50 // 5% slippage
  };

  // Define the owner of the contract. In this case, we're taking the first account from the list of accounts fetched earlier.
  const owner = accounts[0].address;

  // Fetch the Contract Factory for TokenPaymaster. A Contract Factory in ethers.js is an abstraction used to deploy new smart contracts.
  const TokenPaymaster = await hre.ethers.getContractFactory("TokenPaymaster");

  // Use the Contract Factory to deploy a new TokenPaymaster contract. This is done by passing the necessary arguments to the `deploy` method.
  const tokenPaymaster = await TokenPaymaster.deploy(
    token,
    entryPoint,
    wrappedNative,
    uniswap,
    tokenPaymasterConfig,
    oracleHelperConfig,
    uniswapHelperConfig,
    owner
  );

  // Wait for the contract to be mined on the blockchain.
  await tokenPaymaster.deployed();

  // Log the address of the newly deployed contract.
  console.log("TokenPaymaster deployed to:", tokenPaymaster.address);
}

// Call the main function and handle any errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
