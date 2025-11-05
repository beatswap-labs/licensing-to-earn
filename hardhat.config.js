require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.27",
  paths: {
    sources: "./opbnb/contracts",
    tests: "./opbnb/test",
    cache: "./opbnb/cache",
    artifacts: "./opbnb/artifacts"
  },
  networks: {
    opbnb: {
      url: process.env.OP_BNB_RPC_URL || "https://opbnb-mainnet-rpc.bnbchain.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 204
    }
  }
};
