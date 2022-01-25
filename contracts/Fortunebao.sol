// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./utils/math/SafeMath.sol";
import "./CACPAToken.sol";
import "./CACPBToken.sol";
import "./CACPCToken.sol";
import "./CACPToken.sol";
import "./CacusdtPriceOracleInterface.sol";
import "./Owner.sol";
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

contract Fortunebao is Owner{

  using SafeMath for uint;

  uint constant private TO_WEI = 1000000000000000000;   // 1e18
  uint constant private MIN_BONUS = 100000000000000;    // 最小奖励(小数点后4位)

  // 获取cac的USDT价格
  CacusdtPriceOracleInterface private oracleInstance;
  address private oracleAddress;

  // 黑洞地址
  address private burningAddress;

  uint private SATISFY_USDT_VALUE = _toWei(500);   // 价值500USDT
  uint private FIRST_MEAL_DAYS = 30;               // 第一个套餐：30天
  uint private SECOND_MEAL_DAYS = 60;              // 第二个套餐：60天
  uint private THIRD_MEAL_DAYS = 90;               // 第三个套餐：90天
  uint private FORTH_MEAL_DAYS = 180;              // 第四个套餐：180天
  uint private FIFTH_MEAL_DAYS = 360;              // 第五个套餐：360天

  //uint private FIRST_BONUS_RATE = 1.mul(2);             // 第一期活动：2倍
  //uint private SECOND_BONUS_RATE = 1.mul(15).div(10);   // 第二期活动：1.5倍
  //uint private THIRD_BONUS_RATE = 1.mul(13).div(10);    // 第三期活动：1.3倍
  //uint private NORMAL_BONUS_RATE = 1;                   // 常态轮活动：1倍

  uint private COMMON_DENOMINATOR = 1000;   // 通用分母

  // 三轮白名单mapping以及地址列表
  mapping (address => uint) private firstWhiteList;
  address[] private firstAddresses;
  mapping (address => uint) private secondWhiteList;
  address[] private secondAddresses;
  mapping (address => uint) private thirdWhiteList;
  address[] private thirdAddresses;

  address private priceLooper;  // 价格查询员

  IERC20 private firstToken;    // CACPA token
  IERC20 private secondToken;   // CACPB token
  IERC20 private thirdToken;    // CACPC token
  IERC20 private normalToken;   // CACP token
  ERC20  private bonusToken;    // CAC token 用于利息

  bool private isEnd = false;   // 是否活动已经结束

  mapping(uint256=>bool) myRequests;      // oracle  调用请求
  uint private cacusdtPrice = _toWei(8);  // cacusdt 价格(默认是8) TODO

  uint targetUSDTValue = _toWei(500);

  // 质押、提取本金和利息、提取利息
  Deposit[] private totalDeposits; // 全部的充值信息(公开)
  Operation[] private allOperations; //  用户操作(公开)
  mapping (address => Deposit[]) public userDeposits; //  用户所有的储蓄记录

  enum OperationType { DEPOSIT, WITHDRAW_PRINCIPAL, WITHDRAW_INTEREST } // 质押、提现本金、提现利息
  enum ActivityType { FIRST, SECOND, THIRD, NORMAL } // 第1、2、3轮以及常态轮
  enum MealType { FIRST, SECOND, THIRD, FORTH, FIFTH } // 第1、2、3、4、5套餐

  mapping (address => bool) private userRequestLocked; // 用户一个请求未确认的时候不能进行下一个请求

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
    Deposit deposit;              // 操作的储蓄记录
  }

  event DepositSuccessEvent();  // 成功质押
  event WithdrawSuccessEvent();  // 成功提取
  event WithdrawInterestSuccessEvent();  // 成功提取利息

  constructor(address _bonusTokenAddress, address _oracleAddress, address _burningAddress) public {
    require(!isEnd, 'Activity is not opened!');
    // 质押TOKEN发布
    uint miningPoolAmount = _toWei(20000000);                      // 发行量2000万
    firstToken = new CACPAToken(msg.sender, miningPoolAmount);     // 发行CACPA合约
    secondToken = new CACPBToken(msg.sender, miningPoolAmount);    // 发行CACPB合约
    thirdToken = new CACPCToken(msg.sender, miningPoolAmount);     // 发行CACPC合约
    normalToken = new CACPToken(msg.sender, miningPoolAmount);     // 发行CACP合约

    // 利息Token初始化
    bonusToken = ERC20(_bonusTokenAddress);                        // 初始化CAC合约
    // 预言机初始化
    oracleAddress = _oracleAddress;
    oracleInstance = CacusdtPriceOracleInterface(_oracleAddress);  // 初始化Oracle

    // 黑洞地址
    burningAddress = _burningAddress;
  }

  function setPriceLooper(address addr) public isOwner {
    priceLooper = addr;
  }

  // 1e18
  function setTargetUSDTValue (uint value) public isOwner {
    targetUSDTValue = value;
  }

  // 1e18
  function setCacPrice(uint price) public isPriceLooper{
    cacusdtPrice = price;
  }

  function addWhiteList(ActivityType activityType, uint amount, address addr) public isOwner {
    if (activityType == ActivityType.FIRST) {
      firstWhiteList[addr] = amount;
      firstAddresses.push(addr);
    }
    if (activityType == ActivityType.SECOND) {
      secondWhiteList[addr] = amount;
      secondAddresses.push(addr);
    }
    if (activityType == ActivityType.THIRD) {
      thirdWhiteList[addr] = amount;
      thirdAddresses.push(addr);
    }
  }

  // 获取白名单
  function getWhiteList(ActivityType activityType) public view isOwner returns(address[] memory){
    if (activityType == ActivityType.FIRST) {
      return firstAddresses;
    }
    if (activityType == ActivityType.SECOND) {
      return secondAddresses;
    }
    if (activityType == ActivityType.THIRD) {
      return thirdAddresses;
    }
    require(true, 'illegal activityType');
  }

  // 获取用户所有质押信息
  function myDeposits() public view returns(Deposit[] memory) {
    return userDeposits[msg.sender];
  }

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
    require(true, 'illegal activityType');
  }

  function getBonusToken() public view returns(IERC20) {
    return bonusToken;
  }

  // activityType: 0, 1, 2, 3
  function getPurchaseToken(ActivityType activityType) public view returns(IERC20) {
    if (activityType == ActivityType.FIRST) {
      return firstToken;
    }
    if (activityType == ActivityType.SECOND) {
      return secondToken;
    }
    if (activityType == ActivityType.THIRD) {
      return thirdToken;
    }
    return normalToken;
  }

  function getTotalDeposits() public view returns(Deposit[] memory) {
    return totalDeposits;
  }

  function getAllOperations() public view returns(Operation[] memory) {
    return allOperations;
  }

  struct InterestInfo {
    Deposit deposit;
    uint interest;
  }

  // 计算利息
  function getInterest(uint depositId, uint nowTime) public view returns(InterestInfo memory) {
    if (nowTime == 0) {
      nowTime = block.timestamp;
    }
    for (uint i = 0; i < userDeposits[msg.sender].length; i ++) {
      if (userDeposits[msg.sender][i].id == depositId) {
        Deposit storage tempDeposit = userDeposits[msg.sender][i];
        uint totalDepositDays = 0;
        // 质押时间: 天数
        if (nowTime > tempDeposit.calcInterestDate) {
          totalDepositDays = ((nowTime.sub(tempDeposit.calcInterestDate)).div(1 days));
        }
        // 套餐收益最大天数
        uint maxBonusDays = _getMaxBonusDays(tempDeposit.mealType);
        // 可获得收益的天数
        uint bonusDays = totalDepositDays > maxBonusDays ? maxBonusDays : totalDepositDays; // 获取收益天数最大为套餐天数
        // 计算利息(活动倍数 + 不同套餐费率)
        uint interest = 0;
        if (bonusDays > 0) {
          interest = _getInterestIncreaseRate(tempDeposit.activityType, _makeInterestRate(tempDeposit.mealType, tempDeposit.depositAmount.mul(bonusDays)));
        }
        //uint interest = _toWei(1) * maxBonusDays * totalDepositDays;
        InterestInfo memory info = InterestInfo(
          tempDeposit,
          interest - tempDeposit.withdrawedInterest // 应得利息减少已经提取的利息
        );
        return info;
      }
    }
  }

  // 仅提取利息
  function withdrawOnlyInterest(uint depositId) public noReentrancy {
    uint interest = getInterest(depositId, 0).interest;    // 得到利息
    Deposit memory d = getInterest(depositId, 0).deposit; // 得到操作的Deposit
    d.withdrawedInterest = d.withdrawedInterest.add(interest); // 记录应提取的withdrawedInterest

    Operation memory newOperation = Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
      msg.sender,        // 操作人
      interest,          // 操作数量
      block.timestamp,   // 当前时间
      string(abi.encodePacked("interest:", uint2str(uint(interest)), "|newWithdrawedInterest:", uint2str(uint(d.withdrawedInterest)), '|oldWithdrawedInterest:', uint2str(uint(d.withdrawedInterest.sub(interest))))), // 备注
      OperationType.WITHDRAW_INTEREST, // 操作类型: 只提取利息
      d // 记录引用
    );
    // 记录操作
    allOperations.push(newOperation);
    normalToken.transfer(msg.sender, d.depositAmount); // 本金转出都转化为CACP
  }

  // 提取利息以及本金
  function withdrawPrincipal(uint depositId) public noReentrancy {
    uint interest = getInterest(depositId, 0).interest;    // 得到利息
    Deposit memory d = getInterest(depositId, 0).deposit; // 得到操作的Deposit
    d.withdrawedInterest = d.withdrawedInterest.add(interest); // 记录应提取的withdrawedInterest
    d.isWithdrawed = true; // 标记deposit已经提取本金

    Operation memory newOperation = Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
      msg.sender,        // 操作人
      interest,          // 利息 + 本金
      block.timestamp,   // 当前时间
      string(abi.encodePacked("depositAmount:", uint2str(uint(d.depositAmount)), "interest:", uint2str(uint(interest)), "|newWithdrawedInterest:", uint2str(uint(d.withdrawedInterest)), '|oldWithdrawedInterest:', uint2str(uint(d.withdrawedInterest.sub(interest))))), // 备注
      OperationType.WITHDRAW_PRINCIPAL, // 操作类型: 提取本金
      d // 记录引用
    );
    // 记录操作
    allOperations.push(newOperation);
    bonusToken.transfer(msg.sender, interest); // 利息转出
    normalToken.transfer(msg.sender, d.depositAmount); // 本金转出都转化为CACP
  }


  // 白名单质押
  // 1. 需要根据白名单列表来进行判断, 非白名单用户不能参加
  // 2. 可以参与的地址以及参与质押数量固定
  // 3. 只要活动类型以及套餐类型可以选择
  function depositInWhiteList(ActivityType activityType, MealType mealType) public noReentrancy {
    address joiner = msg.sender;
    uint depositAmount = 0;
    IERC20 token;
    if (activityType == ActivityType.FIRST) {
      token = firstToken;
      depositAmount = firstWhiteList[joiner];
      firstWhiteList[joiner] = 0;
    }
    if (activityType == ActivityType.SECOND) {
      depositAmount = secondWhiteList[joiner];
      secondWhiteList[joiner] = 0;
      token = secondToken;
    }
    if (activityType == ActivityType.THIRD) {
      depositAmount = thirdWhiteList[joiner];
      thirdWhiteList[joiner] = 0;
      token = thirdToken;
    }
    require(token.balanceOf(msg.sender) >= depositAmount, "Balance not enough");
    require(depositAmount > 0, 'You are not in whiteList');
    _generalUserDepositRecord(token, depositAmount, activityType, mealType);
  }

  // 当前价格所需要的最小存入数量
  function validNormalAmount() public view returns(uint) {
    return targetUSDTValue.mul(TO_WEI).div(cacusdtPrice);
  }

  // 普通质押
  function depositNormally(uint depositAmount, MealType mealType) public noReentrancy{
    require(normalToken.balanceOf(msg.sender) >= depositAmount, "Balance not enough");
    _generalUserDepositRecord(normalToken, depositAmount, ActivityType.NORMAL, mealType);
  }

  // 生成质押记录
  function _generalUserDepositRecord(IERC20 token, uint depositAmount, ActivityType activityType, MealType mealType) private {

    require(depositAmount / TO_WEI > 0, 'Deposit amount is too less'); // 质押必须大于1个
    // 校验depositAmount
    require((depositAmount * cacusdtPrice) / TO_WEI > targetUSDTValue, 'Deposit amount value is too less');
    // 校验depositAmount
    require(depositAmount > 0, 'Deposit amount must more than zero');
    // 校验activityType
    require(activityType == ActivityType.FIRST ||
            activityType == ActivityType.SECOND ||
            activityType == ActivityType.THIRD ||
            activityType == ActivityType.NORMAL, string(abi.encodePacked("activityType is illegal: ", uint2str(uint(activityType)))));
    // 校验mealType
    require(mealType == MealType.FIRST ||
            mealType == MealType.SECOND ||
            mealType == MealType.THIRD ||
            mealType == MealType.FORTH ||
            mealType == MealType.FIFTH, string(abi.encodePacked("mealType is illegal: ", uint2str(uint(mealType)))));

    // 允许合约对此用户token余额进行操作
    uint256 allowance = token.allowance(msg.sender, address(this));
    require(allowance >= depositAmount, string(abi.encodePacked("Check the token allowance: ", uint2str(allowance), ' depositAmount: ', uint2str(depositAmount))));

    uint newDepositId = totalDeposits.length.add(1);

    Deposit memory newDeposit = Deposit(
      newDepositId,              // ID
      msg.sender,                // 储蓄人
      depositAmount,             // 质押数量
      cacusdtPrice,              // 当前质押的数量
      block.timestamp,           // 当前时间
      block.timestamp - ((block.timestamp + 8 hours) % 86400) + 1 days, // 计息时间次日00:00 +0800
      0,                 // 已提取的本金初始值
      false,             // 是否已经提取本金
      activityType,      // 活动类型(一, 二, 三轮, 常态)
      mealType           // 套餐类型(五个套餐)
    );

    // 记录质押
    totalDeposits.push(newDeposit);

    // 获取引用
    Deposit storage tempDeposit = totalDeposits[totalDeposits.length - 1];
    userDeposits[msg.sender].push(tempDeposit);

    Operation memory newOperation = Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
      msg.sender,                // 操作人
      newDeposit.depositAmount,  // 操作数量
      block.timestamp,           // 当前时间
      string(abi.encodePacked("activityType:", uint2str(uint(tempDeposit.activityType)), '|mealType:', uint2str(uint(tempDeposit.mealType)))), // 备注
      OperationType.DEPOSIT, // 操作类型
      tempDeposit            // 记录引用
    );
    // 记录操作
    allOperations.push(newOperation);

    token.transferFrom(msg.sender, address(this), newDeposit.depositAmount); // 移动指定质押token余额至合约
    emit DepositSuccessEvent();
  }

  // 转换成Wei为单位
  function _toWei(uint _number) private view returns (uint) {
    return _number.mul(TO_WEI);
  }

  // 保留4位小数
  function _rounding(uint _number) private view returns (uint) {
    return (_number.add(MIN_BONUS.div(2))).div(MIN_BONUS).mul(MIN_BONUS);
  }

  // uint转字符串
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
  }

  // 获取每期活动的利率增加比例并添加后返回
  function _getInterestIncreaseRate(ActivityType activityType, uint interest) private view returns(uint) {
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
    require(true, 'illegal activityType');
  }

  // 获取每一个套餐的对应最大质押天数
  function _getMaxBonusDays(MealType mealType) private view returns(uint) {
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
    require(true, 'illegal mealType');
  }

  // 获取每一个套餐的对应利率获得的利息
  function _makeInterestRate(MealType mealType, uint amount) private view returns(uint) {
    require(amount > 0, '_makeInterestRate: illegal amount');
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
    require(true, 'illegal mealType');
  }

  modifier noReentrancy() {
    require(
      !userRequestLocked[msg.sender],
      "Reentrancy call."
    );
    userRequestLocked[msg.sender] = true;
    _;
    userRequestLocked[msg.sender] = false;
  }

  modifier isPriceLooper() {
      require(msg.sender == priceLooper || msg.sender == owner, "Caller is not priceLooper");
      _;
  }
}
