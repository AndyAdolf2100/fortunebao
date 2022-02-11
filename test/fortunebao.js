const CacToken = artifacts.require("CacToken"); // Cac合约
const FortunebaoV3 = artifacts.require("FortunebaoV3");
const FortunebaoData = artifacts.require("FortunebaoData");
const cactoken = require('../build/contracts/CacToken.json')
const cacpatoken = require('../build/contracts/CACPAToken.json')
const cacpbtoken = require('../build/contracts/CACPBToken.json')
const cacpctoken = require('../build/contracts/CACPCToken.json')
const cacptoken = require('../build/contracts/CACPToken.json')


/*
需补全测试：
退出质押的时候，已经提取的也要放在双倍销毁里面
*/
contract("FortunebaoTest", (accounts) => {
    const gasLimit = '0x1adb0'
    let catchRevert = require("./utils/exceptions.js").catchRevert;

    let [alice, bob, burning] = accounts; // 获取两个地址 + 销毁地址

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

      totalDeposits = await dataContractInstance.getTotalDeposits()
      allOperations = await dataContractInstance.getAllOperations()

      console.log('totalDeposits == ')
      //console.log(totalDeposits)
      console.log('allOperations == ')
      //console.log(allOperations)
    }

    // 购买数量,套餐类型,循环次数
    async function purchase(amount, meal_type, number) {
      for(let i = 0; i < number; i++ ) {
        // 调用购买矿机的方法
        let purchaseRequest = await contractInstance.depositNormally(amount, meal_type, {from: alice})
        console.log('GasUsed: ' + purchaseRequest.receipt.gasUsed.toString())
      }

      totalDeposits = await dataContractInstance.getTotalDeposits()
      allOperations = await dataContractInstance.getAllOperations()

      console.log('totalDeposits == ')
      // console.log(totalDeposits)
      console.log('allOperations == ')
      // console.log(allOperations)
    }

    beforeEach(async () => {
        TOTAL = 20000000 // 全部奖励
        CNY_PRICE = 5000;
        tokenContract = await CacToken.new();
        dataContractInstance = await FortunebaoData.new(tokenContract.address, burning);
        contractInstance = await FortunebaoV3.new(dataContractInstance.address);
        console.info('tokenContract = ', tokenContract.address)
        console.info('dataContractInstance = ', dataContractInstance.address)
        console.info('contractInstance = ', contractInstance.address)
        bonusToken = new web3.eth.Contract(cactoken['abi'], await dataContractInstance.getBonusToken())
        purchaseAToken = new web3.eth.Contract(cacpatoken['abi'], await dataContractInstance.getPurchaseToken(0))
        purchaseBToken = new web3.eth.Contract(cacpbtoken['abi'], await dataContractInstance.getPurchaseToken(1))
        purchaseCToken = new web3.eth.Contract(cacpctoken['abi'], await dataContractInstance.getPurchaseToken(2))
        purchaseNormalToken = new web3.eth.Contract(cacptoken['abi'], await dataContractInstance.getPurchaseToken(3))
        await bonusToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseAToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseBToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseCToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})
        await purchaseNormalToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: alice})

        // 允许操作合约
        await dataContractInstance.allowAccess(contractInstance.address, {from: alice});
        // 向Fortunebao合约中转账cac
        await bonusToken.methods.transfer(contractInstance.address, toWei('10000000')).send({ from: alice, gas: gasLimit });
        // 向Fortunebao合约中转账cacp
        await purchaseNormalToken.methods.transfer(contractInstance.address, toWei('10000000')).send({ from: alice, gas: gasLimit });
    });

    it("测试多笔手续费....", async () => {
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
    })

    it("提取操作检验: ", async () => {
      await contractInstance.depositAllBonus({from : alice})
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      console.log('alice_cac_balance', alice_cac_balance)
      assert.equal(web3.utils.fromWei(alice_cac_balance), TOTAL)
      await contractInstance.depositAllNormalPurchase({from : alice})
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      console.log('alice_cacp_balance', alice_cacp_balance)
      assert.equal(web3.utils.fromWei(alice_cacp_balance), TOTAL)
    });

    it("持仓地址信息: ", async () => {
      // 发行人CAC余额2000万 转进合约2000
      let addresses = await purchaseNormalToken.methods.getUserAddresses().call()
      console.info(addresses)
      assert.equal(addresses.length, 2)
      let addresses2 = await purchaseNormalToken.methods.getHolderAddresses().call()
      console.info(addresses2)
      assert.equal(addresses2.length, 2)
      let is_holder = await purchaseNormalToken.methods.isUserJoined(alice).call()
      console.info(is_holder)
      assert.equal(is_holder, true)
    });

    it("初始余额确认: ", async () => {
      // 发行人CAC余额2000万 转进合约2000
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      console.log('alice_cac_balance', alice_cac_balance)
      assert.equal(web3.utils.fromWei(alice_cac_balance), TOTAL / 2)

      let contract_cac_balance = await bonusToken.methods.balanceOf(contractInstance.address).call()
      console.log('contract_cac_balance = ', contract_cac_balance)
      assert.equal(web3.utils.fromWei(contract_cac_balance), TOTAL / 2)

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
      没有在白名单里面,质押失败: You are not in whiteList
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
       let before_amount = await dataContractInstance.getWhiteAddressAmount(alice, 1)
       console.log('before_amount = ', before_amount)
       assert.equal(before_amount, toWei(100))  // 校验白名单购买数量
       await purchase_in_white_list(1, 0) // 购买一次
       let after_amount = await dataContractInstance.getWhiteAddressAmount(alice, 1)
       console.log('after_amount = ', after_amount)
       assert.equal(after_amount, 0)  // 校验白名单购买数量是否变为0
       total_addresses = await dataContractInstance.getUserAddresses()
       assert.equal(total_addresses.length, 1)  // 全部参与活动地址数量 1

       // 基本信息校验
       totalDeposits = await dataContractInstance.getTotalDeposits()
       lastDeposit = totalDeposits[totalDeposits.length - 1]
       console.info('lastDeposit = ', lastDeposit)
       assert.equal(lastDeposit.isWithdrawed, false)
       assert.equal(lastDeposit.withdrawedInterest, 0)
       assert.equal(lastDeposit.calcInterestDate, currentTime() - ((currentTime() + 8 * 3600) % 86400) + 86400) // 时间戳对比
       assert.equal(lastDeposit.activityType, 1) // 活动类型,指定类型1
       assert.equal(lastDeposit.mealType, 0) // 套餐类型,选定套餐类型0
       assert.equal(lastDeposit.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastDeposit.depositAmount), 100) // 质押金额固定100

       allOperations = await dataContractInstance.getAllOperations()
       lastOperation = allOperations[allOperations.length - 1]
       console.info('lastOperation = ', lastOperation)
       assert.equal(lastOperation.operationType, 0) // 操作类型,选定充值0
       assert.equal(lastOperation.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastOperation.amount), 100) // 质押金额白名单固定100

       userLastDeposits = await dataContractInstance.getUserDeposits(alice)
       console.info('userLastDeposits = ', userLastDeposits)
       lastUserDeposit = userLastDeposits[userLastDeposits.length - 1]
       assert.equal(lastUserDeposit.id, lastDeposit.id) // 指向deposit正确

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
       totalDeposits = await dataContractInstance.getTotalDeposits()
       lastDeposit = totalDeposits[totalDeposits.length - 1]
       console.info('normal lastDeposit = ', lastDeposit)
       assert.equal(lastDeposit.isWithdrawed, false)
       assert.equal(lastDeposit.withdrawedInterest, 0)
       assert.equal(lastDeposit.calcInterestDate, currentTime() - ((currentTime() + 8 * 3600) % 86400) + 86400) // 时间戳对比
       assert.equal(lastDeposit.activityType, 3) // 活动类型,固定应该是常态轮
       assert.equal(lastDeposit.mealType, 1) // 套餐类型,跟选定套餐类型一致
       assert.equal(lastDeposit.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastDeposit.depositAmount), cny_amount) // 质押金额

       allOperations = await dataContractInstance.getAllOperations()
       lastOperation = allOperations[allOperations.length - 1]
       console.info('normal lastOperation = ', lastOperation)
       assert.equal(lastOperation.operationType, 0) // 操作类型,选定充值0
       assert.equal(lastOperation.user, alice) // 记录参与活动地址
       assert.equal(web3.utils.fromWei(lastOperation.amount), cny_amount) // 质押金额1000

       userLastDeposits = await dataContractInstance.getUserDeposits(alice)
       console.info('userLastDeposits = ', userLastDeposits)
       lastUserDeposit = userLastDeposits[userLastDeposits.length - 1]
       assert.equal(lastUserDeposit.id, lastDeposit.id) // 指向deposit正确

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
        let valid_amount = await dataContractInstance.getWhiteAddressAmount(bob, 1)
        console.info('valid_amount = ', valid_amount)
        assert.equal(valid_amount, toWei(100))
      }
    })


    it("判断不同时间的利息: 当天存入, 没有利息 ", async () => {
      await purchase(toWei(1000), 0, 1) // 普通质押
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('1 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, 0)
      console.log('1 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, 0)
    })

    it("判断不同时间的利息: 次日利息 常态轮-第三个套餐20%月化 ", async () => {
      // (20 / 3000) 每日利息
      await purchase(toWei(1000), 2, 1) // 普通质押 常态轮-第三个套餐
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('2 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 2)
      console.log('2 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '6666700000000000000') // 6.6667
    })

    it("判断不同时间的利息: 次日利息 常态轮-第三个套餐20%月化 100天以后看有多少利息, 应该还有90天", async () => {
      // (20 / 3000) 每日利息
      await purchase(toWei(1000), 2, 1) // 普通质押 常态轮-第三个套餐 第三个套餐最多能拿90天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('2 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 101)
      console.log('2 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, toWei(600)) // 1000 * 20 / 3000 * 90 = 600
    })

    it("判断不同时间的利息: 次日利息 第三轮-第二个套餐17%月化 100天以后看有多少利息, 应该还有60天", async () => {
      // (17 / 3000) 每日利息
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 1) // 白名单质押 第三轮-第二个套餐 第二个套餐最多能拿60天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('3 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 101)
      console.log('3 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, toWei(442)) // 1000 * 17 / 3000 * 60 * 1.3 = 442
    })

    it("在第三轮-第二个套餐17%月化上，25天后仅提取利息, (当前时间 + 25 days)，能得到24天的利息 | 再过24天，再提取24天的利息 测试提取第二次", async () => {
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 1) // 白名单质押 第三轮-第二个套餐 第二个套餐最多能拿60天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('4 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 25)
      console.log('4 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '176800000000000000000') // 1000 * 17 / 3000 * 24 * 1.3 = 176.8
      await contractInstance.withdrawOnlyInterest(last_deposit.id, currentTime() + 86400 * 25)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('4 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 2) // 操作类型,选定提取利息2
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 176.8) // 利息数量  1000.0 * 17 / 3000 * 24 * 1.3 = 176.8

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      console.info('userLastDeposits = ', userLastDeposits)
      lastUserDeposit = userLastDeposits[userLastDeposits.length - 1]
      assert.equal(lastUserDeposit.id, last_deposit.id) // 指向deposit正确

      // alice的cac余额
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10000176.8')

      latest_deposit = await dataContractInstance.getTotalDepositMapping(last_deposit.id);
      assert.equal(latest_deposit.withdrawedInterest, '176800000000000000000') // 已经提取的看看是否记录上

      interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * (25 + 24) )
      console.log('4-2 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '176800000000000000000') // 1000 * 17 / 3000 * 24 * 1.3 = 176.8
      await contractInstance.withdrawOnlyInterest(last_deposit.id, currentTime() + 86400 * (25 + 24))
      allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('4-2 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 2) // 操作类型,选定提取利息2
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 176.8) // 利息数量  1000.0 * 17 / 3000 * 24 * 1.3 = 176.8

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      console.info('4-2 userLastDeposits = ', userLastDeposits)
      lastUserDeposit = userLastDeposits[userLastDeposits.length - 1]
      assert.equal(lastUserDeposit.id, last_deposit.id) // 指向deposit正确

      // alice的cac余额
      alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10000353.6')

    })

    it("在第三轮-第二个套餐17%月化上，25天后仅提取本金，接收惩罚, (当前时间 + 25 days)，本金惩罚 24 * 2 = 48天的利息", async () => {
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 1) // 白名单质押 第三轮-第二个套餐 第二个套餐最多能拿60天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('4 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 25)
      console.log('4 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '176800000000000000000') // 1000 * 17 / 3000 * 24 * 1.3 = 176.8
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 25)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('4 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 3) // 操作类型,选定提取惩罚3
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 176.8 * 2) // 利息数量  1000 * 17 / 3000 * 25 * 1.3 = 442

      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.info('new last_deposit == ', last_deposit)
      let user_total_deposit = await dataContractInstance.getTotalDepositMapping(last_deposit.id)
      console.info('new user_total_deposit == ', user_total_deposit)
      console.info('new user_total_deposit isWithdrawed == ', user_total_deposit.isWithdrawed)
      assert.equal(user_total_deposit.isWithdrawed, true) // 全部Deposit Mapping
      let user_deposits = await dataContractInstance.getUserDeposits(alice)
      let user_deposit  = user_deposits[user_deposits.length - 1]
      assert.equal(user_deposit.isWithdrawed, true) // 用户Deposit
      console.info('new user_deposit == ', user_deposit)
      console.info('new user_deposit isWithdrawed == ', user_deposit.isWithdrawed)

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10000000')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 176.8 * 2)

      // 本金损毁
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10000646.4) // 10000000 + 1000 - 176.8 * 2 = 10000646.4
    })

    it("在第三轮-第五个套餐30%月化上，360天后仅提取本金，接收惩罚, (当前时间 + 360 days)，惩罚掉全部本金", async () => {
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('5 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 360)
      console.log('5 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3821000000000000000000') // 原1000 * 30 / 3000 * 359 * 1.3 = 4667.0 | now: 3821000000000000000000, 77天收益: 77 * 13 还有 359 - 77 = 282天 总收益: 2820 + 1001
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 360)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('5 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 3) // 操作类型,选定提取惩罚3
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 1000) // 利息数量  1000 * 17 / 3000 * 359 * 1.3 = 4667 > 1000 = 1000

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10000000')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 1000)

      // 本金全部损毁
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10000000 ) // 10000000 + 1000 - 176.8 * 2 = 10000646.4
    })

    it("在第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 360 days)，拿回所有本金和利息", async () => {
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 361)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3831000000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 361)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3831) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003831')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 361 days)，拿回所有本金和利息，从第340天开始减产，减产1次，后面20天拿减产之后的数量,总量比之前少（2 * 20 = 40）", async () => {
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 361)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3789000000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 361)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3789) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003789')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 361 days)，拿回所有本金和利息，从第340天开始减产，连续减产2次，后面20天拿减产之后的数量,总量比之前少（2 * 20 = 40）", async () => {
      // 连续两次减产
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340 + 1)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 361)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3755400000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001 | 最后结果：2830 + 1001 - 210 + (21 * 6.4)
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 361)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3755.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003755.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 361 days)，拿回所有本金和利息，从第340天开始减产，连续减产2次，后面20天拿减产之后的数量,总量比之前少（2 * 20 = 40）", async () => {
      // 连续两次减产
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340 + 1)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 361)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3755400000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001 | 最后结果：2830 + 1001 - 210 + (21 * 6.4)
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 361)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3755.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003755.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })


    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 500 days)，拿回所有本金和利息，从第340天开始减产，连续减产2次，后面20天拿减产之后的数量,总量比之前少（2 * 20 = 40）", async () => {
      // 连续两次减产
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340 + 1)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 500)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3755400000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001 | 最后结果：2830 + 1001 - 210 + (21 * 6.4)
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 500)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3755.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003755.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 500 days)，拿回所有本金和利息，从第340天开始减产，连续减产2次，后面20天拿减产之后的数量,总量比之前少（2 * 20 = 40）", async () => {
      // 连续两次减产
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340 + 1)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 500)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3755400000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001 | 最后结果：2830 + 1001 - 210 + (21 * 6.4)
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 500)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3755.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003755.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 500 days)，拿回所有本金和利息，从第340天开始减产，连续减产1次，从350天开始减产第二次, 后面20天拿减产之后的数量,总量比之前少", async () => {
      // 连续两次减产
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 340)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 350)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 500)
      console.log('6 interestInfo = ', interestInfo)
      assert.equal(interestInfo.interest, '3771400000000000000000') // 1000 * 30 / 3000 * 360 * 1.3 = 4680.0 | now: 3831000000000000000000, 77天收益: 77 * 13 还有 360 - 77 = 283天 总收益: 2830 + 1001 | 最后结果：2830 + 1001 -210 + 80 + 70.4
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 500)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3771.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003771.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：第三轮-第五个套餐30%月化上，361天后仅提取本金，套餐时间达成, (当前时间 + 500 days)，拿回所有本金和利息，从第1开始减产，100天后回本利率降低，从350天开始减产第二次, 后面20天拿减产之后的数量,总量比之前少", async () => {
      // 第一天虽然减产但是获得的收益不减产，直到获取的收益达到100%
      await contractInstance.mockReductionInfo(currentTime() + 86400)
      await contractInstance.mockReductionInfo(currentTime() + 86400 * 350)

      let array = await contractInstance.getRedutionDateTime()
      console.info('reductionDateTimeArray = ', array);
      for(let i = 0;i < array.length; i ++) {
        console.info('item = ', array[i].toNumber().toString());
      }
      let reductionCount = await contractInstance.reductionCount()
      console.info('reductionCount = ', reductionCount.toNumber().toString());
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 白名单质押 第三轮-第五个套餐 第五个套餐最多能拿360天
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('6 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 500)
      console.log('6 interestInfo = ', interestInfo)
      // 每天利息13，77天回本 13 * 77 = 1001, 从第78天开始，每天利息变成8，78 * 272 = 2176, 第350天后，利息还有11天没拿，进行第二次减产 6.4 * 11 = 70.4
      // 1001 + 2176 + 70.4 = 3247.4
      assert.equal(interestInfo.interest, '3247400000000000000000')
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 500)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('6 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 3247.4) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10003247.4')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10001000 ) // 10000000 + 1000
    })

    it("在上一个测试上：常态轮-第五个套餐30%月化上，申购前已经减产1次，申购后第二天再减产1次，361天后仅提取本金，套餐时间达成, (当前时间 + 500 days)，拿回所有本金和利息", async () => {
      // 第一天虽然减产但是获得的收益不减产，直到获取的收益达到100%
      await contractInstance.mockReductionInfo(currentTime())
      await contractInstance.mockReductionInfo(currentTime() + 2 * 86400)

      await purchase(toWei(1000), 4, 1)
      my_deposits = await dataContractInstance.getTotalDeposits()
      last_deposit = my_deposits[my_deposits.length - 1]
      console.log('7 last_deposit = ', last_deposit)
      let interestInfo = await contractInstance.getInterest(last_deposit.id, currentTime() + 86400 * 500)
      console.log('7 interestInfo = ', interestInfo)
      // 回本前的利息能拿8，之后都拿6.4 (本金百分百才减产100%)
      // 235 * 6.4 + 125 * 8 = 2504
      assert.equal(interestInfo.interest, '2504000000000000000000')
      await contractInstance.withdrawPrincipal(last_deposit.id, currentTime() + 86400 * 500)
      let allOperations = await dataContractInstance.getAllOperations()
      lastOperation = allOperations[allOperations.length - 1]
      console.info('7 lastOperation = ', lastOperation)
      assert.equal(lastOperation.operationType, 1) // 操作类型,选定提取成功1
      assert.equal(lastOperation.user, alice) // 记录参与活动地址
      assert.equal(web3.utils.fromWei(lastOperation.amount), 2305.6) // 利息数量  看上面

      userLastDeposits = await dataContractInstance.getUserDeposits(alice)
      assert.equal(lastOperation.depositId, last_deposit.id) // 指向deposit正确

      // alice的cac余额不变
      let alice_cac_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cac_balance), '10002305.6')

      // 销毁地址放入销毁量 cac
      let burning_cac_balance = await bonusToken.methods.balanceOf(burning).call()
      assert.equal(web3.utils.fromWei(burning_cac_balance), 0)

      // 本金全部提取
      let alice_cacp_balance = await purchaseNormalToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_cacp_balance), 10000000 ) // 10000000 - 1000 + 1000
    })


    xit("质押减产 basicAmount = 1", async () => {

      let array = await contractInstance.getRedutionDateTime()
      let reductionCount = await contractInstance.reductionCount()
      assert.equal(array.length, 1)
      assert.equal(reductionCount, 0)
      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 第一次质押

      array = await contractInstance.getRedutionDateTime()
      reductionCount = await contractInstance.reductionCount()
      assert.equal(array.length, 2)
      assert.equal(reductionCount, 1)

      await contractInstance.addWhiteList(2, toWei(1000), alice)
      await purchase_in_white_list(2, 4) // 第二次质押不变(同样角色)

      array = await contractInstance.getRedutionDateTime()
      reductionCount = await contractInstance.reductionCount()
      assert.equal(array.length, 2)
      assert.equal(reductionCount, 1)
      await purchaseCToken.methods.approve(contractInstance.address, toWei('20000000')).send({from: bob})
      await purchaseCToken.methods.transfer(bob, toWei('1000')).send({ from: alice, gas: gasLimit });
      await contractInstance.addWhiteList(2, toWei(1000), bob)
      await contractInstance.depositInWhiteList(2, 4, {from: bob})

      array = await contractInstance.getRedutionDateTime()
      reductionCount = await contractInstance.reductionCount()
      assert.equal(array.length, 3)
      assert.equal(reductionCount, 2)

    })

    it("设置/获取cac价格", async () => {
      await dataContractInstance.setPriceLooper(bob, {from: alice})
      await dataContractInstance.setCacPrice(toWei(3), {from: bob})
      let cacprice = await dataContractInstance.getCacPrice({from: bob})
      assert.equal(web3.utils.fromWei(cacprice), 3)
    })



})
