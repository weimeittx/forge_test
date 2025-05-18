// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MemeToken
 * @dev 基础的Meme代币实现，作为代理合约的模板
 */
contract MemeToken is ERC20, Ownable {
    uint256 public maxSupply;
    uint256 public perMint;
    uint256 public price;
    uint256 public mintedAmount;
    address public platformAddress;
    string public memeSymbol;
    string public memeName;
    
    // 构造函数，设置一个默认名称和符号
    constructor() ERC20("Meme Token Template", "TEMPLATE") Ownable(msg.sender) {}
    
    // 初始化函数，用于代理合约
    function initialize(
        string memory symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address creator,
        address _platformAddress
    ) external {
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint amount must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_price > 0, "Price must be greater than 0");
        require(creator != address(0), "Creator cannot be zero address");
        require(_platformAddress != address(0), "Platform address cannot be zero address");
        
        // 在代理模式下，不能修改ERC20名称和符号，但我们可以存储它们
        memeName = string(abi.encodePacked("Meme ", symbol));
        memeSymbol = symbol;
        
        // 设置基本参数
        _transferOwnership(creator);
        _mint(address(this), _totalSupply);
        maxSupply = _totalSupply;
        perMint = _perMint;
        price = _price;
        platformAddress = _platformAddress;
    }
    
    // 铸造函数，由工厂合约调用
    function mint(address to) external payable {
        require(msg.value == price, "Incorrect payment amount");
        require(mintedAmount + perMint <= maxSupply, "Exceeds total supply");
        
        // 计算费用分配
        uint256 platformFee = (msg.value * 1) / 100; // 1%给平台
        uint256 creatorFee = msg.value - platformFee; // 剩余给创建者
        
        // 转账给平台
        (bool platformSuccess, ) = platformAddress.call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");
        
        // 转账给创建者
        (bool creatorSuccess, ) = owner().call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");
        
        // 转让代币
        _transfer(address(this), to, perMint);
        mintedAmount += perMint;
    }
    
    /**
     * @dev 重写name()函数以返回自定义的名称
     */
    function name() public view override returns (string memory) {
        // 如果是模板合约本身，返回基本名称；如果是代理合约，返回自定义名称
        return bytes(memeName).length > 0 ? memeName : super.name();
    }
    
    /**
     * @dev 重写symbol()函数以返回自定义的符号
     */
    function symbol() public view override returns (string memory) {
        // 如果是模板合约本身，返回基本符号；如果是代理合约，返回自定义符号
        return bytes(memeSymbol).length > 0 ? memeSymbol : super.symbol();
    }
} 