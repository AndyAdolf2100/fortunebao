const CacToken = artifacts.require("CacToken"); // Cac合约
const CacusdtPriceOracle = artifacts.require("CacusdtPriceOracle");
const Fortunebao = artifacts.require("Fortunebao");
const cactoken = require('../build/contracts/CacToken.json')
const cacpatoken = require('../build/contracts/CACPAToken.json')
const cacpbtoken = require('../build/contracts/CACPBToken.json')
const cacpctoken = require('../build/contracts/CACPCToken.json')
const cacptoken = require('../build/contracts/CACPToken.json')
//const cacusdtPriceOracle = require('../build/contracts/CacusdtPriceOracle.json')

contract("FortunebaoTest", (accounts) => {
    let catchRevert = require("./utils/exceptions.js").catchRevert;

    let [alice, bob] = accounts; // 获取两个地址

    function toWei(number_str) {
      return number_str + '000000000000000000'
    }

    function currentTime() {
      return  Date.parse(new Date()) / 1000
    }

    // activity_type 0, 1, 2
    // meal_type 0, 1, 2, 3, 4
    async function purchase_in_white_list(activity_type, meal_type) {
      let purchaseRequest =  await contractInstance.depositInWhiteList(activity_type, meal_type, {from: alice})
      console.log('GasUsed: ' + purchaseRequest.receipt.gasUsed.toString())

      totalDeposits = await contractInstance.getTotalDeposits()
      allOperations = await contractInstance.getAllOperations()

      console.log('totalDeposits == ')
      console.log(totalDeposits)
      console.log('allOperations == ')
      console.log(allOperations)
    }

    // 购买数量,套餐类型,循环次数
    async function purchase(amount, meal_type, number) {
      for(let i = 0; i < number; i++ ) {
        // 调用购买矿机的方法
        let purchaseRequest = await contractInstance.depositNormally(amount, meal_type, {from: alice})
        console.log('GasUsed: ' + purchaseRequest.receipt.gasUsed.toString())
      }

      console.log('totalDeposits == ')
      console.log(totalDeposits)
      console.log('allOperations == ')
      console.log(allOperations)
    }

    beforeEach(async () => {
        TOTAL = 20000000 // 全部奖励
        CNY_PRICE = 5000;
        tokenContract = await CacToken.new();
        //cacusdtPriceOracleTokenContract = await CacusdtPriceOracle.new();
        burning_address = "0x0da5e8c87e1c6028fCdDF844B2D9B70E096550C0";
        contractInstance = await Fortunebao.new(tokenContract.address, burning_address);
        bonusToken = new web3.eth.Contract(cactoken['abi'], await contractInstance.getBonusToken())
        purchaseAToken = new web3.eth.Contract(cacpatoken['abi'], await contractInstance.getPurchaseToken(0))
        purchaseBToken = new web3.eth.Contract(cacpbtoken['abi'], await contractInstance.getPurchaseToken(1))
        purchaseCToken = new web3.eth.Contract(cacpctoken['abi'], await contractInstance.getPurchaseToken(2))
        purchaseNormalToken = new web3.eth.Contract(cacptoken['abi'], await contractInstance.getPurchaseToken(3))
        await purchaseAToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseBToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseCToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseNormalToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
    });

    it("初始余额确认: ", async () => {
      // 发行人CAC余额2000万
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), TOTAL)

      // 发行人CACPA余额2000万
      let alice_cacpa_balance = await purchaseAToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacpa_balance), TOTAL)

      // 发行人CACPB余额2000万
      let alice_cacpb_balance = await purchaseBToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacpb_balance), TOTAL)

      // 发行人CACPC余额2000万
      let alice_cacpc_balance = await purchaseCToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacpc_balance), TOTAL)

      // 发行人CACP余额1000万
      // 合约CACP余额1000万
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), TOTAL/2)
      let contract_cacp_balance = await purchaseNormalToken.methods.balanceOf(contractInstance.address).call()
      assert.equal(web3.utils.fromWei(contract_cacp_balance), TOTAL/2)
    })

    it(`
      进行1次白名单质押:
      没有在白名单里面,质押失败
    `, async () => {
      try {
        await purchase_in_white_list(0, 0) // 购买一次
        assert.fail('Expected throw not received');
      } catch (error) {
        assert(error)
      }
    })

    it(`
      进行1次白名单质押:
      管理员进行了添加白名单操作
      在白名单里面,质押成功,
      校验Deposit
        类型,
        质押数量,
        创建时间,
        计息时间,
        活动类型,
        套餐类型,
        参与活动人,
        质押数量
      校验Operation
        操作人,
        操作数量,
        操作时间,
        备注,
        操作类型
    `, async () => {
       await contractInstance.addWhiteList(1,toWei(100), alice)
       let whiteList = await contractInstance.getWhiteList(1)
       assert.equal(whiteList.length, 1)  // 校验白名单数量
       let before_amount = await contractInstance.getWhiteAddressAmount(1)
       console.log('before_amount = ', before_amount)
       assert.equal(before_amount, toWei(100))  // 校验白名单购买数量
       await purchase_in_white_list(1, 0) // 购买一次
       let after_amount = await contractInstance.getWhiteAddressAmount(1)
       console.log('after_amount = ', after_amount)
       assert.equal(after_amount, 0)  // 校验白名单购买数量是否变为0

       // 基本信息校验
       totalDeposits = await contractInstance.getTotalDeposits()
       lastDeposit = totalDeposits[totalDeposits.length - 1]
       console.info('lastDeposit = ', lastDeposit)
       assert.equal(lastDeposit.isWithdrawed, false)
       assert.equal(lastDeposit.withdrawedInterest, 0)
       assert.equal(lastDeposit.calcInterestDate, currentTime() - ((currentTime() + 8 * 3600) % 86400) + 86400) // 时间戳对比
       assert.equal(lastDeposit.activityType, 1) // 活动类型,指定类型1
       assert.equal(lastDeposit.mealType, 0) // 套餐类型,选定套餐类型0
       assert.equal(lastDeposit.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastDeposit.depositAmount), 100) // 质押金额固定100

       allOperations = await contractInstance.getAllOperations()
       lastOperation = allOperations[allOperations.length - 1]
       console.info('lastOperation = ', lastOperation)
       assert.equal(lastOperation.operationType, 0) // 操作类型,选定充值0
       assert.equal(lastOperation.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastOperation.amount), 100) // 质押金额白名单固定100
       assert.equal(lastOperation.deposit.id, lastDeposit.id) // 指向deposit正确

       // cacpb减少100
       let alice_cacpb_balance = await purchaseBToken.methods.balanceOf(alice).call()
       assert.equal(web3.utils.fromWei(alice_cacpb_balance), TOTAL - 100)
    })

    //
    // 需要追加一个合约capc的提取以及充值 isOwner

    it(`进行普通质押:
        校验Deposit
          类型,
          质押数量,
          创建时间,
          计息时间,
          活动类型,
          套餐类型,
          参与活动人,
          质押数量
        是否正确
    `, async () => {
       cny_amount = 1000
       purchase_amount = toWei(cny_amount)
       await purchase(purchase_amount, 1, 1) // 购买一次
       totalDeposits = await contractInstance.getTotalDeposits()
       lastDeposit = totalDeposits[totalDeposits.length - 1]
       console.info('normal lastDeposit = ', lastDeposit)
       assert.equal(lastDeposit.isWithdrawed, false)
       assert.equal(lastDeposit.withdrawedInterest, 0)
       assert.equal(lastDeposit.calcInterestDate, currentTime() - ((currentTime() + 8 * 3600) % 86400) + 86400) // 时间戳对比
       assert.equal(lastDeposit.activityType, 3) // 活动类型,固定应该是常态轮
       assert.equal(lastDeposit.mealType, 1) // 套餐类型,跟选定套餐类型一致
       assert.equal(lastDeposit.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastDeposit.depositAmount), cny_amount) // 质押金额

       allOperations = await contractInstance.getAllOperations()
       lastOperation = allOperations[allOperations.length - 1]
       console.info('normal lastOperation = ', lastOperation)
       assert.equal(lastOperation.operationType, 0) // 操作类型,选定充值0
       assert.equal(lastOperation.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastOperation.amount), cny_amount) // 质押金额1000
       assert.equal(lastOperation.deposit.id, lastDeposit.id) // 指向deposit正确

       // cacp减少100
       let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
       assert.equal(web3.utils.fromWei(alice_cacp_balance), TOTAL/2 - cny_amount)
    })

    it(`普通质押余额不足质押判断 Balance not enough`, async () => {
      // 购买时余额不足
      try {
        await contractInstance.depositNormally(toWei(1000), 1, {from: bob})
        assert.fail('Expected throw not received');
      } catch (error) {
        assert(error)
      }
    })

    it(`1. 白名单余额不足质押判断 Balance not enough
        2. 抛出异常白名单数量不变`, async () => {
      // 添加白名单
      try {
        await contractInstance.addWhiteList(1, toWei(100), bob)
        // 购买时余额不足
        await contractInstance.depositInWhiteList(1, 0, {from: bob})
        assert.fail('Expected throw not received');
      } catch (error) {
        assert(error)
        let valid_amount = await contractInstance.getWhiteAddressAmount(1, {from: bob})
        console.info('valid_amount = ', valid_amount)
        assert.equal(valid_amount, toWei(100))
      }
    })


    it("判断不同时间的利息: 当天存入, 没有利息 ", async () => {
      await purchase(toWei(1000), 0, 1) // 普通质押
      my_deposits = await contractInstance.myDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('1 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, 0)
      console.log('1 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, 0)
    })

    it("判断不同时间的利息: 次日利息 常态轮-第三个套餐20%月化 ", async () => {
      // (20 / 3000) 每日利息
      await purchase(toWei(1000), 2, 1) // 普通质押 常态轮-第三个套餐
      my_deposits = await contractInstance.myDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('2 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 2)
      console.log('2 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '6666700000000000000') // 6.6667
    })

    it("判断不同时间的利息: 次日利息 常态轮-第三个套餐20%月化 100天以后看有多少利息, 应该还有90天", async () => {
      // (20 / 3000) 每日利息
      await purchase(toWei(1000), 2, 1) // 普通质押 常态轮-第三个套餐 第三个套餐最多能拿90天
      my_deposits = await contractInstance.myDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('2 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 101)
      console.log('2 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, toWei(600)) // 1000 * 20 / 300 * 90 = 600
    })

    xit("判断提前提币是否销毁,", async () => {
       await purchase(1000, 1, 1) // 购买一次
      my_deposits = await contractInstance.myDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime + 86500)
      console.log('interestInfo = ', interestInfo)
    })

    xit("正常提现 CACP提取余额查看, CAC利息提取余额查看", async () => {
       await purchase(1000, 1, 1) // 购买一次
    })

    xit("正常只提取利息 CAC利息提取余额查看", async () => {
       await purchase(1000, 1, 1) // 购买一次
    })


    xit("四舍五入看看有没有问题", async () => {

      await contractInstance.contract.events.TestEvent({}, function(error, event){
         console.log('event =======');
         console.log(event.returnValues);
      })
      .on('data', function(event){
          console.log('data == '); // same results as the optional callback above
          console.log(event.returnValues); // same results as the optional callback above
      })
      .on('changed', function(event){
          // remove event from local database
          console.log('changed == '); // same results as the optional callback above
          console.log(event.returnValues); // same results as the optional callback above
      })
      .on('error', console.error);

      await purchase(400)


      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      console.info('alice_gb_balance == ')
      console.info(alice_gb_balance)
      //assert.equal(web3.utils.fromWei(alice_gb_balance), 380 + PRE_MINING)
    })

    xit("获取价格", async () => {
      await contractInstance.updateCacusdtPrice({from: alice})
      console.log(555)
    })



})
