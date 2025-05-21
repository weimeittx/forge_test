// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UpgradeableBox.sol";
import "../src/UpgradeableBoxV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeToV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        console.log("proxyAddress:", proxyAddress);
        vm.startBroadcast(deployerPrivateKey);
        
        // 获取代理合约的当前版本和值
        UpgradeableBox box = UpgradeableBox(proxyAddress);
        console.log("Current version:", box.version());
        console.log("Current value:", box.retrieve());
        
        // 部署V2实现合约
        UpgradeableBoxV2 implementationV2 = new UpgradeableBoxV2();
        console.log("ImplementationV2 deployed at:", address(implementationV2));
        
        // 升级到V2
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(
            address(implementationV2), 
            ""
        );
        
        // 验证升级是否成功
        UpgradeableBoxV2 boxV2 = UpgradeableBoxV2(proxyAddress);
        console.log("New version:", boxV2.version());
        console.log("Value after upgrade:", boxV2.retrieve());
        
        // 测试V2新功能
        boxV2.setName("UpgradedBox");
        console.log("New name:", boxV2.getName());
        
        boxV2.increment(10);
        console.log("Value after increment:", boxV2.retrieve());
        
        vm.stopBroadcast();
    }
} 