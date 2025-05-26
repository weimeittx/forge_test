// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "v2-periphery/interfaces/IUniswapV2Router02.sol";
import "v2-core/interfaces/IUniswapV2Factory.sol";
import "v2-core/interfaces/IUniswapV2Pair.sol";

/**
 * @title MemeToken
 * @dev 基础的Meme代币实现，作为代理合约的模板，集成Uniswap V2流动性
 */
contract MemeToken is ERC20, Ownable {
    uint256 public maxSupply;
    uint256 public perMint;
    uint256 public price;
    uint256 public mintedAmount;
    address public platformAddress;
    string public memeSymbol;
    string public memeName;
    
    // Uniswap V2 相关
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;
    bool public liquidityAdded;
    
    // 事件
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event TokensBought(address indexed buyer, uint256 tokenAmount, uint256 ethAmount);
    
    // 构造函数，设置一个默认名称和符号
    constructor() ERC20("Meme Token Template", "TEMPLATE") Ownable(msg.sender) {}
    
    // 初始化函数，用于代理合约
    function initialize(
        string memory symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address creator,
        address _platformAddress,
        address _uniswapRouter
    ) external {
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint amount must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_price > 0, "Price must be greater than 0");
        require(creator != address(0), "Creator cannot be zero address");
        require(_platformAddress != address(0), "Platform address cannot be zero address");
        require(_uniswapRouter != address(0), "Uniswap router cannot be zero address");
        
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
        
        // 设置Uniswap路由器
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        
        // 创建交易对
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapRouter.factory());
        uniswapPair = factory.createPair(address(this), uniswapRouter.WETH());
    }
    
    // 铸造函数，由工厂合约调用
    function mint(address to) external payable {
        require(msg.value == price, "Incorrect payment amount");
        require(mintedAmount + perMint <= maxSupply, "Exceeds total supply");
        
        // 计算费用分配 - 修改为5%
        uint256 liquidityFee = (msg.value * 5) / 100; // 5%用于添加流动性
        uint256 creatorFee = msg.value - liquidityFee; // 剩余给创建者
        
        // 转账给创建者
        (bool creatorSuccess, ) = owner().call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");
        
        // 转让代币
        _transfer(address(this), to, perMint);
        mintedAmount += perMint;
        
        // 添加流动性（如果还没有添加过）
        if (!liquidityAdded && liquidityFee > 0) {
            _addInitialLiquidity(liquidityFee);
        }
    }
    
    /**
     * @dev 添加初始流动性
     */
    function _addInitialLiquidity(uint256 ethAmount) internal {
        // 计算要添加的代币数量，基于mint价格
        uint256 tokenAmount = (ethAmount * 10**decimals()) / price;
        
        // 确保合约有足够的代币
        require(balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        
        // 批准路由器使用代币
        _approve(address(this), address(uniswapRouter), tokenAmount);
        
        // 添加流动性
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // 接受任何数量的代币
            0, // 接受任何数量的ETH
            owner(), // 流动性代币发送给创建者
            block.timestamp + 300 // 5分钟超时
        );
        
        liquidityAdded = true;
        emit LiquidityAdded(amountToken, amountETH, liquidity);
    }
    
    /**
     * @dev 通过Uniswap购买代币
     */
    function buyMeme() external payable {
        require(msg.value > 0, "Must send ETH");
        require(liquidityAdded, "Liquidity not yet added");
        
        // 获取当前Uniswap价格
        uint256 currentPrice = getCurrentPrice();
        require(currentPrice < price, "Uniswap price not better than mint price");
        
        // 通过Uniswap购买代币
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(this);
        
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            0, // 接受任何数量的代币
            path,
            msg.sender,
            block.timestamp + 300 // 5分钟超时
        );
        
        emit TokensBought(msg.sender, amounts[1], msg.value);
    }
    
    /**
     * @dev 获取当前Uniswap价格（每个代币需要多少ETH）
     */
    function getCurrentPrice() public view returns (uint256) {
        if (!liquidityAdded) {
            return price; // 如果还没有流动性，返回mint价格
        }
        
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapPair);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        
        // 确定哪个是ETH储备，哪个是代币储备
        address token0 = pair.token0();
        uint256 ethReserve;
        uint256 tokenReserve;
        
        if (token0 == uniswapRouter.WETH()) {
            ethReserve = reserve0;
            tokenReserve = reserve1;
        } else {
            ethReserve = reserve1;
            tokenReserve = reserve0;
        }
        
        if (tokenReserve == 0) {
            return price;
        }
        
        // 计算价格：1个代币需要多少ETH
        return (ethReserve * 10**decimals()) / tokenReserve;
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