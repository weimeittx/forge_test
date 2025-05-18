// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MemeLaunch.sol";
import "../src/MemeToken.sol";

contract MemeLaunchTest is Test {
    MemeLaunch public memeLaunch;
    
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
        
        // 部署合约
        vm.startPrank(owner);
        memeLaunch = new MemeLaunch();
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
    }
    
    // 测试铸造Meme代币
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
        uint256 ownerBalanceBefore = owner.balance;
        uint256 creatorBalanceBefore = creator.balance;
        
        // 铸造代币
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证代币余额
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT, "Buyer should receive tokens");
        assertEq(token.mintedAmount(), PER_MINT, "Minted amount should be updated");
        
        // 验证费用分配
        uint256 platformFee = (PRICE * 1) / 100; // 1%给平台
        uint256 creatorFee = PRICE - platformFee; // 剩余给创建者
        
        assertEq(owner.balance, ownerBalanceBefore + platformFee, "Platform fee incorrect");
        assertEq(creator.balance, creatorBalanceBefore + creatorFee, "Creator fee incorrect");
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
    
    // 测试费用分配正确性
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
        uint256 ownerBalanceBefore = owner.balance;
        uint256 creatorBalanceBefore = creator.balance;
        
        // 铸造代币
        vm.startPrank(buyer1);
        memeLaunch.mintInscription{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 计算预期分配
        uint256 platformFee = (PRICE * 1) / 100; // 1%给平台
        uint256 creatorFee = PRICE - platformFee; // 剩余给创建者
        
        // 验证费用分配
        assertEq(owner.balance, ownerBalanceBefore + platformFee, "Platform fee incorrect");
        assertEq(creator.balance, creatorBalanceBefore + creatorFee, "Creator fee incorrect");
    }
} 