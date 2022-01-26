// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import "./utils/math/SafeMath.sol";
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
*/

contract FortunbaoConfig {

  using SafeMath for uint;
  uint constant internal TO_WEI = 1000000000000000000;   // 1e18
  uint constant internal MIN_BONUS = 100000000000000;    // 最小奖励(小数点后4位)

  uint private FIRST_MEAL_DAYS = 30;               // 第一个套餐：30天
  uint private SECOND_MEAL_DAYS = 60;              // 第二个套餐：60天
  uint private THIRD_MEAL_DAYS = 90;               // 第三个套餐：90天
  uint private FORTH_MEAL_DAYS = 180;              // 第四个套餐：180天
  uint private FIFTH_MEAL_DAYS = 360;              // 第五个套餐：360天

  // 三轮白名单mapping以及地址列表
  mapping (address => uint) internal firstWhiteList;
  address[] internal firstAddresses;
  mapping (address => uint) internal secondWhiteList;
  address[] internal secondAddresses;
  mapping (address => uint) internal thirdWhiteList;
  address[] internal thirdAddresses;

  enum OperationType { DEPOSIT, WITHDRAW_PRINCIPAL, WITHDRAW_INTEREST, WITHDRAW_PUBLISHMENT } // 质押、提现本金、提现利息、惩罚提现
  enum ActivityType { FIRST, SECOND, THIRD, NORMAL } // 第1、2、3轮以及常态轮
  enum MealType { FIRST, SECOND, THIRD, FORTH, FIFTH } // 第1、2、3、4、5套餐

  // 获取白名单可购买量
  function getWhiteAddressAmount(ActivityType activityType) public view returns(uint) {
    if (activityType == ActivityType.FIRST) {
      return firstWhiteList[msg.sender];
    }
    if (activityType == ActivityType.SECOND) {
      return secondWhiteList[msg.sender];
    }
    if (activityType == ActivityType.THIRD) {
      return thirdWhiteList[msg.sender];
    }
    require(true, 'iaT');
  }

  // 转换成Wei为单位
  function _toWei(uint _number) internal view returns (uint) {
    return _number.mul(TO_WEI);
  }

  // 保留4位小数
  function _rounding(uint _number) internal view returns (uint) {
    return (_number.add(MIN_BONUS.div(2))).div(MIN_BONUS).mul(MIN_BONUS);
  }

  // 获取每一个套餐的对应最大质押天数
  function _getMaxBonusDays(MealType mealType) internal view returns(uint) {
    if (mealType == MealType.FIRST) {
      return FIRST_MEAL_DAYS;
    }
    if (mealType == MealType.SECOND) {
      return SECOND_MEAL_DAYS;
    }
    if (mealType == MealType.THIRD) {
      return THIRD_MEAL_DAYS;
    }
    if (mealType == MealType.FORTH) {
      return FORTH_MEAL_DAYS;
    }
    if (mealType == MealType.FIFTH) {
      return FIFTH_MEAL_DAYS;
    }
    require(true, 'imT');
  }

  // 获取每一个套餐的对应利率获得的利息
  function _makeInterestRate(MealType mealType, uint amount) internal view returns(uint) {
    require(amount > 0, 'illegal amount');
    if (mealType == MealType.FIRST) {
      return _rounding(amount.mul(15).div(3000));
    }
    if (mealType == MealType.SECOND) {
      return _rounding(amount.mul(17).div(3000));
    }
    if (mealType == MealType.THIRD) {
      return _rounding(amount.mul(20).div(3000));
    }
    if (mealType == MealType.FORTH) {
      return _rounding(amount.mul(24).div(3000));
    }
    if (mealType == MealType.FIFTH) {
      return _rounding(amount.mul(30).div(3000));
    }
    require(true, 'imT');
  }

  // 获取每期活动的利率增加比例并添加后返回
  function _getInterestIncreaseRate(ActivityType activityType, uint interest) internal view returns(uint) {
    if (activityType == ActivityType.FIRST) {
      return interest.mul(2); // 2倍
    }
    if (activityType == ActivityType.SECOND) {
      return interest.mul(15).div(10); // 1.5倍
    }
    if (activityType == ActivityType.THIRD) {
      return interest.mul(13).div(10); // 1.3倍
    }
    if (activityType == ActivityType.NORMAL) {
      return interest; // 没有增加
    }
    require(true, 'iaT');
  }


}
