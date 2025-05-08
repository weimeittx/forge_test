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

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        
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
}
