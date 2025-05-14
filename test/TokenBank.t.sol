// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/MockToken.sol";
import "forge-std/console.sol";

// 为测试创建模拟Permit2接口
interface IMockPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }
    
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }
    
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract TokenBankTest is Test {
    TokenBank public tokenBank;
    MockToken public mockToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public mockPermit2;
    
    // Permit2合约地址常量
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    uint256 public ownerPrivateKey = 0x01;
    uint256 public user1PrivateKey = 0x02;
    uint256 public user2PrivateKey = 0x03;
    
    // Permit2相关常量
    uint256 constant MAX_UINT = type(uint256).max;
    uint256 constant INITIAL_TOKEN_AMOUNT = 1000 * 10**18; // 1000 tokens
    
    // 用于追踪Permit2调用的标志
    bool public permitTransferFromCalled;
    address public lastPermitOwner;
    address public lastPermitToken;
    uint256 public lastPermitAmount;
    uint256 public lastPermitNonce;
    uint256 public lastPermitDeadline;
    address public lastPermitTo;
    uint256 public lastPermitRequestedAmount;
    bytes public lastPermitSignature;
    
    // 模拟Permit2的permitTransferFrom函数
    function mockPermitTransferFrom(
        IMockPermit2.PermitTransferFrom calldata permit,
        IMockPermit2.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        // 记录调用参数
        permitTransferFromCalled = true;
        lastPermitOwner = owner;
        lastPermitToken = permit.permitted.token;
        lastPermitAmount = permit.permitted.amount;
        lastPermitNonce = permit.nonce;
        lastPermitDeadline = permit.deadline;
        lastPermitTo = transferDetails.to;
        lastPermitRequestedAmount = transferDetails.requestedAmount;
        lastPermitSignature = signature;
        
        // 基本验证
        require(permit.deadline >= block.timestamp, "Permit expired");
        require(signature.length > 0, "Invalid signature length");
        
        // 模拟代币转移，直接从用户向目标地址转移代币
        MockToken(permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
    }
    
    function setUp() public {
        // 使用特定私钥设置地址
        owner = vm.addr(ownerPrivateKey);
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        
        // 部署合约
        vm.startPrank(owner);
        tokenBank = new TokenBank();
        mockToken = new MockToken();
        vm.stopPrank();
        
        // 给测试用户铸造代币
        vm.startPrank(owner);
        mockToken.mint(user1, INITIAL_TOKEN_AMOUNT);
        mockToken.mint(user2, INITIAL_TOKEN_AMOUNT);
        vm.stopPrank();
        
        // 设置模拟Permit2
        mockPermit2 = address(this); // 使用测试合约自身作为mockPermit2
        
        // 用户授权代币给mockPermit2
        vm.startPrank(user1);
        mockToken.approve(mockPermit2, MAX_UINT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        mockToken.approve(mockPermit2, MAX_UINT);
        vm.stopPrank();
    }
    
    // 测试常规存款
    function testDeposit() public {
        uint256 depositAmount = 100 * 10**18;
        
        vm.startPrank(user1);
        // 授权代币给TokenBank
        mockToken.approve(address(tokenBank), depositAmount);
        // 存款
        tokenBank.deposit(address(mockToken), depositAmount);
        vm.stopPrank();
        
        // 验证余额更新
        assertEq(tokenBank.balanceOf(user1, address(mockToken)), depositAmount);
    }
    
    // 测试使用Permit2进行存款
    function testDepositWithPermit2() public {
        // 部署模拟的Permit2
        vm.etch(PERMIT2_ADDRESS, address(this).code);
        
        uint256 depositAmount = 100 * 10**18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(27)); // 任意有效签名
        
        // 重置调用标志
        permitTransferFromCalled = false;
        
        vm.startPrank(user1);
        
        // 使用Permit2进行存款
        tokenBank.depositWithPermit2(
            address(mockToken),
            depositAmount,
            nonce,
            deadline,
            signature
        );
        
        vm.stopPrank();
        
        // 验证Permit2调用
        assertTrue(permitTransferFromCalled, "Permit2.permitTransferFrom was not called");
        assertEq(lastPermitOwner, user1, "Wrong owner in Permit2 call");
        assertEq(lastPermitToken, address(mockToken), "Wrong token in Permit2 call");
        assertEq(lastPermitAmount, depositAmount, "Wrong amount in Permit2 call");
        assertEq(lastPermitNonce, nonce, "Wrong nonce in Permit2 call");
        assertEq(lastPermitDeadline, deadline, "Wrong deadline in Permit2 call");
        assertEq(lastPermitTo, address(tokenBank), "Wrong target in Permit2 call");
        assertEq(lastPermitRequestedAmount, depositAmount, "Wrong requested amount in Permit2 call");
        assertEq(lastPermitSignature, signature, "Wrong signature in Permit2 call");
        
        // 验证余额更新
        assertEq(tokenBank.balanceOf(user1, address(mockToken)), depositAmount);
    }
    
    // 测试Permit2存款 - 过期截止时间
    function testDepositWithPermit2_ExpiredDeadline() public {
        // 部署模拟的Permit2
        vm.etch(PERMIT2_ADDRESS, address(this).code);
        
        uint256 depositAmount = 100 * 10**18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp - 1 hours; // 过期的截止时间
        bytes memory signature = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(27));
        
        vm.startPrank(user1);
        
        // 期望交易失败，因为截止时间已过期
        vm.expectRevert();
        tokenBank.depositWithPermit2(
            address(mockToken),
            depositAmount,
            nonce,
            deadline,
            signature
        );
        
        vm.stopPrank();
    }
    
    // 测试重复使用相同签名的情况
    function testDepositWithPermit2_DoubleSpend() public {
        // 部署模拟的Permit2
        vm.etch(PERMIT2_ADDRESS, address(this).code);
        
        uint256 depositAmount = 50 * 10**18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(27));
        
        // 第一次存款 - 成功
        vm.startPrank(user1);
        tokenBank.depositWithPermit2(
            address(mockToken),
            depositAmount,
            nonce,
            deadline,
            signature
        );
        vm.stopPrank();
        
        // 验证余额
        assertEq(tokenBank.balanceOf(user1, address(mockToken)), depositAmount);
        
        // 修改已使用nonce的标志 - 模拟nonce已被使用情况
        uint256 alreadyUsedNonce = 0;
        
        vm.startPrank(user1);
        // 尝试使用相同nonce再次存款 - 应该失败
        vm.mockCall(
            PERMIT2_ADDRESS,
            abi.encodeWithSelector(
                IMockPermit2.permitTransferFrom.selector,
                abi.encode(
                    IMockPermit2.TokenPermissions(address(mockToken), depositAmount),
                    alreadyUsedNonce,
                    deadline
                ),
                abi.encode(address(tokenBank), depositAmount),
                user1,
                signature
            ),
            abi.encode("Nonce already used")
        );
        
        // 期望失败
        vm.expectRevert();
        tokenBank.depositWithPermit2(
            address(mockToken),
            depositAmount,
            alreadyUsedNonce,
            deadline,
            signature
        );
        
        vm.stopPrank();
    }
    
    // 测试零地址
    function testDepositWithPermit2_ZeroAddress() public {
        // 部署模拟的Permit2
        vm.etch(PERMIT2_ADDRESS, address(this).code);
        
        uint256 depositAmount = 100 * 10**18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(27));
        
        vm.startPrank(user1);
        
        // 期望交易失败，因为代币地址是零地址
        vm.expectRevert("Zero address not allowed");
        tokenBank.depositWithPermit2(
            address(0),
            depositAmount,
            nonce,
            deadline,
            signature
        );
        
        vm.stopPrank();
    }
} 