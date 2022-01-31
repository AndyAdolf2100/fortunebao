// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./utils/math/SafeMath.sol";

library Configuration{

  using SafeMath for uint;

  uint private constant FIRST_MEAL_DAYS = 30;               // 第一个套餐：30天
  uint private constant SECOND_MEAL_DAYS = 60;              // 第二个套餐：60天
  uint private constant THIRD_MEAL_DAYS = 90;               // 第三个套餐：90天
  uint private constant FORTH_MEAL_DAYS = 180;              // 第四个套餐：180天
  uint private constant FIFTH_MEAL_DAYS = 360;              // 第五个套餐：360天

  enum OperationType { DEPOSIT, WITHDRAW_PRINCIPAL, WITHDRAW_INTEREST, WITHDRAW_PUBLISHMENT } // 质押、提现本金、提现利息、惩罚提现
  enum ActivityType { FIRST, SECOND, THIRD, NORMAL } // 第1、2、3轮以及常态轮
  enum MealType { FIRST, SECOND, THIRD, FORTH, FIFTH } // 第1、2、3、4、5套餐

  uint constant internal MIN_BONUS = 100000000000000;    // 最小奖励(小数点后4位)

  // 储蓄记录
  struct Deposit {
    uint id;                    // ID
    address user;               // 储蓄人
    uint depositAmount;         // 储蓄金额
    uint cacusdtPrice;          // 价格
    uint createdDate;           // 操作时间
    uint calcInterestDate;      // 开始计息时间(次日00:00 +0800)
    uint withdrawedInterest;    // 已提取的利息
    bool isWithdrawed;          // 是否提取本金
    ActivityType activityType;  // 活动类型
    MealType mealType;          // 套餐类型
  }

  // 用户操作 公开可读
  struct Operation {
    uint id;                      // 操作ID
    address user;                 // 操作地址
    uint amount;                  // 操作数量
    uint createdDate;             // 操作时间
    string comment;               // 备注
    OperationType operationType;  // 操作类型
    uint depositId;               // DepositId
  }

  // 返回的信息
  struct InterestInfo {
    Deposit deposit;
    uint interest;
    bool needDepositPunishment;
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

  // 获取每一个套餐的对应利率获得的利息
  function _makeInterestRate(MealType mealType, uint amount) internal view returns(uint) {
    require(amount > 0, 'illegal amount');
    if (mealType == MealType.FIRST) {
      return amount.mul(15).div(3000);
    }
    if (mealType == MealType.SECOND) {
      return amount.mul(17).div(3000);
    }
    if (mealType == MealType.THIRD) {
      return amount.mul(20).div(3000);
    }
    if (mealType == MealType.FORTH) {
      return amount.mul(24).div(3000);
    }
    if (mealType == MealType.FIFTH) {
      return amount.mul(30).div(3000);
    }
    require(true, 'imT');
  }

  // 保留4位小数
  function _rounding(uint _number) internal view returns (uint) {
    return (_number.add(MIN_BONUS.div(2))).div(MIN_BONUS).mul(MIN_BONUS);
  }



}
