const CacToken = artifacts.require("CacToken");
const Fortunebao = artifacts.require("Fortunebao");
const FortunebaoData = artifacts.require("FortunebaoData");

module.exports = async function (deployer) {
  await deployer.deploy(CacToken);      // 创造cac的合约
  const token = await CacToken.deployed();
  const burning_address = "0xD91901Faa4A654534Fe4F9974b52080779D0071F";
  await deployer.deploy(FortunebaoData, token.address, burning_address);
  const dataContract = await FortunebaoData.deployed();
  await deployer.deploy(Fortunebao, dataContract.address);
};
