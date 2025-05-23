// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    address public user6;
    address public user7;
    address public user8;
    address public user9;
    address public user10;
    address public user11;
    address public user12;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");
        user6 = makeAddr("user6");
        user7 = makeAddr("user7");
        user8 = makeAddr("user8");
        user9 = makeAddr("user9");
        user10 = makeAddr("user10");
        user11 = makeAddr("user11");
        user12 = makeAddr("user12");
        
        vm.startPrank(admin);
        bank = new Bank();
        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(user1);
        vm.deal(user1, 2 ether);
        
        assertEq(bank.balanceOf(user1), 0 ether);
        (bool success,) = address(bank).call{value: 1 ether}("");
        require(success, "Deposit failed");
        assertEq(bank.balanceOf(user1), 1 ether);
        vm.stopPrank();
    }
    
    function test_DepositMethod() public {
        // 使用deposit方法而不是receive
        vm.startPrank(user1);
        vm.deal(user1, 2 ether);
        
        assertEq(bank.balanceOf(user1), 0 ether);
        
        // 调用deposit方法
        bank.deposit{value: 1 ether}();
        
        // 验证余额更新
        assertEq(bank.balanceOf(user1), 1 ether);
        
        // 验证用户在排名中
        address[] memory topUsers = bank.getTopUsers(1);
        assertEq(topUsers[0], user1, "User1 should be in top list");
        
        vm.stopPrank();
    }
    
    function test_DepositMethodMinimumAmount() public {
        // 测试最小存款额度限制
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        
        // 尝试存入少于最小限额的金额，应该失败
        vm.expectRevert();
        bank.deposit{value: 0.0009 ether}();
        
        // 验证余额未变化
        assertEq(bank.balanceOf(user1), 0 ether);
        
        // 存入有效金额
        bank.deposit{value: 0.002 ether}();
        
        // 验证余额更新
        assertEq(bank.balanceOf(user1), 0.002 ether);
        
        vm.stopPrank();
    }
    
    function test_DepositMethodMultipleTimes() public {
        // 测试多次存款
        vm.startPrank(user1);
        vm.deal(user1, 3 ether);
        
        // 第一次存款
        bank.deposit{value: 1 ether}();
        assertEq(bank.balanceOf(user1), 1 ether);
        
        // 第二次存款
        bank.deposit{value: 0.5 ether}();
        assertEq(bank.balanceOf(user1), 1.5 ether);
        
        // 第三次存款
        bank.deposit{value: 0.3 ether}();
        assertEq(bank.balanceOf(user1), 1.8 ether);
        
        vm.stopPrank();
        
        // 检查排名
        address[] memory topUsers = bank.getTopUsers(1);
        assertEq(topUsers[0], user1, "User1 should still be top after multiple deposits");
    }
    
    function test_DepositMethodRanking() public {
        // 测试多个用户使用deposit方法时的排名
        // 用户1存款
        vm.startPrank(user1);
        vm.deal(user1, 2 ether);
        bank.deposit{value: 1 ether}();
        vm.stopPrank();
        
        // 用户2存入更多
        vm.startPrank(user2);
        vm.deal(user2, 3 ether);
        bank.deposit{value: 2 ether}();
        vm.stopPrank();
        
        // 用户3存入更少
        vm.startPrank(user3);
        vm.deal(user3, 1 ether);
        bank.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        // 检查排名
        address[] memory topUsers = bank.getTopUsers(3);
        assertEq(topUsers[0], user2, "User2 should be first");
        assertEq(topUsers[1], user1, "User1 should be second");
        assertEq(topUsers[2], user3, "User3 should be third");
        
        // 用户1再次存款超过用户2
        vm.startPrank(user1);
        vm.deal(user1, 2 ether); // 已有1，再加2，总共3
        bank.deposit{value: 2 ether}();
        vm.stopPrank();
        
        // 再次检查排名
        address[] memory updatedTopUsers = bank.getTopUsers(3);
        assertEq(updatedTopUsers[0], user1, "User1 should now be first");
        assertEq(updatedTopUsers[1], user2, "User2 should now be second");
        assertEq(updatedTopUsers[2], user3, "User3 should still be third");
    }

    function test_Withdraw() public {
        // 先存入一些资金
        vm.startPrank(user1);
        vm.deal(user1, 2 ether);
        (bool success,) = address(bank).call{value: 1 ether}("");
        require(success, "Deposit failed");
        vm.stopPrank();

        // 管理员提现
        vm.startPrank(admin);
        uint256 balanceBefore = admin.balance;
        bank.withdraw();
        uint256 balanceAfter = admin.balance;
        
        assertEq(balanceAfter - balanceBefore, 1 ether, "Withdraw amount incorrect");
        assertEq(address(bank).balance, 0, "Bank balance should be 0 after withdraw");
        vm.stopPrank();
    }

    function test_NonAdminWithdraw() public {
        vm.startPrank(user1);
        vm.expectRevert("Only admin can withdraw");
        bank.withdraw();
        vm.stopPrank();
    }

    function test_Top3Depositors() public {
        // 用户1存入2 ETH
        vm.startPrank(user1);
        vm.deal(user1, 3 ether);
        (bool success1,) = address(bank).call{value: 2 ether}("");
        require(success1, "Deposit failed");
        vm.stopPrank();

        // 用户2存入1.5 ETH
        vm.startPrank(user2);
        vm.deal(user2, 2 ether);
        (bool success2,) = address(bank).call{value: 1.5 ether}("");
        require(success2, "Deposit failed");
        vm.stopPrank();

        // 用户3存入1 ETH
        vm.startPrank(user3);
        vm.deal(user3, 2 ether);
        (bool success3,) = address(bank).call{value: 1 ether}("");
        require(success3, "Deposit failed");
        vm.stopPrank();

        // 用户4存入0.5 ETH
        vm.startPrank(user4);
        vm.deal(user4, 1 ether);
        (bool success4,) = address(bank).call{value: 0.5 ether}("");
        require(success4, "Deposit failed");
        vm.stopPrank();

        // 检查Top3
        address[3] memory top3 = bank.getTop3();
        assertEq(top3[0], user1, "First place should be user1");
        assertEq(top3[1], user2, "Second place should be user2");
        assertEq(top3[2], user3, "Third place should be user3");
    }
    
    function test_Top10Depositors() public {
        // 创建12个用户，其中前10个会被记录
        depositEther(user1, 10 ether);
        depositEther(user2, 9 ether);
        depositEther(user3, 8 ether);
        depositEther(user4, 7 ether);
        depositEther(user5, 6 ether);
        depositEther(user6, 5 ether);
        depositEther(user7, 4 ether);
        depositEther(user8, 3 ether);
        depositEther(user9, 2 ether);
        depositEther(user10, 1 ether);
        depositEther(user11, 0.5 ether);
        depositEther(user12, 0.1 ether);
        
        // 检查Top10
        address[] memory top10 = bank.getTop10();
        
        // 验证前10名用户
        assertEq(top10.length, 10, "Should have 10 users in the list");
        assertEq(top10[0], user1, "First place should be user1");
        assertEq(top10[1], user2, "Second place should be user2");
        assertEq(top10[2], user3, "Third place should be user3");
        assertEq(top10[3], user4, "Fourth place should be user4");
        assertEq(top10[4], user5, "Fifth place should be user5");
        assertEq(top10[5], user6, "Sixth place should be user6");
        assertEq(top10[6], user7, "Seventh place should be user7");
        assertEq(top10[7], user8, "Eighth place should be user8");
        assertEq(top10[8], user9, "Ninth place should be user9");
        assertEq(top10[9], user10, "Tenth place should be user10");
        
        // 验证user11不在列表中
        address[] memory top11 = bank.getTopUsers(11);
        assertEq(top11.length, 10, "Should only return 10 users even when asking for 11");
    }
    
    function test_UpdateTopList() public {
        // 初始存款
        depositEther(user1, 1 ether);
        depositEther(user2, 2 ether);
        depositEther(user3, 3 ether);
        
        // 检查初始排名
        address[] memory initialTop = bank.getTopUsers(3);
        assertEq(initialTop[0], user3, "First place should be user3");
        assertEq(initialTop[1], user2, "Second place should be user2");
        assertEq(initialTop[2], user1, "Third place should be user1");
        
        // 用户1增加存款，应该变成第一名
        vm.startPrank(user1);
        vm.deal(user1, 5 ether); // 这里是设置余额，不是增加
        (bool success,) = address(bank).call{value: 4 ether}("");
        require(success, "Deposit failed");
        vm.stopPrank();
        
        // 检查更新后的排名
        address[] memory updatedTop = bank.getTopUsers(3);
        assertEq(updatedTop[0], user1, "First place should now be user1");
        assertEq(updatedTop[1], user3, "Second place should now be user3");
        assertEq(updatedTop[2], user2, "Third place should now be user2");
    }
    
    // 辅助函数，为用户存入以太币
    function depositEther(address user, uint256 amount) internal {
        vm.startPrank(user);
        vm.deal(user, amount + 1 ether); // 确保用户有足够的ETH
        (bool success,) = address(bank).call{value: amount}("");
        require(success, "Deposit failed");
        vm.stopPrank();
    }
}
