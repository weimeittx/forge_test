// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./MemeToken.sol";

/**
 * @title MemeLaunch
 * @dev 一个基于最小代理模式的Meme代币发射平台
 */
contract MemeLaunch is Ownable {
    using Clones for address;
    
    // 原始Meme代币实现合约地址
    address public immutable implementation;
    
    // 部署成功事件
    event DeploymentSuccess(
        address indexed deployer,
        address indexed tokenAddress,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    // 铸造成功事件
    event MintSuccess(
        address indexed buyer,
        address indexed tokenAddress,
        uint256 amount,
        uint256 value
    );
    
    // 构造函数：部署模板合约并保存实现地址
    constructor() Ownable(msg.sender) {
        // 部署原型合约
        implementation = address(new MemeToken());
    }
    
    /**
     * @dev 创建新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 总发行量
     * @param perMint 单次铸造量
     * @param price 铸造价格（wei）
     * @return 新部署的代币合约地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 验证参数
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint amount must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        require(price > 0, "Price must be greater than 0");
        
        // 使用最小代理模式克隆模板合约
        address newToken = implementation.clone();
        
        // 初始化代币合约
        MemeToken(newToken).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,  // 创建者
            owner()      // 平台地址（项目方）
        );
        
        // 触发事件
        emit DeploymentSuccess(
            msg.sender,
            newToken,
            symbol,
            totalSupply,
            perMint,
            price
        );
        
        return newToken;
    }
    
    /**
     * @dev 铸造Meme代币
     * @param tokenAddr Meme代币合约地址
     */
    function mintInscription(address tokenAddr) external payable {
        // 验证
        require(tokenAddr != address(0), "Invalid token address");
        
        // 调用代币合约的mint函数
        MemeToken(tokenAddr).mint{value: msg.value}(msg.sender);
        
        // 触发事件
        emit MintSuccess(
            msg.sender,
            tokenAddr,
            MemeToken(tokenAddr).perMint(),
            msg.value
        );
    }
}
