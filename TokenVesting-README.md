# TokenVesting 合约

## 概述

TokenVesting 是一个基于 OpenZeppelin 的代币归属（Vesting）合约，实现了12个月的 Cliff 期和24个月的线性释放机制。该合约允许项目方为受益人创建代币归属计划，确保代币按照预定的时间表逐步释放。

## 功能特性

### 归属机制
- **Cliff 期**: 12个月（365天）- 在此期间内，受益人无法释放任何代币
- **线性释放期**: 24个月（730天）- 从第13个月开始，每月释放总量的 1/24
- **总归属期**: 36个月（1095天）

### 主要功能
1. **创建归属计划**: 所有者可以为受益人创建代币归属计划
2. **代币释放**: 受益人可以释放已归属的代币
3. **查询功能**: 查询归属状态、可释放金额等信息
4. **撤销功能**: 所有者可以撤销归属计划
5. **紧急提取**: 所有者可以紧急提取意外转入的代币

## 合约架构

### 主要合约
- `TokenVesting.sol`: 主要的归属合约
- `MockToken.sol`: 用于测试的 ERC20 代币合约

### 依赖
- OpenZeppelin Contracts (ERC20, SafeERC20, Ownable, ReentrancyGuard)

## 使用方法

### 1. 部署合约

```bash
# 编译合约
forge build

# 部署合约
forge script script/DeployTokenVesting.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### 2. 创建归属计划

```solidity
// 1. 批准代币使用
token.approve(vestingContract, amount);

// 2. 创建归属计划
vesting.createVestingSchedule(beneficiary, tokenAddress, amount);
```

### 3. 释放代币

受益人可以调用 `release()` 方法释放已归属的代币：

```solidity
// 受益人调用释放方法
vesting.release();
```

### 4. 查询信息

```solidity
// 查询可释放金额
uint256 releasable = vesting.getReleasableAmount(beneficiary);

// 查询已归属金额
uint256 vested = vesting.getVestedAmount(beneficiary);

// 查询剩余金额
uint256 remaining = vesting.getRemainingAmount(beneficiary);

// 查询归属计划详情
(address beneficiary, address token, uint256 total, uint256 released, uint256 start, bool revoked) 
    = vesting.getVestingSchedule(beneficiary);
```

## 合约接口

### 主要方法

#### 所有者方法
- `createVestingSchedule(address _beneficiary, address _token, uint256 _amount)`: 创建归属计划
- `revokeVesting(address _beneficiary)`: 撤销归属计划
- `emergencyWithdraw(address _token, uint256 _amount)`: 紧急提取代币

#### 受益人方法
- `release()`: 释放当前可用的代币

#### 查询方法
- `getReleasableAmount(address _beneficiary)`: 获取可释放金额
- `getVestedAmount(address _beneficiary)`: 获取已归属金额
- `getRemainingAmount(address _beneficiary)`: 获取剩余金额
- `getVestingSchedule(address _beneficiary)`: 获取归属计划详情
- `getTimeToNextRelease(address _beneficiary)`: 获取距离下次释放的时间
- `getBeneficiaries()`: 获取所有受益人列表

### 事件
- `VestingCreated(address indexed beneficiary, address indexed token, uint256 amount, uint256 startTime)`
- `TokensReleased(address indexed beneficiary, uint256 amount)`

## 时间线示例

假设在 2024年1月1日 部署合约并创建100万代币的归属计划：

| 时间点 | 描述 | 可释放金额 |
|--------|------|------------|
| 2024年1月1日 | 合约部署，归属开始 | 0 MTK |
| 2024年12月31日 | Cliff期结束 | 0 MTK |
| 2025年1月31日 | 第13个月 | ~41,667 MTK (1/24) |
| 2025年12月31日 | 第24个月 | ~500,000 MTK (12/24) |
| 2026年12月31日 | 第36个月，归属完成 | 1,000,000 MTK (全部) |

## 测试

运行测试套件：

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract TokenVestingTest

# 运行测试并显示详细输出
forge test -vvv
```

### 测试覆盖
- ✅ 创建归属计划
- ✅ Cliff期限制
- ✅ 线性释放机制
- ✅ 多次释放
- ✅ 撤销归属计划
- ✅ 权限控制
- ✅ 边界条件测试

## 安全考虑

1. **重入攻击防护**: 使用 OpenZeppelin 的 ReentrancyGuard
2. **权限控制**: 只有所有者可以创建和撤销归属计划
3. **安全转账**: 使用 SafeERC20 进行代币转账
4. **输入验证**: 对所有输入参数进行验证
5. **溢出保护**: Solidity 0.8+ 内置溢出保护

## 部署示例

### 本地测试网部署

```bash
# 启动本地测试网
anvil

# 部署到本地测试网
forge script script/DeployTokenVesting.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### 主网部署

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url

# 部署到主网
forge script script/DeployTokenVesting.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

## 使用示例

查看 `script/VestingExample.s.sol` 文件获取完整的使用示例。

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个合约。

## 免责声明

此合约仅供学习和参考使用。在生产环境中使用前，请进行充分的安全审计。 