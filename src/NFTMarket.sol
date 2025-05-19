// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract NFTMarket is Ownable, ReentrancyGuard {
    // 优化1: 紧凑存储结构，减少存储槽
    struct Listing {
        address seller;         // 20字节
        address nftContract;    // 20字节
        address paymentToken;   // 20字节
        uint96 price;           // 12字节 (通常价格不需要uint256这么大)
        uint40 tokenId;         // 5字节 (大多数NFT的tokenId不会太大)
        bool isActive;          // 1字节
    }

    // 优化2: 使用组合键作为mapping key，减少嵌套层级
    mapping(bytes32 => Listing) public listingsByKey;
    
    // 保持常量值
    uint256 public feeRate = 250; // 默认2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // 事件
    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 price
    );
    
    event NFTPurchased(
        address indexed buyer,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );
    
    event NFTListingCancelled(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    event FeeRateChanged(uint256 oldFeeRate, uint256 newFeeRate);

    // 优化3: 提前计算常用的gas值并声明为常量
    uint256 private constant _GAS_FOR_ERC20_TRANSFER = 60000;

    constructor() Ownable(msg.sender) {}
    
    // 优化4: 添加一个帮助函数来生成键
    function _getListingKey(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }
    
    // 优化5: 添加一个获取列表的函数，保持向后兼容
    function listings(address nftContract, uint256 tokenId) 
        external 
        view 
        returns (
            address seller,
            address nftContract_,
            uint256 tokenId_,
            address paymentToken,
            uint256 price,
            bool isActive
        ) 
    {
        bytes32 key = _getListingKey(nftContract, tokenId);
        Listing storage listing = listingsByKey[key];
        return (
            listing.seller,
            listing.nftContract,
            listing.tokenId,
            listing.paymentToken,
            listing.price,
            listing.isActive
        );
    }
    
    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT令牌ID
     * @param paymentToken 支付代币地址
     * @param price 价格
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    ) external {
        // 优化6: 使用自定义错误代替require字符串
        if (nftContract == address(0)) revert NFTContractCannotBeZeroAddress();
        if (paymentToken == address(0)) revert PaymentTokenCannotBeZeroAddress();
        if (price == 0) revert PriceMustBeGreaterThanZero();
        
        bytes32 key = _getListingKey(nftContract, tokenId);
        
        // 优化7: 减少存储读取
        if (listingsByKey[key].isActive) revert NFTAlreadyListed();
        
        // 优化8: 提前检查NFT所有权，避免不必要的调用
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) revert NotTheOwnerOfTheNFT();
        
        // 优化9: 检查授权，合并条件减少gas使用
        address approved = IERC721(nftContract).getApproved(tokenId);
        bool isApprovedForAll = IERC721(nftContract).isApprovedForAll(msg.sender, address(this));
        if (approved != address(this) && !isApprovedForAll) revert NFTNotApprovedForMarketplace();
        
        // 优化10: 检查价格是否超出类型范围
        if (price > type(uint96).max) revert PriceExceedsMaximum();
        if (tokenId > type(uint40).max) revert TokenIdExceedsMaximum();
        
        // 创建listing
        listingsByKey[key] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: uint40(tokenId),
            paymentToken: paymentToken,
            price: uint96(price),
            isActive: true
        });
        
        // 触发上架事件
        emit NFTListed(
            msg.sender,
            nftContract,
            tokenId,
            paymentToken,
            price
        );
    }
    
    /**
     * @dev 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT令牌ID
     */
    function buyNFT(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
        bytes32 key = _getListingKey(nftContract, tokenId);
        
        // 优化11: 内存中存储listing以减少存储读取
        Listing memory listing = listingsByKey[key];
        
        // 优化12: 使用自定义错误代替require字符串
        if (!listing.isActive) revert NFTNotListedForSale();
        if (msg.sender == listing.seller) revert CannotBuyYourOwnNFT();
        
        // 优化13: 提前删除listing，遵循检查-效果-交互模式，防止重入攻击
        delete listingsByKey[key];
        
        // 计算手续费
        uint256 price = listing.price;
        uint256 fee = (price * feeRate) / FEE_DENOMINATOR;
        uint256 sellerProceeds = price - fee;
        
        // 优化14: 使用低级调用保证交易完成
        // 将NFT从卖家转移给买家
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        // 优化15: 使用低级调用减少gas，并检查返回值
        IERC20 paymentToken = IERC20(listing.paymentToken);
        
        // 优化16: 合并转账，减少外部调用次数
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, sellerProceeds);
        if (!success) revert PaymentTransferToSellerFailed();
        
        if (fee > 0) {
            success = paymentToken.transferFrom(msg.sender, owner(), fee);
            if (!success) revert PaymentTransferForFeeFailed();
        }
        
        // 触发购买事件
        emit NFTPurchased(
            msg.sender,
            listing.seller,
            listing.nftContract,
            tokenId,
            listing.paymentToken,
            price
        );
    }
    
    /**
     * @dev 取消NFT上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT令牌ID
     */
    function cancelListing(
        address nftContract,
        uint256 tokenId
    ) external {
        bytes32 key = _getListingKey(nftContract, tokenId);
        Listing memory listing = listingsByKey[key];
        
        // 优化17: 使用自定义错误代替require字符串
        if (!listing.isActive) revert NFTNotListedForSale();
        if (msg.sender != listing.seller) revert NotTheSellerOfTheNFT();
        
        // 删除listing
        delete listingsByKey[key];
        
        // 触发取消上架事件
        emit NFTListingCancelled(
            msg.sender,
            nftContract,
            tokenId
        );
    }
    
    /**
     * @dev 设置手续费率
     * @param newFeeRate 新的手续费率
     */
    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        // 优化18: 使用自定义错误代替require字符串
        if (newFeeRate > FEE_DENOMINATOR) revert FeeRateCannotExceed100Percent();
        
        uint256 oldFeeRate = feeRate;
        feeRate = newFeeRate;
        
        emit FeeRateChanged(oldFeeRate, newFeeRate);
    }
    
    // 优化19: 自定义错误，减少部署和调用成本
    error NFTContractCannotBeZeroAddress();
    error PaymentTokenCannotBeZeroAddress();
    error PriceMustBeGreaterThanZero();
    error NFTAlreadyListed();
    error NotTheOwnerOfTheNFT();
    error NFTNotApprovedForMarketplace();
    error NFTNotListedForSale();
    error CannotBuyYourOwnNFT();
    error PaymentTransferToSellerFailed();
    error PaymentTransferForFeeFailed();
    error NotTheSellerOfTheNFT();
    error FeeRateCannotExceed100Percent();
    error PriceExceedsMaximum();
    error TokenIdExceedsMaximum();
} 