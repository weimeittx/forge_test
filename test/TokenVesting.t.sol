// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenVesting.sol";
import "../src/MockToken.sol";

contract TokenVestingTest is Test {
    TokenVesting public vesting;
    MockToken public token;
    
    address public owner;
    address public beneficiary;
    address public otherUser;
    
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18; // 100万代币
    uint256 public constant CLIFF_DURATION = 365 days; // 12个月
    uint256 public constant VESTING_DURATION = 730 days; // 24个月
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 36个月

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingCreated(
        address indexed beneficiary,
        address indexed token,
        uint256 amount,
        uint256 startTime
    );

    function setUp() public {
        owner = address(this);
        beneficiary = makeAddr("beneficiary");
        otherUser = makeAddr("otherUser");
        
        // 部署合约
        token = new MockToken();
        vesting = new TokenVesting();
        
        // 铸造代币给owner
        token.mint(owner, TOTAL_AMOUNT);
        
        // 批准vesting合约使用代币
        token.approve(address(vesting), TOTAL_AMOUNT);
    }

    function testCreateVestingSchedule() public {
        vm.expectEmit(true, true, false, true);
        emit VestingCreated(beneficiary, address(token), TOTAL_AMOUNT, block.timestamp);
        
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 验证归属计划创建成功
        (
            address _beneficiary,
            address _token,
            uint256 _totalAmount,
            uint256 _releasedAmount,
            uint256 _startTime,
            bool _revoked
        ) = vesting.getVestingSchedule(beneficiary);
        
        assertEq(_beneficiary, beneficiary);
        assertEq(_token, address(token));
        assertEq(_totalAmount, TOTAL_AMOUNT);
        assertEq(_releasedAmount, 0);
        assertEq(_startTime, block.timestamp);
        assertFalse(_revoked);
        
        // 验证代币已转入合约
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
        assertEq(token.balanceOf(owner), 0);
    }

    function testCreateVestingScheduleFailures() public {
        // 测试零地址受益人
        vm.expectRevert("Beneficiary cannot be zero address");
        vesting.createVestingSchedule(address(0), address(token), TOTAL_AMOUNT);
        
        // 测试零地址代币
        vm.expectRevert("Token cannot be zero address");
        vesting.createVestingSchedule(beneficiary, address(0), TOTAL_AMOUNT);
        
        // 测试零金额
        vm.expectRevert("Amount must be greater than 0");
        vesting.createVestingSchedule(beneficiary, address(token), 0);
        
        // 创建第一个归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 测试重复创建
        token.mint(owner, TOTAL_AMOUNT);
        token.approve(address(vesting), TOTAL_AMOUNT);
        vm.expectRevert("Vesting schedule already exists");
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
    }

    function testReleaseInCliffPeriod() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 在cliff期内尝试释放
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
        
        // 验证可释放金额为0
        assertEq(vesting.getReleasableAmount(beneficiary), 0);
        assertEq(vesting.getVestedAmount(beneficiary), 0);
    }

    function testReleaseAfterCliff() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 跳过cliff期（12个月）
        vm.warp(block.timestamp + CLIFF_DURATION);
        
        // 此时应该没有代币可释放（需要进入线性释放期）
        assertEq(vesting.getVestedAmount(beneficiary), 0);
        assertEq(vesting.getReleasableAmount(beneficiary), 0);
        
        // 跳过1个月进入线性释放期
        vm.warp(block.timestamp + 30 days);
        
        // 计算预期的归属金额（1个月的线性释放）
        uint256 expectedVested = (TOTAL_AMOUNT * 30 days) / VESTING_DURATION;
        uint256 actualVested = vesting.getVestedAmount(beneficiary);
        
        // 允许小的误差
        assertApproxEqAbs(actualVested, expectedVested, 1e15);
        
        // 释放代币
        vm.prank(beneficiary);
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(beneficiary, actualVested);
        vesting.release();
        
        // 验证代币已释放
        assertEq(token.balanceOf(beneficiary), actualVested);
        assertEq(vesting.getReleasableAmount(beneficiary), 0);
    }

    function testLinearVesting() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 跳过cliff期 + 12个月（线性释放期的一半）
        vm.warp(block.timestamp + CLIFF_DURATION + 365 days);
        
        // 计算预期的归属金额（12个月的线性释放，应该是总量的一半）
        uint256 expectedVested = (TOTAL_AMOUNT * 365 days) / VESTING_DURATION;
        uint256 actualVested = vesting.getVestedAmount(beneficiary);
        
        // 验证归属金额约为总量的一半
        assertApproxEqAbs(actualVested, TOTAL_AMOUNT / 2, 1e16);
        
        // 释放代币
        vm.prank(beneficiary);
        vesting.release();
        
        // 验证代币已释放
        assertApproxEqAbs(token.balanceOf(beneficiary), TOTAL_AMOUNT / 2, 1e16);
    }

    function testFullVesting() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 跳过整个归属期
        vm.warp(block.timestamp + TOTAL_DURATION);
        
        // 验证全部代币已归属
        assertEq(vesting.getVestedAmount(beneficiary), TOTAL_AMOUNT);
        assertEq(vesting.getReleasableAmount(beneficiary), TOTAL_AMOUNT);
        
        // 释放全部代币
        vm.prank(beneficiary);
        vesting.release();
        
        // 验证全部代币已释放
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
        assertEq(vesting.getReleasableAmount(beneficiary), 0);
        assertEq(vesting.getRemainingAmount(beneficiary), 0);
    }

    function testMultipleReleases() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 跳过cliff期 + 6个月
        vm.warp(block.timestamp + CLIFF_DURATION + 180 days);
        
        // 第一次释放
        uint256 firstVested = vesting.getVestedAmount(beneficiary);
        vm.prank(beneficiary);
        vesting.release();
        uint256 firstBalance = token.balanceOf(beneficiary);
        
        // 再跳过6个月
        vm.warp(block.timestamp + 180 days);
        
        // 第二次释放
        uint256 secondVested = vesting.getVestedAmount(beneficiary);
        uint256 secondReleasable = vesting.getReleasableAmount(beneficiary);
        
        vm.prank(beneficiary);
        vesting.release();
        uint256 secondBalance = token.balanceOf(beneficiary);
        
        // 验证第二次释放的金额
        assertEq(secondBalance - firstBalance, secondReleasable);
        assertEq(secondBalance, secondVested);
    }

    function testRevokeVesting() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 跳过cliff期 + 6个月
        vm.warp(block.timestamp + CLIFF_DURATION + 180 days);
        
        uint256 vestedBeforeRevoke = vesting.getVestedAmount(beneficiary);
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        // 撤销归属计划
        vesting.revokeVesting(beneficiary);
        
        // 验证受益人收到了已归属的代币
        assertEq(token.balanceOf(beneficiary), vestedBeforeRevoke);
        
        // 验证所有者收到了剩余代币
        uint256 remainingAmount = TOTAL_AMOUNT - vestedBeforeRevoke;
        assertEq(token.balanceOf(owner), ownerBalanceBefore + remainingAmount);
        
        // 验证归属计划已标记为撤销
        (, , , , , bool revoked) = vesting.getVestingSchedule(beneficiary);
        assertTrue(revoked);
        
        // 验证无法再释放代币
        assertEq(vesting.getReleasableAmount(beneficiary), 0);
    }

    function testUnauthorizedAccess() public {
        // 非所有者尝试创建归属计划
        vm.prank(otherUser);
        vm.expectRevert();
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 非所有者尝试撤销归属计划
        vm.prank(otherUser);
        vm.expectRevert();
        vesting.revokeVesting(beneficiary);
        
        // 非受益人尝试释放代币
        vm.warp(block.timestamp + TOTAL_DURATION);
        vm.prank(otherUser);
        vm.expectRevert("No vesting schedule found");
        vesting.release();
    }

    function testGetTimeToNextRelease() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 在cliff期内
        uint256 timeToNext = vesting.getTimeToNextRelease(beneficiary);
        assertEq(timeToNext, CLIFF_DURATION);
        
        // 跳过一半cliff期
        vm.warp(block.timestamp + CLIFF_DURATION / 2);
        timeToNext = vesting.getTimeToNextRelease(beneficiary);
        assertEq(timeToNext, CLIFF_DURATION / 2);
        
        // 跳过整个归属期
        vm.warp(block.timestamp + TOTAL_DURATION);
        timeToNext = vesting.getTimeToNextRelease(beneficiary);
        assertEq(timeToNext, 0);
    }

    function testGetBeneficiaries() public {
        address beneficiary2 = makeAddr("beneficiary2");
        
        // 创建第一个归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT / 2);
        
        // 铸造更多代币并创建第二个归属计划
        token.mint(owner, TOTAL_AMOUNT);
        token.approve(address(vesting), TOTAL_AMOUNT);
        vesting.createVestingSchedule(beneficiary2, address(token), TOTAL_AMOUNT / 2);
        
        // 验证受益人列表
        address[] memory beneficiaries = vesting.getBeneficiaries();
        assertEq(beneficiaries.length, 2);
        assertEq(beneficiaries[0], beneficiary);
        assertEq(beneficiaries[1], beneficiary2);
    }

    function testEmergencyWithdraw() public {
        // 创建归属计划
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        // 铸造额外代币到合约（模拟意外转入）
        token.mint(address(vesting), 1000 * 10**18);
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 emergencyAmount = 1000 * 10**18;
        
        // 紧急提取
        vesting.emergencyWithdraw(address(token), emergencyAmount);
        
        // 验证代币已提取给所有者
        assertEq(token.balanceOf(owner), ownerBalanceBefore + emergencyAmount);
    }
} 