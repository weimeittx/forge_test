# 多签钱包 (MultSign) 合约

多签钱包是一种需要多个持有人共同确认后才能执行交易的智能合约钱包，提高资金安全性，防止单点故障风险。

## 功能特点

- 创建多签钱包时设置多签持有人和签名门槛
- 多签持有人可提交交易提案
- 其他多签持有人确认提案
- 达到签名门槛后任何人可执行交易
- 持有人可撤销自己的确认
- 完整的事件记录

## 合约结构

合约主要包含以下组件：

- **状态变量**：记录持有人、确认门槛、交易列表等信息
- **事件**：记录重要操作，如提交、确认、撤销确认和执行交易
- **修饰器**：确保权限和操作条件的验证
- **主要功能**：提交、确认、撤销和执行交易

## 测试合约

已创建完整的测试套件，测试所有关键功能：

```bash
# 运行所有测试
forge test -vv

# 运行特定测试
forge test --match-test test_SubmitTransaction -vv
```

## 部署指南

### 环境变量设置

部署前，需要在 `.env` 文件中设置以下环境变量：

```
# 部署私钥
PRIVATE_KEY=0xYour_private_key

# 持有人地址（逗号分隔）
OWNERS=0xOwner1,0xOwner2,0xOwner3

# 确认门槛（需要多少持有人确认）
REQUIRED_CONFIRMATIONS=2

# 网络配置（选择要部署的网络）
RPC_URL=https://eth-mainnet.alchemyapi.io/v2/your-api-key
ETHERSCAN_API_KEY=your-etherscan-api-key
```

### 部署命令

```bash
# 加载环境变量
source .env

# 部署到测试网络
forge script script/MultSign.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 部署到主网网络（谨慎使用）
forge script script/MultSign.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 合约验证

```bash
forge verify-contract --chain-id 1 --compiler-version v0.8.20 <合约地址> src/MultSign.sol:MultSign --etherscan-api-key $ETHERSCAN_API_KEY
```

## 合约使用示例

### 1. 提交交易（持有人操作）

```solidity
// 转账 1 ETH 到目标地址
uint txIndex = multSign.submitTransaction(
    0x123...789, // 目标地址
    1 ether,     // 金额
    ""           // 无数据（简单转账）
);
```

### 2. 确认交易（持有人操作）

```solidity
// 确认交易 #0
multSign.confirmTransaction(0);
```

### 3. 撤销确认（持有人操作）

```solidity
// 撤销对交易 #0 的确认
multSign.revokeConfirmation(0);
```

### 4. 执行交易（任何人都可以在达到门槛后执行）

```solidity
// 执行交易 #0
multSign.executeTransaction(0);
```

### 5. 向钱包存入资金

```solidity
// 简单转账
(bool success, ) = address(multSign).call{value: 1 ether}("");
```

## 合约安全注意事项

1. **确认门槛设置**：确保门槛值合理，既能提供安全性又不会过于影响使用便利性
2. **私钥安全**：持有人需妥善保管私钥，防止丢失或被盗
3. **交易验证**：确认交易前仔细检查交易详情，包括目标地址、金额和数据
4. **执行外部合约**：谨慎执行调用外部合约的交易，应先彻底审计目标合约代码
5. **持有人地址变更**：当前版本不支持动态更改持有人，如需此功能可进一步扩展

## 获取合约ABI

ABI是与合约交互所必需的接口说明。可通过以下命令获取：

```bash
# 生成ABI
forge inspect src/MultSign.sol:MultSign abi > MultSign_abi.json
```

## 后续优化方向

当前多签钱包已实现基本功能，未来可考虑添加以下扩展：

1. 添加/移除持有人的功能
2. 变更确认门槛的功能
3. 批量执行交易的能力
4. 时间锁功能
5. 紧急暂停功能

## 许可证

SPDX-License-Identifier: MIT 