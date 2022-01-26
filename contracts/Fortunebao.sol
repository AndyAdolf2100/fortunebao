// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./CACPAToken.sol";
import "./CACPBToken.sol";
import "./CACPCToken.sol";
import "./CACPToken.sol";
import "./Owner.sol";
import "./FortunbaoConfig.sol";
import "./Utils.sol";
/*
iaT: activityType illegal
imT: mealType illegal
 */
contract Fortunebao is Owner, FortunbaoConfig{
  using SafeMath for uint;
  // 黑洞地址
  address private burningAddress;
  address private priceLooper;  // 价格查询员
  IERC20 private firstToken;    // CACPA token
  IERC20 private secondToken;   // CACPB token
  IERC20 private thirdToken;    // CACPC token
  IERC20 private normalToken;   // CACP token
  ERC20  private bonusToken;    // CAC token 用于利息
  mapping(uint256=>bool) myRequests;      // oracle  调用请求
  uint private cacusdtPrice = _toWei(8);  // cacusdt 价格(默认是8) TODO

  uint targetUSDTValue = _toWei(500);

  // 质押、提取本金和利息、提取利息
  Deposit[] private totalDeposits; // 全部的充值信息(公开)
  Operation[] private allOperations; //  用户操作(公开)
  mapping (address => Deposit[]) public userDeposits; //  用户所有的储蓄记录

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
  event WithdrawSuccessEvent();  // 成功提取本金及利息
  event WithdrawInterestSuccessEvent();  // 成功提取利息

  constructor(address _bonusTokenAddress, address _burningAddress) public {
    // 质押TOKEN发布
    uint miningPoolAmount = _toWei(20000000);                      // 发行量2000万
    firstToken = new CACPAToken(msg.sender, miningPoolAmount);     // 发行CACPA合约
    secondToken = new CACPBToken(msg.sender, miningPoolAmount);    // 发行CACPB合约
    thirdToken = new CACPCToken(msg.sender, miningPoolAmount);     // 发行CACPC合约
    normalToken = new CACPToken(msg.sender, miningPoolAmount);     // 发行CACP合约

    // 利息Token初始化
    bonusToken = ERC20(_bonusTokenAddress);                        // 初始化CAC合约

    // 黑洞地址
    burningAddress = _burningAddress;
  }

  function setPriceLooper(address addr) public isOwner {
    priceLooper = addr;
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

  // 获取用户所有质押信息
  function myDeposits() public view returns(Deposit[] memory) {
    return userDeposits[msg.sender];
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
    bool needDepositPunishment;
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
    require(true, 'iaT');
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
        InterestInfo memory info = InterestInfo(
          tempDeposit,
          interest - tempDeposit.withdrawedInterest, // 应得利息减少已经提取的利息
          totalDepositDays >= maxBonusDays // 质押天数是否大于所需天数
        );
        return info;
      }
    }
  }

  // 仅提取利息
  function withdrawOnlyInterest(uint depositId) public noReentrancy {
    InterestInfo memory info = getInterest(depositId, 0);
    uint interest = info.interest;    // 得到利息
    Deposit memory d = info.deposit; // 得到操作的Deposit
    require(interest > 0, 'interest is zero');

    d.withdrawedInterest = d.withdrawedInterest.add(interest); // 记录应提取的withdrawedInterest

    Operation memory newOperation = Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
      msg.sender,        // 操作人
      interest,          // 操作数量
      block.timestamp,   // 当前时间
      string(abi.encodePacked("interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest)), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest.sub(interest))))), // 备注
      OperationType.WITHDRAW_INTEREST, // 操作类型: 只提取利息
      d // 记录引用
    );
    // 记录操作
    allOperations.push(newOperation);
    bonusToken.transfer(msg.sender, interest); // 利息转出
    emit WithdrawInterestSuccessEvent();
  }

  // 提取利息以及本金
  function withdrawPrincipal(uint depositId) public noReentrancy {
    InterestInfo memory info = getInterest(depositId, 0);
    uint interest = info.interest;    // 得到利息
    Deposit memory d = info.deposit; // 得到操作的Deposit
    bool needPublishment = info.needDepositPunishment; // 是否需要得到惩罚
    address transferTarget = msg.sender;
    uint principal = 0;

    d.withdrawedInterest = d.withdrawedInterest.add(interest); // 记录应提取的withdrawedInterest
    d.isWithdrawed = true; // 标记deposit已经提取本金

    if (!needPublishment || interest == 0) {
      Operation memory newOperation = Operation(
        uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
        msg.sender,        // 操作人
        interest,          // 利息 + 本金
        block.timestamp,   // 当前时间
        string(abi.encodePacked("depositAmount:", Utils.uint2str(uint(d.depositAmount)), "interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest)), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest.sub(interest))))), // 备注
        OperationType.WITHDRAW_PRINCIPAL, // 操作类型: 提取本金
        d // 记录引用
      );
      // 记录操作
      allOperations.push(newOperation);
      principal = d.depositAmount;
    } else {
      // 需要惩罚 惩罚的本金数量是利息的2倍, 最少可扣除至0, 扣除的cac转移到销毁地址
      Operation memory newOperation = Operation(
        uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, allOperations.length))), // UUID
        msg.sender,        // 操作人
        0,                 // 操作数量
        block.timestamp,   // 当前时间
        string(abi.encodePacked("depositAmount:", Utils.uint2str(uint(d.depositAmount)), "interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest)), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest.sub(interest))))), // 备注
        OperationType.WITHDRAW_PUBLISHMENT, // 操作类型: 提取接收惩罚
        d // 记录引用
      );
      // 记录操作
      allOperations.push(newOperation);
      // 转移地址变成销毁地址
      transferTarget = burningAddress;
      // 惩罚为利息2倍
      uint pAmount = interest.mul(2);
      // 还剩余本金的情况下有转账
      if (d.depositAmount > pAmount) {
        d.depositAmount.sub(pAmount);
      }
    }
    if (interest > 0) {
      bonusToken.transfer(transferTarget, interest); // 利息转出
    }
    if (principal > 0) {
      normalToken.transfer(msg.sender, principal); // 本金转出都转化为CACP
    }
    emit WithdrawSuccessEvent();
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
            activityType == ActivityType.NORMAL, 'iaT');
    // 校验mealType
    require(mealType == MealType.FIRST ||
            mealType == MealType.SECOND ||
            mealType == MealType.THIRD ||
            mealType == MealType.FORTH ||
            mealType == MealType.FIFTH, 'imT');

    // 允许合约对此用户token余额进行操作
    uint256 allowance = token.allowance(msg.sender, address(this));
    require(allowance >= depositAmount, string(abi.encodePacked("Check the token allowance: ", Utils.uint2str(allowance), ' depositAmount: ', Utils.uint2str(depositAmount))));

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
      string(abi.encodePacked("activityType:", Utils.uint2str(uint(tempDeposit.activityType)), '|mealType:', Utils.uint2str(uint(tempDeposit.mealType)))), // 备注
      OperationType.DEPOSIT, // 操作类型
      tempDeposit            // 记录引用
    );
    // 记录操作
    allOperations.push(newOperation);

    token.transferFrom(msg.sender, address(this), newDeposit.depositAmount); // 移动指定质押token余额至合约
    emit DepositSuccessEvent();
  }

  modifier isPriceLooper() {
      require(msg.sender == priceLooper || msg.sender == owner, "Caller is not priceLooper");
      _;
  }
}
