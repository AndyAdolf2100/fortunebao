// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./CACPAToken.sol";
import "./CACPBToken.sol";
import "./CACPCToken.sol";
import "./CACPToken.sol";
import "./Owner.sol";
import "./FortunebaoConfig.sol";
import "./FortunebaoData.sol";
import "./Configuration.sol";
import "./Utils.sol";

contract FortunebaoDataOperation is FortunbaoConfig {
  using SafeMath for uint;
  FortunebaoData data; // 数据合约 所有常规不变数据从这里面取

  constructor(address _dataContract) {
    data = FortunebaoData(_dataContract);
  }

  function getAllOperationIds() public view returns(uint[] memory) {
    uint[] memory totalIds = new uint[](data.getAllOperations().length);
    for (uint i = 0; i < data.getAllOperations().length; i ++) {
      Configuration.Operation[] memory ds = data.getAllOperations();
      totalIds[i] = ds[i].id;
    }
    return totalIds;
  }

  function getOperationId(uint index) public view returns(uint) {
    return data.getAllOperations()[index].id;
  }

  function getOperationUser(uint index) public view returns(address) {
    return data.getAllOperations()[index].user;
  }

  function getOperationAmount(uint index) public view returns(uint) {
    return data.getAllOperations()[index].amount;
  }

  function getOperationCreatedDate(uint index) public view returns(uint) {
    return data.getAllOperations()[index].createdDate;
  }

  function getOperationType(uint index) public view returns(Configuration.OperationType) {
    return data.getAllOperations()[index].operationType;
  }

  function getOperationComment(uint index) public view returns(string memory) {
    return data.getAllOperations()[index].comment;
  }

  function getOperationDepositId(uint index) public view returns(uint) {
    return data.getAllOperations()[index].depositId;
  }




}
