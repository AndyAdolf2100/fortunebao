// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./utils/math/SafeMath.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./CACPAToken.sol";
import "./CACPBToken.sol";
import "./CACPCToken.sol";
import "./CACPToken.sol";
import "./FortunebaoConfig.sol";
import "./Configuration.sol";
import "./Utils.sol";
import "./Owner.sol";
/*
  财富宝智能合约:

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

contract FortunebaoData is Owner, FortunbaoConfig{
  using SafeMath for uint;

  uint public newDepositId = 0;          // 记录depositID
  address private burningAddress; // 销毁地址
  address private priceLooper;  // 价格查询员
  IERC20 private firstToken;    // CACPA token
  IERC20 private secondToken;   // CACPB token
  IERC20 private thirdToken;    // CACPC token
  IERC20 private normalToken;   // CACP token
  ERC20  private bonusToken;    // CAC token 用于利息
  uint private cacusdtPrice = _toWei(8);  // cacusdt 价格(默认是8) TODO

  // 质押、提取本金和利息、提取利息
  Configuration.Deposit[] public totalDeposits; // 全部的充值信息(公开) isWithdrawed 和 已提现的利息字段不作数
  mapping (uint => Configuration.Deposit) public totalDepositMappings; // ID快速查找Deposit(公开)
  Configuration.Operation[] public allOperations; //  用户操作(公开)
  mapping (address => bool) userJoined; // 判断用户是否参与了活动
  address[] userAddresses; // 用户地址列表
  mapping (address => Configuration.Deposit[]) public userDeposits; //  用户所有的储蓄记录

  // 三轮白名单mapping以及地址列表
  mapping (address => uint) private firstWhiteList;
  address[] public firstAddresses;
  // 判断是否参与过此轮活动
  mapping (address => bool) private firstJoined;

  mapping (address => uint) private secondWhiteList;
  address[] public secondAddresses;
  mapping (address => bool) private secondJoined;

  mapping (address => uint) private thirdWhiteList;
  address[] public thirdAddresses;
  mapping (address => bool) private thirdJoined;

  mapping (address => bool) accessAllowed;

  constructor(address _bonusTokenAddress, address _burningAddress) public {
    // 质押TOKEN发布
    bonusToken = ERC20(_bonusTokenAddress);                        // CAC合约
    uint miningPoolAmount = _toWei(20000000);                      // 发行量2000万
    firstToken = new CACPAToken(msg.sender, miningPoolAmount);     // 发行CACPA合约
    secondToken = new CACPBToken(msg.sender, miningPoolAmount);    // 发行CACPB合约
    thirdToken = new CACPCToken(msg.sender, miningPoolAmount);     // 发行CACPC合约
    normalToken = new CACPToken(msg.sender, miningPoolAmount);     // 发行CACP合约
    priceLooper = msg.sender;
    accessAllowed[msg.sender] = true;
    burningAddress = _burningAddress;
  }

  // 是否用户参与了活动
  function isUserJoined(address user) public view returns(bool) {
    return userJoined[user];
  }

  // 存入用户地址列表
  function setUserAddresses(address user) public platform{
    if (!isUserJoined(user)) {
      userJoined[user] = true;
      userAddresses.push(user);
    }
  }

  // 取出用户地址列表
  function getUserAddresses() public view returns(address[] memory){
    return userAddresses;
  }

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

  function getTotalDepositMapping(uint depositId) public view returns (Configuration.Deposit memory){
    return totalDepositMappings[depositId];
  }

  // 设置白名单可购买量
  function setWhiteAddressAmount(address addr, uint amount, Configuration.ActivityType activityType) public platform{
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

  // 向地址列表中存放
  function pushAddresses(address addr, Configuration.ActivityType activityType) public platform{
    if (activityType == Configuration.ActivityType.FIRST && !firstJoined[addr]) {
      firstJoined[addr] = true;
      firstAddresses.push(addr);
    }
    if (activityType == Configuration.ActivityType.SECOND && !secondJoined[addr]) {
      secondJoined[addr] = true;
      secondAddresses.push(addr);
    }
    if (activityType == Configuration.ActivityType.THIRD && !thirdJoined[addr]) {
      thirdJoined[addr] = true;
      thirdAddresses.push(addr);
    }
    require(true, 'iaT');
  }

  function getTotalDeposits() public view returns(Configuration.Deposit[] memory) {
    return totalDeposits;
  }

  function getAllOperations() public view returns(Configuration.Operation[] memory) {
    return allOperations;
  }

  // 获取cac
  function getBonusToken() public view returns(IERC20) {
    return bonusToken;
  }

  // 获取cacp系列token
  // activityType: 0, 1, 2, 3
  function getPurchaseToken(Configuration.ActivityType activityType) public view returns(IERC20) {
    if (activityType == Configuration.ActivityType.FIRST) {
      return firstToken;
    }
    if (activityType == Configuration.ActivityType.SECOND) {
      return secondToken;
    }
    if (activityType == Configuration.ActivityType.THIRD) {
      return thirdToken;
    }
    return normalToken;
  }

  function getUserDeposits(address addr) public view returns(Configuration.Deposit[] memory) {
    return userDeposits[addr];
  }

  // push new Deposit
  function pushTotalDeposits(Configuration.Deposit memory d) public platform {
    totalDeposits.push(d);
  }

  // push new Operation
  function pushAllOperations(Configuration.Operation memory o) public platform {
    allOperations.push(o);
  }

  // 设置价格 1e18
  function setCacPrice(uint price) public isPriceLooper{
    cacusdtPrice = price;
  }

  // 获取cac价格
  function getCacPrice() public view returns(uint){
    return cacusdtPrice;
  }

  // 设置价格查询者
  function setPriceLooper(address addr) public isOwner {
    priceLooper = addr;
  }

  function getBurningAddress() public view returns(address){
    return burningAddress;
  }

  // 增长Deposit已收入利息
  function increaseDepositWithdrawedInterest(uint depositId, uint interest) public platform{
    Configuration.Deposit storage d = totalDepositMappings[depositId];
    d.withdrawedInterest = d.withdrawedInterest.add(interest);
    // userDeposits 需要也调整一下
    for(uint i = 0; i < userDeposits[d.user].length ; i ++) {
      if (userDeposits[d.user][i].id == d.id) {
        userDeposits[d.user][i].withdrawedInterest = d.withdrawedInterest;
        break;
      }
    }
  }

  // 设置Deposit已提取
  function setDepositWithdrawed(uint depositId) public platform{
    Configuration.Deposit storage d = totalDepositMappings[depositId];
    d.isWithdrawed = true;
    // userDeposits 需要也调整一下
    for(uint i = 0; i < userDeposits[d.user].length ; i ++) {
      if (userDeposits[d.user][i].id == d.id) {
        userDeposits[d.user][i].isWithdrawed = true;
        break;
      }
    }
  }

  modifier isPriceLooper() {
    require(msg.sender == priceLooper || msg.sender == owner, "Caller is not priceLooper");
    _;
  }

  modifier platform() {
    require(accessAllowed[msg.sender] == true, 'platform not allowed');
    _;
  }

  function allowAccess(address _addr) platform public {
    accessAllowed[_addr] = true;
  }

  function denyAccess(address _addr) platform public {
    accessAllowed[_addr] = false;
  }

  function setNewDepositId(uint newId) public platform{
    newDepositId = newId;
  }

  // 记录用户的deposits
  function pushUserDeposits(uint depositId, address addr) public platform{
    Configuration.Deposit storage tempDeposit = totalDepositMappings[depositId];
    require(addr == tempDeposit.user, 'user deposit addr error');
    userDeposits[addr].push(tempDeposit);
  }

  // 记录deposit到大map上
  function autoSetTotalDepositMapping(Configuration.Deposit memory tempDeposit) public platform {
    require(totalDeposits.length > 0, 'totalDeposits length equal 0');
    // Configuration.Deposit storage tempDeposit = totalDeposits[totalDeposits.length - 1];
    // require(addr == tempDeposit.user, 'user deposit addr error');
    require(totalDepositMappings[tempDeposit.id].id == 0, 'deposit id has been declared');
    totalDepositMappings[tempDeposit.id] = tempDeposit;
  }


}
