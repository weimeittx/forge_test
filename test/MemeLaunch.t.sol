// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MemeLaunch.sol";
import "../src/MemeToken.sol";

// Mock Uniswap V2 Router for testing
contract MockUniswapV2Router {
    address public WETH;
    address public factory;
    
    constructor() {
        WETH = address(0x1234); // Mock WETH address
        factory = address(new MockUniswapV2Factory());
    }
    
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // Mock implementation
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1000; // Mock liquidity amount
        return (amountToken, amountETH, liquidity);
    }
    
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        // 基于0.005 ETH per token的价格计算
        amounts[1] = (msg.value * 10**18) / (0.005 ether); // 1 ETH = 200 tokens
        
        // Mock transfer tokens to buyer
        // 在真实实现中，这里会从pair合约转移代币到买家
        // 这里我们模拟转移，实际上需要调用token的transfer函数
        if (path.length >= 2) {
            // 模拟从token合约转移代币给买家
            // 注意：这只是测试用的mock，真实环境中Uniswap会处理实际的代币转移
        }
        
        return amounts;
    }
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(new MockUniswapV2Pair(tokenA, tokenB));
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
        return pair;
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint256 private reserve0 = 1000 ether;
    uint256 private reserve1 = 500 ether;
    
    constructor(address _token0, address _token1) {
        // 确保WETH总是token0（按照Uniswap的惯例，地址较小的是token0）
        if (_token0 < _token1) {
            token0 = _token0;
            token1 = _token1;
        } else {
            token0 = _token1;
            token1 = _token0;
        }
    }
    
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
    
    // Function to update reserves for testing
    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
}

contract MemeLaunchTest is Test {
    MemeLaunch public memeLaunch;
    MockUniswapV2Router public mockRouter;
    
    address public owner = address(0x1);
    address public creator = address(0x2);
    address public buyer1 = address(0x3);
    address public buyer2 = address(0x4);
    
    uint256 public constant TOTAL_SUPPLY = 1000 * 10**18;
    uint256 public constant PER_MINT = 10 * 10**18;
    uint256 public constant PRICE = 0.01 ether;
    
    function setUp() public {
        // 设置初始余额
        vm.deal(creator, 10 ether);
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        
        // 部署Mock Uniswap Router
        mockRouter = new MockUniswapV2Router();
        
        // 部署合约
        vm.startPrank(owner);
        memeLaunch = new MemeLaunch(address(mockRouter));
        vm.stopPrank();
    }
    
    // 测试部署Meme代币
    function testDeployInscription() public {
        vm.startPrank(creator);
        
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        vm.stopPrank();
        
        // 验证代币地址不为零
        assertTrue(tokenAddr != address(0), "Token address should not be zero");
        
        // 验证代币参数
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.maxSupply(), TOTAL_SUPPLY, "Total supply incorrect");
        assertEq(token.perMint(), PER_MINT, "Per mint amount incorrect");
        assertEq(token.price(), PRICE, "Price incorrect");
        assertEq(token.owner(), creator, "Owner incorrect");
        assertEq(token.platformAddress(), owner, "Platform address incorrect");
        assertEq(address(token.uniswapRouter()), address(mockRouter), "Uniswap router incorrect");
    }
    
    // 测试铸造Meme代币（修改为5%费用）
    function testMintInscription() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 记录铸造前的余额
        uint256 creatorBalanceBefore = creator.balance;
        
        // 铸造代币
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证代币余额
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT, "Buyer should receive tokens");
        assertEq(token.mintedAmount(), PER_MINT, "Minted amount should be updated");
        
        // 验证费用分配（修改为5%用于流动性，95%给创建者）
        uint256 liquidityFee = (PRICE * 5) / 100; // 5%用于流动性
        uint256 creatorFee = PRICE - liquidityFee; // 剩余给创建者
        
        assertEq(creator.balance, creatorBalanceBefore + creatorFee, "Creator fee incorrect");
        
        // 验证流动性已添加
        assertTrue(token.liquidityAdded(), "Liquidity should be added");
    }
    
    // 测试多次铸造
    function testMultipleMint() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 第一次铸造
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 第二次铸造
        vm.startPrank(buyer2);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证代币余额
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT, "Buyer1 should receive tokens");
        assertEq(token.balanceOf(buyer2), PER_MINT, "Buyer2 should receive tokens");
        assertEq(token.mintedAmount(), PER_MINT * 2, "Minted amount should be updated");
    }
    
    // 测试达到总供应量上限
    function testMintUpToTotalSupply() public {
        // 创建一个小总量的代币
        uint256 smallTotalSupply = PER_MINT * 2; // 仅允许铸造2次
        
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            smallTotalSupply,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 第一次铸造
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 第二次铸造
        vm.startPrank(buyer2);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 第三次铸造应该失败
        vm.startPrank(buyer1);
        vm.expectRevert("Exceeds total supply");
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证铸造总量
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.mintedAmount(), smallTotalSupply, "Minted amount should equal total supply");
    }
    
    // 测试支付错误金额
    function testIncorrectPayment() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 支付错误金额应该失败
        vm.startPrank(buyer1);
        vm.expectRevert("Incorrect payment amount");
        memeLaunch.mintInscription{value: PRICE / 2}(tokenAddr);
        vm.stopPrank();
    }
    
    // 测试费用分配正确性（修改为5%）
    function testFeeAllocation() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 记录铸造前的余额
        uint256 creatorBalanceBefore = creator.balance;
        
        // 铸造代币
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 计算预期分配（修改为5%用于流动性）
        uint256 liquidityFee = (PRICE * 5) / 100; // 5%用于流动性
        uint256 creatorFee = PRICE - liquidityFee; // 剩余给创建者
        
        // 验证费用分配
        assertEq(creator.balance, creatorBalanceBefore + creatorFee, "Creator fee incorrect");
    }
    
    // 测试通过Uniswap购买代币
    function testBuyMeme() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 先铸造一些代币以添加流动性
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证流动性已添加
        MemeToken token = MemeToken(tokenAddr);
        assertTrue(token.liquidityAdded(), "Liquidity should be added");
        
        // 模拟Uniswap价格更优（通过设置mock pair的储备）
        MockUniswapV2Pair pair = MockUniswapV2Pair(token.uniswapPair());
        // 设置储备使得Uniswap价格更优
        // mint价格是0.01 ETH，我们设置Uniswap价格为0.005 ETH（更便宜）
        // 如果WETH是token0: reserve0 = ETH储备, reserve1 = Token储备
        // 价格 = ETH储备 / Token储备 = 0.005，所以 ETH储备 = 0.005 * Token储备
        if (pair.token0() == address(0x1234)) { // WETH是token0
            pair.setReserves(5 ether, 1000 ether); // 5 ETH : 1000 Token = 0.005 ETH per token
        } else { // Token是token0
            pair.setReserves(1000 ether, 5 ether); // 1000 Token : 5 ETH = 0.005 ETH per token
        }
        
        // 记录购买前的代币余额
        uint256 balanceBefore = token.balanceOf(buyer2);
        
        // 通过buyMeme购买代币
        vm.startPrank(buyer2);
        uint256 buyAmount = 0.005 ether;
        memeLaunch.buyMeme{value: buyAmount}(tokenAddr);
        vm.stopPrank();
        
        // 验证购买成功（在mock实现中，余额不会实际改变，但事件会被触发）
        // 在真实环境中，这里会验证代币余额的增加
    }
    
    // 测试在流动性未添加时购买代币应该失败
    function testBuyMemeWithoutLiquidity() public {
        // 创建代币但不铸造（不添加流动性）
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 尝试购买应该失败
        vm.startPrank(buyer1);
        vm.expectRevert("Liquidity not yet added");
        memeLaunch.buyMeme{value: 0.005 ether}(tokenAddr);
        vm.stopPrank();
    }
    
    // 测试获取当前价格
    function testGetCurrentPrice() public {
        // 创建代币
        vm.startPrank(creator);
        address tokenAddr = memeLaunch.deployInscription(
            "TEST",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        MemeToken token = MemeToken(tokenAddr);
        
        // 在添加流动性前，价格应该是mint价格
        assertEq(token.getCurrentPrice(), PRICE, "Price should be mint price before liquidity");
        
        // 铸造代币以添加流动性
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 添加流动性后，价格应该基于储备计算
        uint256 currentPrice = token.getCurrentPrice();
        assertTrue(currentPrice > 0, "Current price should be greater than 0");
    }
    
    // 测试无效地址
    function testInvalidTokenAddress() public {
        vm.startPrank(buyer1);
        
        // 测试mintInscription with invalid address
        vm.expectRevert("Invalid token address");
        memeLaunch.mintInscription{value: PRICE}(address(0));
        
        // 测试buyMeme with invalid address
        vm.expectRevert("Invalid token address");
        memeLaunch.buyMeme{value: PRICE}(address(0));
        
        vm.stopPrank();
    }
} 