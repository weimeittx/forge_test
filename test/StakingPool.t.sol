// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingPool.sol";
import "../src/KKToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public owner = address(this);
    
    function setUp() public {
        stakingPool = new StakingPool();
        kkToken = stakingPool.kkToken();
        
        // 给测试用户一些 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function testStake() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();
        
        assertEq(stakingPool.balanceOf(user1), stakeAmount);
        assertEq(stakingPool.getTotalStaked(), stakeAmount);
        assertEq(address(stakingPool).balance, stakeAmount);
        
        vm.stopPrank();
    }
    
    function testMultipleStakes() public {
        // User1 质押
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // User2 质押
        vm.startPrank(user2);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        assertEq(stakingPool.balanceOf(user1), 1 ether);
        assertEq(stakingPool.balanceOf(user2), 2 ether);
        assertEq(stakingPool.getTotalStaked(), 3 ether);
    }
    
    function testUnstake() public {
        vm.startPrank(user1);
        
        // 先质押
        stakingPool.stake{value: 2 ether}();
        
        // 记录初始余额
        uint256 initialBalance = user1.balance;
        
        // 赎回一部分
        stakingPool.unstake(1 ether);
        
        assertEq(stakingPool.balanceOf(user1), 1 ether);
        assertEq(stakingPool.getTotalStaked(), 1 ether);
        assertEq(user1.balance, initialBalance + 1 ether);
        
        vm.stopPrank();
    }
    
    function testRewardCalculation() public {
        vm.startPrank(user1);
        
        // 质押 1 ETH
        stakingPool.stake{value: 1 ether}();
        
        // 模拟过去几个区块
        vm.roll(block.number + 10);
        
        // 检查奖励计算
        uint256 expectedReward = 10 * 10 * 1e18; // 10 blocks * 10 KK per block
        uint256 actualReward = stakingPool.earned(user1);
        
        assertEq(actualReward, expectedReward);
        
        vm.stopPrank();
    }
    
    function testClaim() public {
        vm.startPrank(user1);
        
        // 质押
        stakingPool.stake{value: 1 ether}();
        
        // 模拟过去几个区块
        vm.roll(block.number + 5);
        
        // 领取奖励
        uint256 rewardBefore = stakingPool.earned(user1);
        stakingPool.claim();
        
        assertEq(kkToken.balanceOf(user1), rewardBefore);
        assertEq(stakingPool.earned(user1), 0);
        
        vm.stopPrank();
    }
    
    function testMultipleUsersRewardDistribution() public {
        // User1 质押 1 ETH
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // 过去 5 个区块
        vm.roll(block.number + 5);
        
        // User2 质押 2 ETH
        vm.startPrank(user2);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        // 再过去 6 个区块
        vm.roll(block.number + 6);
        
        // User1 应该获得：5 blocks * 10 KK + 6 blocks * 10 KK * (1/3)
        uint256 user1Expected = 5 * 10 * 1e18 + 6 * 10 * 1e18 / 3;
        // User2 应该获得：6 blocks * 10 KK * (2/3)
        uint256 user2Expected = 6 * 10 * 1e18 * 2 / 3;
        
        assertApproxEqAbs(stakingPool.earned(user1), user1Expected, 1e15); // 允许小误差
        assertApproxEqAbs(stakingPool.earned(user2), user2Expected, 1e15);
    }
    
    function testCannotStakeZero() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Cannot stake 0 ETH");
        stakingPool.stake{value: 0}();
        
        vm.stopPrank();
    }
    
    function testCannotUnstakeMoreThanStaked() public {
        vm.startPrank(user1);
        
        stakingPool.stake{value: 1 ether}();
        
        vm.expectRevert("Insufficient staked amount");
        stakingPool.unstake(2 ether);
        
        vm.stopPrank();
    }
    
    function testCannotClaimZeroReward() public {
        vm.startPrank(user1);
        
        vm.expectRevert("No rewards to claim");
        stakingPool.claim();
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        // 用户质押一些 ETH
        vm.startPrank(user1);
        stakingPool.stake{value: 5 ether}();
        vm.stopPrank();
        
        // Owner 紧急提取
        uint256 ownerBalanceBefore = owner.balance;
        stakingPool.emergencyWithdraw();
        
        assertEq(address(stakingPool).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + 5 ether);
    }
    
    receive() external payable {}
} 