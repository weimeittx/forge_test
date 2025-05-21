// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UpgradeableBox.sol";

/**
 * @title UpgradeableBoxV2
 * @dev 这是UpgradeableBox的升级版本，增加了新功能
 */
contract UpgradeableBoxV2 is UpgradeableBox {
    // 新增状态变量
    string private _name;
    
    /**
     * @dev 设置名称
     * @param newName 新名称
     */
    function setName(string memory newName) public onlyOwner {
        _name = newName;
    }
    
    /**
     * @dev 获取名称
     * @return 当前名称
     */
    function getName() public view returns (string memory) {
        return _name;
    }
    
    /**
     * @dev 递增存储的值
     * @param amount 增加的数量
     */
    function increment(uint256 amount) public {
        store(retrieve() + amount);
    }
    
    /**
     * @dev 获取合约版本
     */
    function version() public pure override returns (string memory) {
        return "v2";
    }
} 