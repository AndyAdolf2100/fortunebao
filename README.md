# 理财宝合约
### 开发环境
```
Truffle v5.4.27 (core: 5.4.27)
Node v14.16.0
```
### 启动模拟本地节点
```
$ ganache-cli -l 0x10378ea0
```

### 测量合约大小
```
$ truffle run contract-size
```

### 执行除了最后一条单元测试其余的单元测试时，需要将reductionBasicNumber设置为正常的1000
### 运行最后一条单元测试的时候需要将reductionBasicNumber设置为1
```
_recordReduction()
```
### 运行测试最后一条出这样的异常这样是正常的
```
  1) Contract: FortunebaoTest
       质押减产 basicAmount = 1:

      AssertionError: expected 1 to equal 2
      + expected - actual

      -1
      +2

```

### 部署到bsc网络
测试网
```
$ truffle migrate --network testnet
```
主网
```
$ truffle migrate --network bsc
```
### 注意事项
```
版本:
@truffle/hdwallet-provider@2.0.0
```
