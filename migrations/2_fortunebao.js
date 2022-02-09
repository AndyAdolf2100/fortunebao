const CacToken = artifacts.require("CacToken");
const FortunebaoV2 = artifacts.require("FortunebaoV2");
const FortunebaoData = artifacts.require("FortunebaoData");

module.exports = async function (deployer) {
  //await deployer.deploy(CacToken);      // 创造cac的合约
  //const token = await CacToken.deployed(); // 测试CACtoken
  //const burning_address = "0xD91901Faa4A654534Fe4F9974b52080779D0071F"; // 测试黑洞地址
  //await deployer.deploy(FortunebaoData, token.address, burning_address);

  // const burning_address = "0xa85712ef3c01596A6830509118646d0C2ff18a76"; // 正式黑洞地址
  // const cacAddress = "0x4d66769a287a6296f8e9e968234017fc0f03b55e"; // CAC合约地址
  // await deployer.deploy(FortunebaoData, cacAddress, burning_address);

  //const dataContract = await FortunebaoData.deployed();
  //await deployer.deploy(FortunebaoV2, dataContract.address);
  await deployer.deploy(FortunebaoV2, '0x88b8cF3e170EfCd7873512fabBF685C3A53792ad');
};
