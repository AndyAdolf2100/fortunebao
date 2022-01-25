// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "./FortunebaoInterface.sol";

contract CacusdtPriceOracle {
  uint private randNonce = 0;
  uint private modulus = 1000000;
  address private _owner;
  SetCacusdtPriceRecord[] private totalSetCacusdtPriceRecords;      // 全部爆块奖励发放记录列表

  mapping(uint256=>bool) pendingRequests;
  event GetLatestCacusdtPriceEvent(address callerAddress, uint id);
  event SetLatestCacusdtPriceEvent(uint256 cacusdtPrice, uint256 createdDate, address callerAddress);

  constructor() public {
    _owner = msg.sender;
  }

  // 更改ZZB价格记录
  struct SetCacusdtPriceRecord {
    uint cacusdtPrice;      // 价格
    uint createdDate;       // 创建日期
  }

  function getLatestCacusdtPrice() public returns (uint256) {
    randNonce++;
    uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % modulus;
    pendingRequests[id] = true;
    emit GetLatestCacusdtPriceEvent(msg.sender, id);
    return id;
  }

  // 获取全部设置ZZB价格的记录
  function getTotalSetCacusdtPriceRecords() view public returns(SetCacusdtPriceRecord[] memory) {
    return totalSetCacusdtPriceRecords;
  }

  function setLatestCacusdtPrice(uint256 _cacusdtPrice, address _callerAddress, uint256 _id) public onlyOwner {
    require(pendingRequests[_id], "This request is not in my pending list.");
    delete pendingRequests[_id];
    FortunebaoInterface callerContractInstance;
    callerContractInstance = FortunebaoInterface(_callerAddress);
    callerContractInstance.oracleCallback(_cacusdtPrice, _id);
    uint256 createdDate = block.timestamp;
    totalSetCacusdtPriceRecords.push(SetCacusdtPriceRecord(_cacusdtPrice, createdDate));
    emit SetLatestCacusdtPriceEvent(_cacusdtPrice, createdDate, _callerAddress);
  }

  function owner() public view virtual returns (address) {
    return _owner;
  }

  function transferOwnership(address newOwner) public virtual onlyOwner {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      _owner = newOwner;
  }

  modifier onlyOwner() {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
    _;
  }
}


