// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
import "../src/MockToken.sol";

/**
 * @title VestingExample
 * @dev 展示如何使用 TokenVesting 合约的示例脚本
 */
contract VestingExample is Script {
    TokenVesting public vesting;
    MockToken public token;
    
    // 示例地址（在实际使用中替换为真实地址）
    address public beneficiary = 0x1234567890123456789012345678901234567890;
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18; // 100万代币

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署合约
        console.log("=== Deploy Contracts ===");
        token = new MockToken();
        vesting = new TokenVesting();
        
        console.log("MockToken Address:", address(token));
        console.log("TokenVesting Address:", address(vesting));

        // 2. 铸造代币
        console.log("\n=== Mint Tokens ===");
        token.mint(deployer, TOTAL_AMOUNT);
        console.log("Minted tokens for deployer:", TOTAL_AMOUNT / 10**18, "MTK");

        // 3. 批准并创建归属计划
        console.log("\n=== Create Vesting Schedule ===");
        token.approve(address(vesting), TOTAL_AMOUNT);
        vesting.createVestingSchedule(beneficiary, address(token), TOTAL_AMOUNT);
        
        console.log("Beneficiary:", beneficiary);
        console.log("Total vesting amount:", TOTAL_AMOUNT / 10**18, "MTK");
        console.log("Cliff period:", vesting.CLIFF_DURATION() / 86400, "days");
        console.log("Vesting period:", vesting.VESTING_DURATION() / 86400, "days");
        console.log("Total duration:", vesting.TOTAL_DURATION() / 86400, "days");

        // 4. 查询归属计划信息
        console.log("\n=== Vesting Schedule Info ===");
        (
            address _beneficiary,
            address _token,
            uint256 _totalAmount,
            uint256 _releasedAmount,
            uint256 _startTime,
            bool _revoked
        ) = vesting.getVestingSchedule(beneficiary);
        
        console.log("Beneficiary address:", _beneficiary);
        console.log("Token address:", _token);
        console.log("Total amount:", _totalAmount / 10**18, "MTK");
        console.log("Released amount:", _releasedAmount / 10**18, "MTK");
        console.log("Start time:", _startTime);
        console.log("Revoked:", _revoked);

        // 5. 查询当前状态
        console.log("\n=== Current Status ===");
        uint256 vestedAmount = vesting.getVestedAmount(beneficiary);
        uint256 releasableAmount = vesting.getReleasableAmount(beneficiary);
        uint256 remainingAmount = vesting.getRemainingAmount(beneficiary);
        uint256 timeToNext = vesting.getTimeToNextRelease(beneficiary);
        
        console.log("Vested amount:", vestedAmount / 10**18, "MTK");
        console.log("Releasable amount:", releasableAmount / 10**18, "MTK");
        console.log("Remaining amount:", remainingAmount / 10**18, "MTK");
        console.log("Time to next release:", timeToNext / 86400, "days");

        vm.stopBroadcast();

        // 6. 输出使用说明
        console.log("\n=== Usage Instructions ===");
        console.log("1. Currently in Cliff period, beneficiary cannot release any tokens");
        console.log("2. After 12 months, beneficiary can start calling release() method");
        console.log("3. From month 13, 1/24 of total amount can be released each month");
        console.log("4. After 36 months, all tokens will be fully released");
        console.log("\nMethods beneficiary can call:");
        console.log("- release(): Release currently available tokens");
        console.log("- getReleasableAmount(address): Query releasable amount");
        console.log("- getVestedAmount(address): Query vested amount");
        console.log("- getRemainingAmount(address): Query remaining amount");
        
        console.log("\nMethods owner can call:");
        console.log("- revokeVesting(address): Revoke vesting schedule");
        console.log("- emergencyWithdraw(address, uint256): Emergency withdraw tokens");
    }

    /**
     * @dev 模拟时间推进并展示释放过程
     */
    function simulateVesting() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Simulate Vesting Process ===");
        
        // 假设合约已部署并创建了归属计划
        // 这里需要替换为实际的合约地址
        
        console.log("\n--- Timeline 1: Immediately after deployment ---");
        console.log("Releasable amount: 0 MTK (Cliff period)");
        
        console.log("\n--- Timeline 2: After 12 months (Cliff period ends) ---");
        console.log("Releasable amount: 0 MTK (Linear vesting starts)");
        
        console.log("\n--- Timeline 3: After 13 months ---");
        console.log("Releasable amount: ~41,667 MTK (1/24)");
        
        console.log("\n--- Timeline 4: After 24 months ---");
        console.log("Releasable amount: ~500,000 MTK (12/24)");
        
        console.log("\n--- Timeline 5: After 36 months ---");
        console.log("Releasable amount: 1,000,000 MTK (All)");

        vm.stopBroadcast();
    }
} 