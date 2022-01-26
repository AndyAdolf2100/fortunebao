// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import {Utils} from "./Utils.sol";
import {Configuration} from "./Configuration.sol";
import {SafeMath} from "./utils/math/SafeMath.sol";
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

contract FortunbaoConfig {

  using SafeMath for uint;
  uint constant internal TO_WEI = 1000000000000000000;   // 1e18

  // 三轮白名单mapping以及地址列表
  mapping (address => uint) internal firstWhiteList;
  address[] internal firstAddresses;
  mapping (address => uint) internal secondWhiteList;
  address[] internal secondAddresses;
  mapping (address => uint) internal thirdWhiteList;
  address[] internal thirdAddresses;

  // 获取白名单可购买量
  function getWhiteAddressAmount(Configuration.ActivityType activityType) public view returns(uint) {
    if (activityType == Configuration.ActivityType.FIRST) {
      return firstWhiteList[msg.sender];
    }
    if (activityType == Configuration.ActivityType.SECOND) {
      return secondWhiteList[msg.sender];
    }
    if (activityType == Configuration.ActivityType.THIRD) {
      return thirdWhiteList[msg.sender];
    }
    require(true, 'iaT');
  }

  // 转换成Wei为单位
  function _toWei(uint _number) internal view returns (uint) {
    return _number.mul(TO_WEI);
  }


}
