// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./utils/math/SafeMath.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./Owner.sol";
import "./CACPAToken.sol";
import "./CACPBToken.sol";
import "./CACPCToken.sol";
import "./CACPToken.sol";
import "./Configuration.sol";
import "./Utils.sol";
/*
  理财宝智能合约:

  1. 四期活动一览:
  第一轮: 2倍利息
  第二轮: 1.5倍利息
  第三轮: 1.3倍利息
  常态轮: 利息正常

  2. 五个套餐利息一览:
  第一个：每日千5, 计息30天
  第二个：每日千566666, 计息60天 0.17 / 30
  第三个：每日千666666, 计息90天 0.2 / 30
  第四个：每日千8, 计息180天
  第五个：每日百1, 计息360天

  3. 次日0:00开始计算收益时间

  4. 减产(待研究)
*/

contract FortunebaoData is Owner{

  using SafeMath for uint;

  address private burningAddress; // 销毁地址
  address private priceLooper;  // 价格查询员
  IERC20 private firstToken;    // CACPA token
  IERC20 private secondToken;   // CACPB token
  IERC20 private thirdToken;    // CACPC token
  IERC20 private normalToken;   // CACP token
  ERC20  private bonusToken;    // CAC token 用于利息
  uint private cacusdtPrice = _toWei(8);  // cacusdt 价格(默认是8) TODO

  uint targetUSDTValue = _toWei(500);

  // 三轮白名单mapping以及地址列表
  mapping (address => uint) internal firstWhiteList;
  address[] internal firstAddresses;
  mapping (address => uint) internal secondWhiteList;
  address[] internal secondAddresses;
  mapping (address => uint) internal thirdWhiteList;
  address[] internal thirdAddresses;

  // 获取白名单可购买量
  function getWhiteAddressAmount(address addr, Configuration.ActivityType activityType) public view returns(uint) {
    if (activityType == Configuration.ActivityType.FIRST) {
      return firstWhiteList[addr];
    }
    if (activityType == Configuration.ActivityType.SECOND) {
      return secondWhiteList[addr];
    }
    if (activityType == Configuration.ActivityType.THIRD) {
      return thirdWhiteList[addr];
    }
    require(true, 'iaT');
  }

  // 设置白名单可购买量
  function setWhiteAddressAmount(address addr, Configuration.ActivityType activityType, uint amount) public {
    if (activityType == Configuration.ActivityType.FIRST) {
      firstWhiteList[addr] = amount;
    }
    if (activityType == Configuration.ActivityType.SECOND) {
      secondWhiteList[addr] = amount;
    }
    if (activityType == Configuration.ActivityType.THIRD) {
      thirdWhiteList[addr] = amount;
    }
    require(true, 'iaT');
  }

}
