// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
import "../src/MockToken.sol";

contract DeployTokenVesting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署 MockToken
        MockToken token = new MockToken();
        console.log("MockToken deployed at:", address(token));

        // 部署 TokenVesting 合约
        TokenVesting vesting = new TokenVesting();
        console.log("TokenVesting deployed at:", address(vesting));

        // 铸造100万代币给部署者
        uint256 totalAmount = 1_000_000 * 10**18; // 100万代币（假设18位小数）
        token.mint(deployer, totalAmount);
        console.log("Minted", totalAmount / 10**18, "tokens to deployer");

        // 批准 Vesting 合约使用代币
        token.approve(address(vesting), totalAmount);
        console.log("Approved vesting contract to spend tokens");

        // 这里可以设置受益人地址，如果需要立即创建归属计划的话
        // 示例：为特定受益人创建归属计划
        // address beneficiary = 0x...; // 替换为实际的受益人地址
        // vesting.createVestingSchedule(beneficiary, address(token), totalAmount);
        // console.log("Created vesting schedule for beneficiary:", beneficiary);

        vm.stopBroadcast();

        console.log("=== Deployment Summary ===");
        console.log("MockToken:", address(token));
        console.log("TokenVesting:", address(vesting));
        console.log("Total tokens minted:", totalAmount / 10**18);
        console.log("Deployer:", deployer);
    }
} 