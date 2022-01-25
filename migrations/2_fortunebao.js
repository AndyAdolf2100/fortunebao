const CacToken = artifacts.require("CacToken");
const Fortunebao = artifacts.require("Fortunebao");
const CacusdtOracle = artifacts.require("CacusdtPriceOracle");

module.exports = async function (deployer) {
  await deployer.deploy(CacusdtOracle); // 获取cacusdt的价格合约
  await deployer.deploy(CacToken);      // 创造cac的合约
  const token = await CacToken.deployed();
  const oracle = await CacusdtOracle.deployed();
  const burning_address = "0x68ED61f76F6d016bF43595d5BAaC29249db3beF8";
  await deployer.deploy(Fortunebao, token.address, oracle.address, burning_address);
};
