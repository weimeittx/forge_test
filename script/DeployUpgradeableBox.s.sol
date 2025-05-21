// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UpgradeableBox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
contract DeployUpgradeableBox is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署实现合约
        UpgradeableBox implementation = new UpgradeableBox();
        console.log("Implementation deployed at:", address(implementation));

        // 准备初始化数据
        uint256 initialValue = 42;
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableBox.initialize.selector, 
            initialValue
        );

        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed at:", address(proxy));

        // 创建代理包装器
        UpgradeableBox box = UpgradeableBox(address(proxy));
        console.log("Initial value:", box.retrieve());
        console.log("Version:", box.version());

        vm.stopBroadcast();
    }
} 