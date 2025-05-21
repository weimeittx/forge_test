// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeableBox
 * @dev 这是一个简单的可升级合约示例，使用UUPS代理模式
 */
contract UpgradeableBox is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _value;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev 替代构造函数的初始化函数
     * @param initialValue 初始值
     */
    function initialize(uint256 initialValue) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        _value = initialValue;
    }
    
    /**
     * @dev 存储一个新值
     * @param newValue 要存储的新值
     */
    function store(uint256 newValue) public {
        _value = newValue;
    }
    
    /**
     * @dev 返回当前存储的值
     * @return 当前值
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }
    
    /**
     * @dev 获取合约版本
     */
    function version() public pure virtual returns (string memory) {
        return "v1";
    }
    
    /**
     * @dev 授权升级函数，仅合约所有者可以升级合约
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 