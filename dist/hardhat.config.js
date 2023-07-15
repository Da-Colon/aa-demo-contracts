"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
require("@typechain/hardhat");
require("solidity-coverage");
require("@nomiclabs/hardhat-etherscan");
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const config = {
    solidity: {
        compilers: [
            {
                version: '0.8.18',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    namedAccounts: {
        deployer: 0,
    },
    typechain: {
        outDir: 'typechain',
        target: 'ethers-v5',
    },
    verify: {
        etherscan: {
            apiKey: process.env.ETHERSCAN_API_KEY
        }
    },
    networks: {
        mainnet: {
            chainId: 1,
            url: process.env.MAINNET_PROVIDER || "",
            accounts: process.env.MAINNET_DEPLOYER_PRIVATE_KEY
                ? [process.env.MAINNET_DEPLOYER_PRIVATE_KEY]
                : [],
        },
        goerli: {
            chainId: 5,
            url: process.env.GOERLI_PROVIDER || "",
            accounts: process.env.GOERLI_DEPLOYER_PRIVATE_KEY
                ? [process.env.GOERLI_DEPLOYER_PRIVATE_KEY]
                : [],
        },
        sepolia: {
            chainId: 11155111,
            url: process.env.SEPOLIA_PROVIDER || "",
            accounts: process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY
                ? [process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY]
                : [],
        },
    }
};
exports.default = config;
