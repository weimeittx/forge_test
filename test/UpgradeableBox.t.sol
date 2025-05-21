// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UpgradeableBox.sol";
import "../src/UpgradeableBoxV2.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeableBoxTest is Test {
    UpgradeableBox public implementation;
    UpgradeableBoxV2 public implementationV2;
    ERC1967Proxy public proxy;
    UpgradeableBox public box;
    UpgradeableBoxV2 public boxV2;
    
    address owner = address(0x1);
    uint256 initialValue = 42;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署实现合约
        implementation = new UpgradeableBox();
        
        // 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableBox.initialize.selector, 
            initialValue
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        
        // 创建代理包装器
        box = UpgradeableBox(address(proxy));
        
        vm.stopPrank();
    }
    
    function testInitialValue() public {
        assertEq(box.retrieve(), initialValue);
    }
    
    function testStore() public {
        vm.startPrank(owner);
        
        uint256 newValue = 100;
        box.store(newValue);
        
        assertEq(box.retrieve(), newValue);
        
        vm.stopPrank();
    }
    
    function testVersion() public {
        assertEq(box.version(), "v1");
    }
    
    function testUpgrade() public {
        vm.startPrank(owner);
        
        // 部署V2实现合约
        implementationV2 = new UpgradeableBoxV2();
        
        // 升级到V2
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(implementationV2), 
            ""
        );
        
        // 创建V2代理包装器
        boxV2 = UpgradeableBoxV2(address(proxy));
        
        // 验证旧数据保持不变
        assertEq(boxV2.retrieve(), box.retrieve());
        
        // 验证版本已更新
        assertEq(boxV2.version(), "v2");
        
        // 测试新增功能
        string memory testName = "TestBox";
        boxV2.setName(testName);
        assertEq(boxV2.getName(), testName);
        
        uint256 incrementAmount = 5;
        uint256 expectedValue = box.retrieve() + incrementAmount;
        boxV2.increment(incrementAmount);
        assertEq(boxV2.retrieve(), expectedValue);
        
        vm.stopPrank();
    }
    
    function testUpgradeUnauthorized() public {
        address attacker = address(0x2);
        vm.startPrank(attacker);
        
        // 部署V2实现合约
        implementationV2 = new UpgradeableBoxV2();
        
        // 尝试从非所有者地址升级，应该失败
        vm.expectRevert("Ownable: caller is not the owner");
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(implementationV2), 
            ""
        );
        
        vm.stopPrank();
    }
} 