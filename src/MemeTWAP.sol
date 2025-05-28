// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MemeTWAP
 * @dev 简化的 TWAP (时间加权平均价格) 计算库
 */
library MemeTWAP {
    struct PriceObservation {
        uint256 timestamp;
        uint256 price;
        uint256 cumulativePrice;
    }
    
    struct TWAPData {
        PriceObservation[] observations;
        uint256 lastUpdateTime;
        bool initialized;
    }
    
    uint256 constant MIN_TWAP_PERIOD = 300; // 5分钟
    uint256 constant MAX_OBSERVATIONS = 100; // 最大观察数量
    
    /**
     * @dev 初始化 TWAP 数据
     */
    function initialize(TWAPData storage self) internal {
        self.initialized = true;
        self.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev 添加价格观察
     */
    function addObservation(TWAPData storage self, uint256 price) internal {
        require(self.initialized, "TWAP not initialized");
        
        uint256 currentTime = block.timestamp;
        uint256 cumulativePrice = 0;
        
        // 计算累积价格
        if (self.observations.length > 0) {
            PriceObservation memory lastObs = self.observations[self.observations.length - 1];
            uint256 timeDelta = currentTime - lastObs.timestamp;
            cumulativePrice = lastObs.cumulativePrice + (lastObs.price * timeDelta);
        }
        
        // 添加新观察
        self.observations.push(PriceObservation({
            timestamp: currentTime,
            price: price,
            cumulativePrice: cumulativePrice
        }));
        
        // 限制观察数量
        if (self.observations.length > MAX_OBSERVATIONS) {
            // 移除最旧的观察
            for (uint256 i = 0; i < self.observations.length - 1; i++) {
                self.observations[i] = self.observations[i + 1];
            }
            self.observations.pop();
        }
        
        self.lastUpdateTime = currentTime;
    }
    
    /**
     * @dev 计算指定时间段的 TWAP
     */
    function getTWAP(TWAPData storage self, uint256 period) internal view returns (uint256) {
        require(self.initialized, "TWAP not initialized");
        require(period >= MIN_TWAP_PERIOD, "Period too short");
        require(self.observations.length >= 2, "Insufficient price data");
        
        uint256 currentTime = block.timestamp;
        uint256 targetTime = currentTime - period;
        
        // 找到目标时间点的观察
        PriceObservation memory startObs;
        PriceObservation memory endObs = self.observations[self.observations.length - 1];
        
        bool foundStart = false;
        
        // 从最新的观察开始向后查找
        for (uint256 i = self.observations.length; i > 0; i--) {
            PriceObservation memory obs = self.observations[i - 1];
            if (obs.timestamp <= targetTime) {
                startObs = obs;
                foundStart = true;
                break;
            }
        }
        
        if (!foundStart) {
            // 如果没有找到足够早的观察，使用最早的观察
            startObs = self.observations[0];
        }
        
        // 计算 TWAP
        uint256 timeDelta = endObs.timestamp - startObs.timestamp;
        if (timeDelta == 0) {
            return endObs.price;
        }
        
        uint256 priceDelta = endObs.cumulativePrice - startObs.cumulativePrice;
        return priceDelta / timeDelta;
    }
    
    /**
     * @dev 获取最新价格
     */
    function getLatestPrice(TWAPData storage self) internal view returns (uint256) {
        require(self.initialized, "TWAP not initialized");
        require(self.observations.length > 0, "No price data");
        
        return self.observations[self.observations.length - 1].price;
    }
    
    /**
     * @dev 获取观察数量
     */
    function getObservationCount(TWAPData storage self) internal view returns (uint256) {
        return self.observations.length;
    }
} 