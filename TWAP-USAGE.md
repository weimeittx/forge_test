# MemeToken TWAP 功能使用指南

## 概述

MemeToken 现在集成了 TWAP（时间加权平均价格）功能，可以跟踪和计算代币的历史价格数据。

## 主要功能

### 1. 自动价格跟踪
- 每次 mint 或购买代币时，系统会自动更新 TWAP 价格数据
- 价格基于 Uniswap 交易对的储备量计算

### 2. 手动价格更新
```solidity
// 任何人都可以调用此函数更新价格
memeToken.updateTWAP();
```

### 3. 获取 TWAP 价格

#### 获取指定时间段的 TWAP
```solidity
// 获取过去 10 分钟的 TWAP（最小 5 分钟）
uint256 twap = memeToken.getTWAP(600); // 600 秒 = 10 分钟
```

#### 获取预设时间段的 TWAP
```solidity
// 5 分钟 TWAP
uint256 twap5min = memeToken.getTWAP5min();

// 15 分钟 TWAP
uint256 twap15min = memeToken.getTWAP15min();

// 1 小时 TWAP
uint256 twap1hour = memeToken.getTWAP1hour();
```

### 4. 获取当前价格信息
```solidity
// 获取最新的 TWAP 价格观察
uint256 latestPrice = memeToken.getLatestTWAPPrice();

// 获取当前 Uniswap 价格
uint256 currentPrice = memeToken.getCurrentPrice();

// 获取观察数量
uint256 count = memeToken.getTWAPObservationCount();
```

### 5. 管理 TWAP 功能（仅代币所有者）
```solidity
// 启用 TWAP
memeToken.setTWAPEnabled(true);

// 禁用 TWAP
memeToken.setTWAPEnabled(false);

// 检查 TWAP 状态
bool enabled = memeToken.twapEnabled();
```

## 技术参数

- **最小 TWAP 周期**: 300 秒（5 分钟）
- **最大观察数量**: 100 个
- **价格精度**: 18 位小数（wei）
- **存储方式**: 环形缓冲区，自动覆盖最旧数据

## 价格计算方法

TWAP 使用累积价格方法计算：
1. 每次价格更新时，计算累积价格 = 上次累积价格 + (上次价格 × 时间间隔)
2. TWAP = (结束累积价格 - 开始累积价格) / 时间间隔

## 使用示例

### 基本使用
```solidity
// 部署代币后，TWAP 自动启用
address tokenAddr = memeLaunch.deployInscription("MEME", 1000000e18, 1000e18, 0.001 ether);
MemeToken token = MemeToken(tokenAddr);

// 进行一些交易以生成价格数据
memeLaunch.mintInscription{value: 0.001 ether}(tokenAddr);

// 等待一段时间后获取 TWAP
vm.warp(block.timestamp + 600); // 10 分钟后
token.updateTWAP(); // 手动更新

// 获取 5 分钟 TWAP
uint256 twap = token.getTWAP5min();
```

### 监控价格变化
```solidity
// 监听 TWAP 更新事件
event TWAPUpdated(uint256 price, uint256 timestamp);

// 在合约中处理价格更新
function onTWAPUpdate(uint256 newPrice) external {
    // 处理价格变化逻辑
}
```

## 注意事项

1. **数据要求**: 计算 TWAP 需要至少 2 个价格观察点
2. **时间限制**: 最小 TWAP 周期为 5 分钟
3. **价格来源**: 价格基于 Uniswap V2 交易对储备量
4. **Gas 消耗**: 每次价格更新会消耗额外的 gas
5. **存储限制**: 最多存储 100 个价格观察点

## 错误处理

常见错误及解决方法：

- `"TWAP not enabled"`: TWAP 功能被禁用，需要启用
- `"Insufficient price data"`: 价格数据不足，需要更多观察点
- `"Period too short"`: 时间周期小于 5 分钟
- `"TWAP not initialized"`: TWAP 未初始化，通常在合约部署时自动初始化

## 最佳实践

1. **定期更新**: 在重要交易后手动调用 `updateTWAP()` 确保数据及时性
2. **合理周期**: 选择合适的 TWAP 周期，避免过短导致数据不足
3. **监控事件**: 监听 `TWAPUpdated` 事件跟踪价格变化
4. **错误处理**: 在调用 TWAP 函数时添加适当的错误处理
5. **Gas 优化**: 批量操作时考虑 gas 消耗

## 集成示例

```solidity
contract TWAPMonitor {
    MemeToken public token;
    uint256 public lastTWAP;
    
    constructor(address _token) {
        token = MemeToken(_token);
    }
    
    function checkPriceChange() external returns (bool significant) {
        if (token.getTWAPObservationCount() >= 2) {
            uint256 currentTWAP = token.getTWAP5min();
            
            if (lastTWAP > 0) {
                uint256 change = currentTWAP > lastTWAP ? 
                    currentTWAP - lastTWAP : lastTWAP - currentTWAP;
                significant = (change * 100 / lastTWAP) > 5; // 5% 变化
            }
            
            lastTWAP = currentTWAP;
        }
        
        return significant;
    }
}
```

这个 TWAP 功能为 MemeToken 提供了强大的价格分析能力，可以用于各种 DeFi 应用场景。 