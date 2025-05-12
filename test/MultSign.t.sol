// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MultSign} from "../src/MultSign.sol";

// 简单的测试目标合约，用于多签调用
contract TestTarget {
    uint256 public value;
    address public lastCaller;
    mapping(address => bool) public callers;
    
    function setValue(uint256 _value) external payable {
        value = _value;
        lastCaller = msg.sender;
        callers[msg.sender] = true;
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    receive() external payable {}
}

contract MultSignTest is Test {
    MultSign public multSign;
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    uint256 public requiredConfirmations = 2;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        
        // 创建包含3个持有人的多签钱包，需要2个确认
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        
        multSign = new MultSign(owners, requiredConfirmations);
        
        // 向多签钱包中转入一些ETH以便测试
        vm.deal(address(multSign), 10 ether);
    }

    function test_Constructor() public {
        // 验证初始状态
        assertEq(multSign.numConfirmationsRequired(), requiredConfirmations);
        assertEq(multSign.getOwners().length, 3);
        assertTrue(multSign.isOwner(owner1));
        assertTrue(multSign.isOwner(owner2));
        assertTrue(multSign.isOwner(owner3));
        assertFalse(multSign.isOwner(nonOwner));
    }

    function test_SubmitTransaction() public {
        // 转账给非持有人
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;
        bytes memory data = "";
        
        // 只有持有人可以提交交易
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: not Owner");
        multSign.submitTransaction(recipient, amount, data);
        
        // 持有人提交交易
        vm.prank(owner1);
        uint txIndex = multSign.submitTransaction(recipient, amount, data);
        
        // 验证交易已创建
        (address to, uint value, bytes memory txData, bool executed, uint numConfirmations) = multSign.getTransaction(txIndex);
        assertEq(to, recipient);
        assertEq(value, amount);
        assertEq(txData, data);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
    }

    function test_ConfirmTransaction() public {
        // 创建交易
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;
        
        vm.prank(owner1);
        uint txIndex = multSign.submitTransaction(recipient, amount, "");
        
        // 非持有人不能确认交易
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: not Owner");
        multSign.confirmTransaction(txIndex);
        
        // 持有人确认交易
        vm.prank(owner1);
        multSign.confirmTransaction(txIndex);
        
        // 验证确认状态
        (, , , , uint numConfirmations) = multSign.getTransaction(txIndex);
        assertEq(numConfirmations, 1);
        
        // 同一持有人不能重复确认
        vm.prank(owner1);
        vm.expectRevert("MultSign: The transaction has been confirmed");
        multSign.confirmTransaction(txIndex);
        
        // 另一持有人确认
        vm.prank(owner2);
        multSign.confirmTransaction(txIndex);
        
        // 验证确认数量增加
        (, , , , numConfirmations) = multSign.getTransaction(txIndex);
        assertEq(numConfirmations, 2);
    }

    function test_ExecuteTransaction() public {
        // 创建交易
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;
        uint256 recipientInitialBalance = recipient.balance;
        
        vm.prank(owner1);
        uint txIndex = multSign.submitTransaction(recipient, amount, "");
        
        // 确认次数不足，无法执行
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: Confirm that the quantity is insufficient");
        multSign.executeTransaction(txIndex);
        
        // 持有人确认交易
        vm.prank(owner1);
        multSign.confirmTransaction(txIndex);
        
        // 一个确认不足以执行
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: Confirm that the quantity is insufficient");
        multSign.executeTransaction(txIndex);
        
        // 第二个持有人确认
        vm.prank(owner2);
        multSign.confirmTransaction(txIndex);
        
        // 达到确认门槛，执行交易
        vm.prank(nonOwner); // 任何人都可以执行已确认的交易
        multSign.executeTransaction(txIndex);
        
        // 验证交易执行状态
        (, , , bool executed, ) = multSign.getTransaction(txIndex);
        assertTrue(executed);
        
        // 验证ETH已转移
        assertEq(recipient.balance, recipientInitialBalance + amount);
        
        // 已执行的交易不能再次执行
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: The transaction has been executed");
        multSign.executeTransaction(txIndex);
    }

    function test_RevokeConfirmation() public {
        // 创建交易
        address recipient = makeAddr("recipient");
        
        vm.prank(owner1);
        uint txIndex = multSign.submitTransaction(recipient, 1 ether, "");
        
        // 确认交易
        vm.prank(owner1);
        multSign.confirmTransaction(txIndex);
        
        // 验证确认状态
        (, , , , uint numConfirmations) = multSign.getTransaction(txIndex);
        assertEq(numConfirmations, 1);
        
        // 撤销确认
        vm.prank(owner1);
        multSign.revokeConfirmation(txIndex);
        
        // 验证确认已撤销
        (, , , , numConfirmations) = multSign.getTransaction(txIndex);
        assertEq(numConfirmations, 0);
        
        // 未确认的交易不能撤销
        vm.prank(owner2);
        vm.expectRevert("MultSign: The deal has not been confirmed");
        multSign.revokeConfirmation(txIndex);
    }

    function test_Deposit() public {
        // 向多签钱包存入ETH
        address sender = makeAddr("sender");
        uint256 amount = 2 ether;
        uint256 initialBalance = address(multSign).balance;
        
        vm.deal(sender, amount);
        vm.prank(sender);
        (bool success, ) = address(multSign).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(multSign).balance, initialBalance + amount);
    }

    function test_GetTransactionCount() public {
        // 初始交易数为0
        assertEq(multSign.getTransactionCount(), 0);
        
        // 添加交易
        vm.startPrank(owner1);
        multSign.submitTransaction(makeAddr("recipient1"), 1 ether, "");
        multSign.submitTransaction(makeAddr("recipient2"), 2 ether, "");
        vm.stopPrank();
        
        // 验证交易数
        assertEq(multSign.getTransactionCount(), 2);
    }
    
    // 高级测试：调用外部合约并检查完整流程
    function test_ComplexTransaction() public {
        // 部署测试目标合约
        TestTarget target = new TestTarget();
        
        // 向多签钱包发送一些ETH
        vm.deal(address(multSign), 5 ether);
        
        // 准备调用目标合约的calldata
        uint256 newValue = 12345;
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", newValue);
        
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = multSign.submitTransaction(
            address(target), 
            0.5 ether,  // 发送0.5 ETH到目标合约
            data        // 调用setValue函数
        );
        
        // 持有人1确认交易
        vm.prank(owner1);
        multSign.confirmTransaction(txIndex);
        
        // 持有人2确认交易
        vm.prank(owner2);
        multSign.confirmTransaction(txIndex);
        
        // 执行前检查状态
        assertEq(target.value(), 0);
        assertEq(target.lastCaller(), address(0));
        assertEq(target.getBalance(), 0);
        
        // 执行交易
        vm.prank(nonOwner);
        multSign.executeTransaction(txIndex);
        
        // 验证调用结果
        assertEq(target.value(), newValue);
        assertEq(target.lastCaller(), address(multSign));
        assertTrue(target.callers(address(multSign)));
        assertEq(target.getBalance(), 0.5 ether);
    }
    
    // 高级测试：完整流程，包括多个交易和撤销
    function test_CompleteWorkflow() public {
        // 设置3笔交易
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        TestTarget target = new TestTarget();
        
        bytes memory setValueData = abi.encodeWithSignature("setValue(uint256)", 999);
        
        // 持有人1提交3笔交易
        vm.startPrank(owner1);
        uint txIndex1 = multSign.submitTransaction(recipient1, 1 ether, "");
        uint txIndex2 = multSign.submitTransaction(recipient2, 2 ether, "");
        uint txIndex3 = multSign.submitTransaction(address(target), 0.5 ether, setValueData);
        vm.stopPrank();
        
        // 持有人1确认所有交易
        vm.startPrank(owner1);
        multSign.confirmTransaction(txIndex1);
        multSign.confirmTransaction(txIndex2);
        multSign.confirmTransaction(txIndex3);
        vm.stopPrank();
        
        // 持有人2确认交易1和3，但不确认交易2
        vm.startPrank(owner2);
        multSign.confirmTransaction(txIndex1);
        multSign.confirmTransaction(txIndex3);
        vm.stopPrank();
        
        // 持有人3撤销对交易3的确认，然后确认交易2
        vm.startPrank(owner3);
        multSign.confirmTransaction(txIndex3);
        multSign.revokeConfirmation(txIndex3);
        multSign.confirmTransaction(txIndex2);
        vm.stopPrank();
        
        // 执行交易1
        vm.prank(nonOwner);
        uint256 recipient1InitialBalance = recipient1.balance;
        multSign.executeTransaction(txIndex1);
        assertEq(recipient1.balance, recipient1InitialBalance + 1 ether);
        
        // 执行交易2
        vm.prank(nonOwner);
        uint256 recipient2InitialBalance = recipient2.balance;
        multSign.executeTransaction(txIndex2);
        assertEq(recipient2.balance, recipient2InitialBalance + 2 ether);
        
        // 交易3不能执行，因为确认不足
        vm.prank(nonOwner);
        vm.expectRevert("MultSign: Confirm that the quantity is insufficient");
        multSign.executeTransaction(txIndex3);
        
        // 持有人2再次确认交易3
        vm.prank(owner2);
        multSign.confirmTransaction(txIndex3);
        
        // 现在可以执行交易3
        vm.prank(nonOwner);
        multSign.executeTransaction(txIndex3);
        
        // 验证结果
        assertEq(target.value(), 999);
        assertEq(target.getBalance(), 0.5 ether);
    }
} 