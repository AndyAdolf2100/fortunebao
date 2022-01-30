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
import "./FortunebaoData.sol";
import "./Configuration.sol";
import "./Utils.sol";
/*
错误信息:
iaT: activityType illegal
imT: mealType illegal
 */
contract Fortunebao is Owner, FortunbaoConfig{
  using SafeMath for uint;

  FortunebaoData data; // 数据合约 所有常规不变数据从这里面取
  uint targetUSDTValue = _toWei(500); // 500等价U

  event DepositSuccessEvent();  // 成功质押
  event WithdrawSuccessEvent();  // 成功提取本金及利息
  event WithdrawInterestSuccessEvent();  // 成功提取利息

  constructor(address _dataContract) public {
    data = FortunebaoData(_dataContract);
  }

  function addWhiteList(Configuration.ActivityType activityType, uint amount, address addr) public isOwner {
    data.setWhiteAddressAmount(addr, amount, activityType);
    data.pushAddresses(addr, activityType);
  }

  // 计算利息
  function getInterest(uint depositId, uint nowTime) public view returns(Configuration.InterestInfo memory) {
    if (nowTime == 0) {
      nowTime = block.timestamp;
    }
    Configuration.Deposit memory tempDeposit = data.getTotalDepositMapping(depositId);
    uint totalDepositDays = 0;
    // 质押时间: 天数
    if (nowTime > tempDeposit.calcInterestDate) {
      totalDepositDays = ((nowTime.sub(tempDeposit.calcInterestDate)).div(1 days));
    }
    // 套餐收益最大天数
    uint maxBonusDays = Configuration._getMaxBonusDays(tempDeposit.mealType);
    // 可获得收益的天数
    uint bonusDays = totalDepositDays > maxBonusDays ? maxBonusDays : totalDepositDays; // 获取收益天数最大为套餐天数
    // 计算利息(活动倍数 + 不同套餐费率)
    uint interest = 0;
    if (bonusDays > 0) {
      interest = Configuration._getInterestIncreaseRate(tempDeposit.activityType, Configuration._makeInterestRate(tempDeposit.mealType, tempDeposit.depositAmount.mul(bonusDays)));
    }
    Configuration.InterestInfo memory info = Configuration.InterestInfo(
      tempDeposit,
      interest - tempDeposit.withdrawedInterest, // 应得利息减少已经提取的利息
      totalDepositDays < maxBonusDays // 质押天数是否大于所需天数 套餐所需天数
    );
    return info;
  }

  // 仅提取利息
  function withdrawOnlyInterest(uint depositId, uint nowTime) public noReentrancy {
    if (nowTime == 0) {
      nowTime = block.timestamp;
    }
    Configuration.InterestInfo memory info = getInterest(depositId, nowTime);
    uint interest = info.interest;    // 得到利息
    Configuration.Deposit memory d = info.deposit; // 得到操作的Deposit
    require(interest > 0, 'interest is zero');

    data.increaseDepositWithdrawedInterest(d.id, interest);

    uint oLength = data.getAllOperations().length;
    Configuration.Operation memory newOperation = Configuration.Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, oLength))), // UUID
      msg.sender,        // 操作人
      interest,          // 操作数量
      block.timestamp,   // 当前时间
      string(abi.encodePacked("interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest.add(interest))), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest)))), // 备注
      Configuration.OperationType.WITHDRAW_INTEREST, // 操作类型: 只提取利息
      d.id
    );

    // 记录操作
    data.pushAllOperations(newOperation);

    // require(false, string(abi.encodePacked("oLength:", Utils.uint2str(oLength))));

    data.getBonusToken().transfer(msg.sender, interest); // 利息转出
    emit WithdrawInterestSuccessEvent();
  }

  // 提取利息以及本金
  function withdrawPrincipal(uint depositId, uint nowTime) public noReentrancy {
    if (nowTime == 0) {
      nowTime = block.timestamp;
    }
    Configuration.InterestInfo memory info = getInterest(depositId, nowTime);
    uint interest = info.interest;    // 得到利息
    Configuration.Deposit memory d = info.deposit; // 得到操作的Deposit
    bool needPublishment = info.needDepositPunishment; // 是否需要得到惩罚
    address transferTarget = msg.sender; // 转移目标地址(黑洞/用户账户)
    uint transferAmount = 0; // 黑洞燃烧/利息提取
    uint principal = 0;

    data.increaseDepositWithdrawedInterest(d.id, interest);
    data.setDepositWithdrawed(d.id);

    uint oLength = data.getAllOperations().length;
    if (!needPublishment || interest == 0) {
      Configuration.Operation memory newOperation = Configuration.Operation(
        uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, oLength))), // UUID
        msg.sender,        // 操作人
        interest,          // 利息 + 本金
        block.timestamp,   // 当前时间
        string(abi.encodePacked("depositAmount:", Utils.uint2str(uint(d.depositAmount)), "|interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest.add(interest))), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest)))), // 备注
        Configuration.OperationType.WITHDRAW_PRINCIPAL, // 操作类型: 提取本金
        d.id
      );
      // 记录操作
      data.pushAllOperations(newOperation);
      principal = d.depositAmount;
      transferAmount = interest;
    } else {
      uint pAmount = interest.mul(2);
      // 需要惩罚 惩罚的本金数量是利息的2倍, 最少可扣除至0, 扣除的cac转移到销毁地址
      Configuration.Operation memory newOperation = Configuration.Operation(
        uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, oLength))), // UUID
        msg.sender,        // 操作人
        pAmount,           // 惩罚数量
        block.timestamp,   // 当前时间
        string(abi.encodePacked("depositAmount:", Utils.uint2str(uint(d.depositAmount)), "|interest:", Utils.uint2str(uint(interest)), "|newWithdrawedInterest:", Utils.uint2str(uint(d.withdrawedInterest.add(interest))), '|oldWithdrawedInterest:', Utils.uint2str(uint(d.withdrawedInterest)))), // 备注
        Configuration.OperationType.WITHDRAW_PUBLISHMENT, // 操作类型: 提取接收惩罚
        d.id
      );
      // 记录操作
      data.pushAllOperations(newOperation);
      // 转移地址变成销毁地址
      transferTarget = data.getBurningAddress();
      // 惩罚为利息2倍
      // 还剩余本金的情况下有转账
      if (d.depositAmount > pAmount) {
        principal = d.depositAmount.sub(pAmount);
      }
      transferAmount = pAmount;
    }
    if (transferAmount > 0) {
      data.getBonusToken().transfer(transferTarget, transferAmount); // 利息转出
    }
    if (principal > 0) {
      // normalToken
      data.getPurchaseToken(Configuration.ActivityType.NORMAL).transfer(msg.sender, principal); // 本金转出都转化为CACP
    }
    emit WithdrawSuccessEvent();
  }


  // 白名单质押
  // 1. 需要根据白名单列表来进行判断, 非白名单用户不能参加
  // 2. 可以参与的地址以及参与质押数量固定
  // 3. 只要活动类型以及套餐类型可以选择
  function depositInWhiteList(Configuration.ActivityType activityType, Configuration.MealType mealType) public noReentrancy {
    uint depositAmount = data.getWhiteAddressAmount(msg.sender, activityType);
    data.setWhiteAddressAmount(msg.sender, 0, activityType); // 将可申购量去除
    IERC20 token = data.getPurchaseToken(activityType);
    require(token.balanceOf(msg.sender) >= depositAmount, "Balance not enough");
    require(depositAmount > 0, 'You are not in whiteList');
    _generalUserDepositRecord(token, depositAmount, activityType, mealType);
  }

  // 当前价格所需要的最小存入数量
  function validNormalAmount() public view returns(uint) {
    return targetUSDTValue.mul(TO_WEI).div(data.getCacPrice());
  }

  // 普通质押
  function depositNormally(uint depositAmount, Configuration.MealType mealType) public noReentrancy{
    require(data.getPurchaseToken(Configuration.ActivityType.NORMAL).balanceOf(msg.sender) >= depositAmount, "Balance not enough");
    _generalUserDepositRecord(data.getPurchaseToken(Configuration.ActivityType.NORMAL), depositAmount, Configuration.ActivityType.NORMAL, mealType);
  }

  // 生成质押记录
  function _generalUserDepositRecord(IERC20 token, uint depositAmount, Configuration.ActivityType activityType, Configuration.MealType mealType) private {
    require(depositAmount / TO_WEI > 0, 'Deposit amount is too less'); // 质押必须大于1个
    // 校验depositAmount
    require((depositAmount * data.getCacPrice()) / TO_WEI > targetUSDTValue, 'Deposit amount value is too less');
    // 校验depositAmount
    require(depositAmount > 0, 'Deposit amount must more than zero');
    // 校验activityType
    require(activityType == Configuration.ActivityType.FIRST ||
            activityType == Configuration.ActivityType.SECOND ||
            activityType == Configuration.ActivityType.THIRD ||
            activityType == Configuration.ActivityType.NORMAL, 'iaT');
    // 校验mealType
    require(mealType == Configuration.MealType.FIRST ||
            mealType == Configuration.MealType.SECOND ||
            mealType == Configuration.MealType.THIRD ||
            mealType == Configuration.MealType.FORTH ||
            mealType == Configuration.MealType.FIFTH, 'imT');

    // 允许合约对此用户token余额进行操作
    uint256 allowance = token.allowance(msg.sender, address(this));
    require(allowance >= depositAmount, string(abi.encodePacked("Check the token allowance: ", Utils.uint2str(allowance), ' depositAmount: ', Utils.uint2str(depositAmount))));

    uint newDepositId = data.getTotalDeposits().length.add(1);

    uint currentTime = block.timestamp;
    Configuration.Deposit memory newDeposit = Configuration.Deposit(
      newDepositId,              // ID
      msg.sender,                // 储蓄人
      depositAmount,             // 质押数量
      data.getCacPrice(),        // 质押的价格
      currentTime,               // 当前时间
      currentTime - ((currentTime + 8 hours) % 86400) + 1 days, // 计息时间次日00:00 +0800
      0,                 // 已提取的本金初始值
      false,             // 是否已经提取本金
      activityType,      // 活动类型(一, 二, 三轮, 常态)
      mealType           // 套餐类型(五个套餐)
    );

    // 记录质押
    data.pushTotalDeposits(newDeposit);

    Configuration.Operation memory newOperation = Configuration.Operation(
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, data.getAllOperations().length))), // UUID
      msg.sender,                // 操作人
      newDeposit.depositAmount,  // 操作数量
      block.timestamp,           // 当前时间
      string(abi.encodePacked("activityType:", Utils.uint2str(uint(newDeposit.activityType)), '|mealType:', Utils.uint2str(uint(newDeposit.mealType)))), // 备注
      Configuration.OperationType.DEPOSIT, // 操作类型
      newDeposit.id
    );
    // 记录操作
    data.pushAllOperations(newOperation);

    token.transferFrom(msg.sender, address(this), newDeposit.depositAmount); // 移动指定质押token余额至合约
    emit DepositSuccessEvent();
  }

}
