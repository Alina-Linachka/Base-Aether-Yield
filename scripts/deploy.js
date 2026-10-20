const hre = require("hardhat");
async function main() {
  const PoolData = await hre.ethers.getContractFactory("AetherYieldPool");
  const aetherPool = await PoolData.deploy();
  await aetherPool.deployed();
  console.log("-> Aether Yield Pool active at:", aetherPool.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
