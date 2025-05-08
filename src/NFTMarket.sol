// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract NFTMarket is Ownable, ReentrancyGuard {
    struct Listing {
        //卖家
        address seller;
        //nft合约
        address nftContract;
        //nft令牌ID
        uint256 tokenId;
        //支付代币
        address paymentToken;
        //价格
        uint256 price;
        //是否活跃
        bool isActive;
    }

    // 使用nftContract地址和tokenId作为唯一标识
    mapping(address/* nft合约 */ => mapping(uint256/* nft令牌ID */ => Listing /* 上架信息 */)) public listings;
    
    // 市场手续费率（单位：万分之几）
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
    
    //购买事件
    event NFTPurchased(
        address indexed buyer,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );
    
    //取消上架事件
    event NFTListingCancelled(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    //手续费率变化事件
    event FeeRateChanged(uint256 oldFeeRate, uint256 newFeeRate);

    constructor() Ownable(msg.sender) {}
    
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
        // 检查NFT合约地址是否为零地址
        require(nftContract != address(0), "NFTMarket: NFT contract cannot be zero address");
        // 检查支付代币地址是否为零地址
        require(paymentToken != address(0), "NFTMarket: Payment token cannot be zero address");
        // 检查价格是否大于0
        require(price > 0, "NFTMarket: Price must be greater than zero");
        
        // 检查该NFT是否已经在市场上
        require(!listings[nftContract][tokenId].isActive, "NFTMarket: NFT already listed");
        
        // 确保卖家拥有该NFT
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "NFTMarket: Not the owner of the NFT"
        );
        
        // 获取NFT的授权
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this) || 
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)),
            "NFTMarket: NFT not approved for marketplace"
        );
        
        // 创建listing
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
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
        // 获取listing信息
        Listing memory listing = listings[nftContract][tokenId];
        
        // 检查NFT是否正在出售
        require(listing.isActive, "NFTMarket: NFT not listed for sale");
        
        // 检查买家是否为卖家
        require(msg.sender != listing.seller, "NFTMarket: Cannot buy your own NFT");
        
        // 计算手续费
        uint256 fee = (listing.price * feeRate) / FEE_DENOMINATOR;
        uint256 sellerProceeds = listing.price - fee;
        
        // 将NFT从卖家转移给买家
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        // 将代币从买家转移给卖家和平台
        require(
            IERC20(listing.paymentToken).transferFrom(msg.sender, listing.seller, sellerProceeds),
            "NFTMarket: Payment transfer to seller failed"
        );
        
        if (fee > 0) {
            //转手续费
            require(
                IERC20(listing.paymentToken).transferFrom(msg.sender, owner(), fee),
                "NFTMarket: Payment transfer for fee failed"
            );
        }
        
        // 删除listing
        delete listings[nftContract][tokenId];
        
        // 触发购买事件
        emit NFTPurchased(
            msg.sender,
            listing.seller,
            nftContract,
            tokenId,
            listing.paymentToken,
            listing.price
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
        // 获取listing信息
        Listing memory listing = listings[nftContract][tokenId];
        
        // 检查NFT是否正在出售
        require(listing.isActive, "NFTMarket: NFT not listed for sale");
        
        // 检查调用者是否为卖家
        require(msg.sender == listing.seller, "NFTMarket: Not the seller of the NFT");
        
        // 删除listing
        delete listings[nftContract][tokenId];
        
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
        require(newFeeRate <= FEE_DENOMINATOR, "NFTMarket: Fee rate cannot exceed 100%");
        
        uint256 oldFeeRate = feeRate;
        feeRate = newFeeRate;
        
        emit FeeRateChanged(oldFeeRate, newFeeRate);
    }
} 