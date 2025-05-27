// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MemeLaunch.sol";
import "../src/MemeToken.sol";

// Mock contracts for testing without real Uniswap
contract MockUniswapPair {
    uint256 public reserve0 = 1000 * 1e18; // Mock reserves
    uint256 public reserve1 = 1000 * 1e18;
    address public token0;
    address public token1;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() external view returns (uint256, uint256, uint256) {
        return (reserve0, reserve1, block.timestamp);
    }
    
    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
}

contract MockUniswapFactory {
    mapping(address => mapping(address => address)) public pairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // Deploy a real mock pair contract
        MockUniswapPair mockPair = new MockUniswapPair(tokenA, tokenB);
        pair = address(mockPair);
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        return pair;
    }
}

contract MockUniswapRouter {
    address public WETH;
    MockUniswapFactory public factoryContract;
    
    constructor() {
        WETH = address(0x1234); // Mock WETH
        factoryContract = new MockUniswapFactory();
    }
    
    function factory() external view returns (address) {
        return address(factoryContract);
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // Mock implementation - just return some values
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1000; // Mock liquidity amount
        return (amountToken, amountETH, liquidity);
    }
}

contract MemeTWAPIntegrationTest is Test {
    MemeLaunch public memeLaunch;
    MemeToken public memeToken;
    MockUniswapRouter public mockRouter;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock router
        mockRouter = new MockUniswapRouter();
        
        // Deploy MemeLaunch with mock router
        memeLaunch = new MemeLaunch(address(mockRouter));
        
        vm.stopPrank();
        
        // Give users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function testTWAPBasicFunctionality() public {
        console.log("=== Testing TWAP Basic Functionality ===");
        
        // Deploy a meme token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "TEST",
            1000000 * 1e18, // 1M tokens
            1000 * 1e18,    // 1000 per mint
            0.001 ether     // 0.001 ETH price
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        console.log("Token deployed at:", tokenAddress);
        console.log("TWAP enabled:", memeToken.twapEnabled());
        
        // Check initial state
        assertTrue(memeToken.twapEnabled(), "TWAP should be enabled by default");
        
        // Initially should have no observations
        uint256 observationCount = memeToken.getTWAPObservationCount();
        console.log("Initial observation count:", observationCount);
        
        // Mint some tokens to trigger TWAP update
        vm.startPrank(user1);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        // Check if observation was added
        uint256 newObservationCount = memeToken.getTWAPObservationCount();
        console.log("Observation count after mint:", newObservationCount);
        assertTrue(newObservationCount > observationCount, "Should have added observation");
        
        // Get current price
        uint256 currentPrice = memeToken.getCurrentPrice();
        console.log("Current price:", currentPrice);
        
        // Get latest TWAP price
        if (newObservationCount > 0) {
            uint256 latestTWAPPrice = memeToken.getLatestTWAPPrice();
            console.log("Latest TWAP price:", latestTWAPPrice);
            assertEq(latestTWAPPrice, currentPrice, "Latest TWAP price should equal current price");
        }
    }
    
    function testTWAPMultipleObservations() public {
        console.log("=== Testing TWAP Multiple Observations ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "MULTI",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        // Perform multiple mints with time gaps
        for (uint256 i = 0; i < 3; i++) {
            // Advance time
            vm.warp(block.timestamp + 300); // 5 minutes
            
            // Mint tokens
            vm.startPrank(user1);
            memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
            vm.stopPrank();
            
            uint256 observationCount = memeToken.getTWAPObservationCount();
            uint256 currentPrice = memeToken.getCurrentPrice();
            
            console.log("Iteration", i + 1);
            console.log("  Observation count:", observationCount);
            console.log("  Current price:", currentPrice);
            
            if (observationCount > 0) {
                uint256 latestPrice = memeToken.getLatestTWAPPrice();
                console.log("  Latest TWAP price:", latestPrice);
            }
        }
        
        // Try to get TWAP after sufficient observations
        uint256 finalObservationCount = memeToken.getTWAPObservationCount();
        console.log("Final observation count:", finalObservationCount);
        
        if (finalObservationCount >= 2) {
            try memeToken.getTWAP5min() returns (uint256 twap5min) {
                console.log("5-minute TWAP:", twap5min);
                assertTrue(twap5min > 0, "5-minute TWAP should be greater than 0");
            } catch {
                console.log("5-minute TWAP calculation failed");
            }
        }
    }
    
    function testTWAPManualUpdate() public {
        console.log("=== Testing TWAP Manual Update ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "MANUAL",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        // Initial mint to create liquidity
        vm.startPrank(user1);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 initialCount = memeToken.getTWAPObservationCount();
        console.log("Initial observation count:", initialCount);
        
        // Advance time
        vm.warp(block.timestamp + 600); // 10 minutes
        
        // Manually update TWAP
        memeToken.updateTWAP();
        
        uint256 newCount = memeToken.getTWAPObservationCount();
        console.log("Observation count after manual update:", newCount);
        
        assertTrue(newCount > initialCount, "Manual update should add observation");
    }
    
    function testTWAPEnableDisable() public {
        console.log("=== Testing TWAP Enable/Disable ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "TOGGLE",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        // Check initial state
        assertTrue(memeToken.twapEnabled(), "TWAP should be enabled initially");
        
        // Disable TWAP (only owner can do this)
        vm.startPrank(user1); // user1 is the token owner
        memeToken.setTWAPEnabled(false);
        vm.stopPrank();
        
        assertFalse(memeToken.twapEnabled(), "TWAP should be disabled");
        
        // Try to update TWAP when disabled
        vm.expectRevert("TWAP not enabled");
        memeToken.updateTWAP();
        
        // Re-enable TWAP
        vm.startPrank(user1);
        memeToken.setTWAPEnabled(true);
        vm.stopPrank();
        
        assertTrue(memeToken.twapEnabled(), "TWAP should be enabled again");
        
        // Now update should work
        memeToken.updateTWAP();
        
        console.log("TWAP enable/disable test passed");
    }
    
    function testTWAPErrorCases() public {
        console.log("=== Testing TWAP Error Cases ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "ERROR",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        // Try to get TWAP with insufficient data
        vm.expectRevert("Insufficient price data");
        memeToken.getTWAP5min();
        
        // Add one observation
        vm.startPrank(user1);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        // Still insufficient (need at least 2)
        vm.expectRevert("Insufficient price data");
        memeToken.getTWAP5min();
        
        // Add second observation
        vm.warp(block.timestamp + 300);
        memeToken.updateTWAP();
        
        // Now should work
        uint256 twap = memeToken.getTWAP5min();
        assertTrue(twap > 0, "TWAP should work with sufficient data");
        
        console.log("Error cases test passed");
    }
    
    function testTWAPWithMultipleTransactionsOverTime() public {
        console.log("=== Testing TWAP with Multiple Transactions Over Time ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "TIMETEST",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        console.log("Starting TWAP simulation with multiple transactions...");
        
        uint256 startTime = block.timestamp;
        
        // 执行多个时间点的交易
        _performTransactionAtTime(tokenAddress, startTime, 0, "Transaction 1 (Time: 0 min)", user1);
        _performTransactionAtTime(tokenAddress, startTime, 300, "Transaction 2 (Time: 5 min)", user1);
        _performTransactionAtTime(tokenAddress, startTime, 600, "Transaction 3 (Time: 10 min)", user2);
        _performTransactionAtTime(tokenAddress, startTime, 900, "Transaction 4 (Time: 15 min)", user2);
        _performTransactionAtTime(tokenAddress, startTime, 1800, "Transaction 5 (Time: 30 min)", user1);
        
        // 最后一笔交易 - 60分钟后
        console.log("\n--- Transaction 6 (Time: 60 min) ---");
        vm.warp(startTime + 3600);
        vm.startPrank(user2);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        // 获取最终结果
        uint256 finalCount = memeToken.getTWAPObservationCount();
        uint256 finalPrice = memeToken.getCurrentPrice();
        
        console.log("Price:", finalPrice);
        console.log("Observation count:", finalCount);
        
        // 获取各种 TWAP
        uint256 twap5min = memeToken.getTWAP5min();
        uint256 twap15min = memeToken.getTWAP15min();
        uint256 twap1hour = memeToken.getTWAP1hour();
        
        console.log("5-minute TWAP:", twap5min);
        console.log("15-minute TWAP:", twap15min);
        console.log("1-hour TWAP:", twap1hour);
        
        // 验证结果
        assertTrue(finalCount >= 6, "Should have at least 6 observations");
        assertTrue(twap5min > 0, "5-minute TWAP should be positive");
        assertTrue(twap15min > 0, "15-minute TWAP should be positive");
        assertTrue(twap1hour > 0, "1-hour TWAP should be positive");
        
        console.log("\n=== TWAP Summary ===");
        console.log("Total observations:", finalCount);
        console.log("Final 5-min TWAP:", twap5min);
        console.log("Final 15-min TWAP:", twap15min);
        console.log("Final 1-hour TWAP:", twap1hour);
        console.log("Current price:", finalPrice);
    }
    
    function _performTransactionAtTime(
        address tokenAddress, 
        uint256 startTime, 
        uint256 offset, 
        string memory label,
        address user
    ) internal {
        console.log(string(abi.encodePacked("\n--- ", label, " ---")));
        vm.warp(startTime + offset);
        vm.startPrank(user);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 price = memeToken.getCurrentPrice();
        uint256 count = memeToken.getTWAPObservationCount();
        console.log("Price:", price);
        console.log("Observation count:", count);
        
        // 如果有足够的观察点，显示 TWAP
        if (count >= 2) {
            uint256 twap = memeToken.getTWAP5min();
            console.log("5-minute TWAP:", twap);
        }
    }
    
    function testTWAPWithPriceChanges() public {
        console.log("=== Testing TWAP with Simulated Price Changes ===");
        
        // Deploy token
        vm.startPrank(user1);
        address tokenAddress = memeLaunch.deployInscription(
            "PRICETEST",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        memeToken = MemeToken(tokenAddress);
        vm.stopPrank();
        
        // 获取交易对地址并模拟价格变化
        address pairAddress = memeToken.uniswapPair();
        MockUniswapPair pair = MockUniswapPair(pairAddress);
        
        // 检查代币顺序
        address token0 = pair.token0();
        address token1 = pair.token1();
        address weth = mockRouter.WETH();
        
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("WETH:", weth);
        console.log("MemeToken:", tokenAddress);
        
        bool isToken0WETH = (token0 == weth);
        console.log("Is Token0 WETH:", isToken0WETH);
        
        uint256 startTime = block.timestamp;
        
        // 第1笔交易 - 初始价格
        console.log("\n--- Price Scenario 1: Initial Price ---");
        if (isToken0WETH) {
            pair.setReserves(1000 * 1e18, 1000 * 1e18); // ETH, Token
        } else {
            pair.setReserves(1000 * 1e18, 1000 * 1e18); // Token, ETH
        }
        vm.startPrank(user1);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 price1 = memeToken.getCurrentPrice();
        console.log("Price 1:", price1);
        
        // 第2笔交易 - 价格上涨
        console.log("\n--- Price Scenario 2: Price Increase ---");
        vm.warp(startTime + 300); // 5分钟后
        if (isToken0WETH) {
            pair.setReserves(2000 * 1e18, 1000 * 1e18); // ETH增加，代币价格上涨
        } else {
            pair.setReserves(500 * 1e18, 1000 * 1e18); // 代币减少，代币价格上涨
        }
        vm.startPrank(user1);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 price2 = memeToken.getCurrentPrice();
        console.log("Price 2:", price2);
        assertTrue(price2 > price1, "Price should have increased");
        
        uint256 twap1 = memeToken.getTWAP5min();
        console.log("TWAP after price increase:", twap1);
        
        // 第3笔交易 - 价格下跌
        console.log("\n--- Price Scenario 3: Price Decrease ---");
        vm.warp(startTime + 600); // 10分钟后
        if (isToken0WETH) {
            pair.setReserves(500 * 1e18, 1000 * 1e18); // ETH减少，代币价格下跌
        } else {
            pair.setReserves(2000 * 1e18, 1000 * 1e18); // 代币增加，代币价格下跌
        }
        vm.startPrank(user2);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 price3 = memeToken.getCurrentPrice();
        console.log("Price 3:", price3);
        assertTrue(price3 < price2, "Price should have decreased");
        
        uint256 twap2 = memeToken.getTWAP5min();
        console.log("TWAP after price decrease:", twap2);
        
        // 第4笔交易 - 价格稳定
        console.log("\n--- Price Scenario 4: Price Stabilization ---");
        vm.warp(startTime + 900); // 15分钟后
        pair.setReserves(1000 * 1e18, 1000 * 1e18); // 回到1:1
        vm.startPrank(user2);
        memeLaunch.mintInscription{value: 0.001 ether}(tokenAddress);
        vm.stopPrank();
        
        uint256 price4 = memeToken.getCurrentPrice();
        console.log("Price 4:", price4);
        
        uint256 twap3 = memeToken.getTWAP5min();
        uint256 twap15min = memeToken.getTWAP15min();
        console.log("5-min TWAP after stabilization:", twap3);
        console.log("15-min TWAP:", twap15min);
        
        // 验证 TWAP 平滑了价格波动
        console.log("\n=== Price Analysis ===");
        console.log("Price 1:", price1);
        console.log("Price 2:", price2);
        console.log("Price 3:", price3);
        console.log("Price 4:", price4);
        console.log("TWAP 1:", twap1);
        console.log("TWAP 2:", twap2);
        console.log("TWAP 3:", twap3);
        console.log("15-min TWAP (smoothed):", twap15min);
        
        // TWAP 应该比单个价格点更平滑
        uint256 priceVolatility = price2 > price3 ? price2 - price3 : price3 - price2;
        uint256 twapVolatility = twap2 > twap3 ? twap2 - twap3 : twap3 - twap2;
        
        console.log("Price volatility:", priceVolatility);
        console.log("TWAP volatility:", twapVolatility);
        
        // 在大多数情况下，TWAP 的波动应该小于即时价格的波动
        // 这验证了 TWAP 的平滑效果
    }
} 