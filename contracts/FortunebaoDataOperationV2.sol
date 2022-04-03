// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import "./FortunebaoConfig.sol";
import "./FortunebaoData.sol";
import "./Configuration.sol";

contract FortunebaoDataOperationV2 is FortunbaoConfig {
  using SafeMath for uint;
  FortunebaoData data; // 数据合约 所有常规不变数据从这里面取

  constructor(address _dataContract) {
    data = FortunebaoData(_dataContract);
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
