const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with:", deployer.address);
  console.log("Network:", hre.network.name);

  const IPLicensingIndex = await hre.ethers.getContractFactory("IPLicensingIndex");
  const contract = await IPLicensingIndex.deploy(deployer.address);

  await contract.waitForDeployment();
  console.log("IPLicensingIndex deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
