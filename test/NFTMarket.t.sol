// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/MockNFT.sol";
import "../src/MockToken.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    MockNFT public nft;
    MockToken public token;

    address public owner = address(0x1);
    address public seller = address(0x2);
    address public buyer = address(0x3);
    
    uint256 public tokenId;
    uint256 public listingPrice = 1000 * 10**18; // 1000 tokens
    
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

    function setUp() public {
        vm.startPrank(owner);
        
        // 部署合约
        market = new NFTMarket();
        nft = new MockNFT();
        token = new MockToken();
        
        // 铸造NFT给seller
        vm.stopPrank();
        vm.startPrank(owner);
        tokenId = nft.mint(seller, 1);
        
        // 给buyer铸造ERC20代币
        token.mint(buyer, 10000 * 10**18); // 10000 tokens
        
        vm.stopPrank();
    }

    // 测试成功上架NFT
    function testListNFTSuccess() public {
        vm.startPrank(seller);
        
        // 授权市场合约操作NFT
        nft.approve(address(market), tokenId);
        
        // 期望事件被触发
        vm.expectEmit(true, true, true, true);
        emit NFTListed(seller, address(nft), tokenId, address(token), listingPrice);
        
        // 上架NFT
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        // 验证listing存在并且信息正确
        (
            address _seller,
            address _nftContract,
            uint256 _tokenId,
            address _paymentToken,
            uint256 _price,
            bool _isActive
        ) = market.listings(address(nft), tokenId);
        
        assertEq(_seller, seller);
        assertEq(_nftContract, address(nft));
        assertEq(_tokenId, tokenId);
        assertEq(_paymentToken, address(token));
        assertEq(_price, listingPrice);
        assertEq(_isActive, true);
        
        vm.stopPrank();
    }
    
    // 测试上架NFT失败 - 没有授权
    function testListNFTFailNoApproval() public {
        vm.startPrank(seller);
        
        // 不授权市场合约操作NFT
        
        // 上架NFT，预期会失败
        vm.expectRevert("NFTMarket: NFT not approved for marketplace");
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        vm.stopPrank();
    }
    
    // 测试上架NFT失败 - 非NFT拥有者
    function testListNFTFailNotOwner() public {
        vm.startPrank(buyer);
        
        // 上架NFT，预期会失败
        vm.expectRevert("NFTMarket: Not the owner of the NFT");
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        vm.stopPrank();
    }
    
    // 测试上架NFT失败 - 价格为0
    function testListNFTFailZeroPrice() public {
        vm.startPrank(seller);
        
        // 授权市场合约操作NFT
        nft.approve(address(market), tokenId);
        
        // 上架NFT，价格为0，预期会失败
        vm.expectRevert("NFTMarket: Price must be greater than zero");
        market.listNFT(address(nft), tokenId, address(token), 0);
        
        vm.stopPrank();
    }
    
    // 测试上架NFT失败 - NFT已经上架
    function testListNFTFailAlreadyListed() public {
        vm.startPrank(seller);
        
        // 授权市场合约操作NFT
        nft.approve(address(market), tokenId);
        
        // 首次上架NFT
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        // 再次上架同一个NFT，预期会失败
        vm.expectRevert("NFTMarket: NFT already listed");
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        vm.stopPrank();
    }
    
    // 测试成功购买NFT
    function testBuyNFTSuccess() public {
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        vm.stopPrank();
        
        // 买家购买NFT
        vm.startPrank(buyer);
        
        // 授权市场合约使用代币
        token.approve(address(market), listingPrice);
        
        // 计算费用
        uint256 fee = (listingPrice * market.feeRate()) / market.FEE_DENOMINATOR();
        uint256 sellerProceeds = listingPrice - fee;
        
        // 记录购买前的余额
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        // 期望事件被触发
        vm.expectEmit(true, true, true, true);
        emit NFTPurchased(buyer, seller, address(nft), tokenId, address(token), listingPrice);
        
        // 购买NFT
        market.buyNFT(address(nft), tokenId);
        
        // 验证NFT所有权已转移
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // 验证代币已正确转移
        assertEq(token.balanceOf(seller), sellerBalanceBefore + sellerProceeds);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + fee);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - listingPrice);
        
        // 验证listing已删除
        (,,,,, bool isActive) = market.listings(address(nft), tokenId);
        assertEq(isActive, false);
        
        vm.stopPrank();
    }
    
    // 测试购买NFT失败 - 自己购买自己的NFT
    function testBuyNFTFailBuySelfListing() public {
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        
        // 卖家尝试购买自己的NFT
        vm.expectRevert("NFTMarket: Cannot buy your own NFT");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }
    
    // 测试购买NFT失败 - NFT不在销售中
    function testBuyNFTFailNotListed() public {
        vm.startPrank(buyer);
        
        // 尝试购买未上架的NFT
        vm.expectRevert("NFTMarket: NFT not listed for sale");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }
    
    // 测试购买NFT失败 - 代币余额不足
    function testBuyNFTFailInsufficientBalance() public {
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        vm.stopPrank();
        
        // 创建一个余额不足的新买家
        address poorBuyer = address(0x4);
        vm.startPrank(owner);
        token.mint(poorBuyer, listingPrice / 2); // 只有一半的代币
        vm.stopPrank();
        
        vm.startPrank(poorBuyer);
        token.approve(address(market), listingPrice);
        
        // 尝试购买NFT，应该失败
        vm.expectRevert(); // ERC20代币转账会失败
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }
    
    // 测试购买NFT失败 - 代币未授权
    function testBuyNFTFailNoTokenApproval() public {
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        // 不授权代币
        
        // 尝试购买NFT，应该失败
        vm.expectRevert(); // ERC20代币转账会失败
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }
    
    // 测试购买NFT失败 - 重复购买
    function testBuyNFTFailAlreadyPurchased() public {
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), listingPrice);
        vm.stopPrank();
        
        // 买家购买NFT
        vm.startPrank(buyer);
        token.approve(address(market), listingPrice);
        market.buyNFT(address(nft), tokenId);
        
        // 尝试再次购买同一个NFT
        vm.expectRevert("NFTMarket: NFT not listed for sale");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }

    // 1. 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT

    // 2. 不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有Token持仓
    function testInvariant_NoTokenBalance() public {
        // 获取初始token余额
        uint256 initialMarketBalance = token.balanceOf(address(market));
        assertEq(initialMarketBalance, 0);
        
        // 设置多个NFT和多个买家进行测试
        uint256[] memory testTokenIds = new uint256[](3);
        address[] memory testBuyers = new address[](3);
        uint256[] memory prices = new uint256[](3);
        
        testTokenIds[0] = 100;
        testTokenIds[1] = 101;
        testTokenIds[2] = 102;
        
        testBuyers[0] = address(0x1234);
        testBuyers[1] = address(0x5678);
        testBuyers[2] = address(0x9ABC);
        
        prices[0] = 100 * 10**18; // 100 tokens
        prices[1] = 200 * 10**18; // 200 tokens
        prices[2] = 500 * 10**18; // 500 tokens
        
        // 铸造NFT给卖家
        vm.startPrank(owner);
        for (uint256 i = 0; i < testTokenIds.length; i++) {
            nft.mint(seller, testTokenIds[i]);
        }
        
        // 给测试买家铸造代币
        for (uint256 i = 0; i < testBuyers.length; i++) {
            token.mint(testBuyers[i], prices[i] * 2);
        }
        vm.stopPrank();
        
        // 卖家上架多个NFT
        vm.startPrank(seller);
        for (uint256 i = 0; i < testTokenIds.length; i++) {
            nft.approve(address(market), testTokenIds[i]);
            market.listNFT(address(nft), testTokenIds[i], address(token), prices[i]);
            
            // 验证市场合约没有token持仓
            assertEq(token.balanceOf(address(market)), 0);
        }
        vm.stopPrank();
        
        // 多个买家购买NFT
        for (uint256 i = 0; i < testBuyers.length; i++) {
            vm.startPrank(testBuyers[i]);
            token.approve(address(market), prices[i]);
            market.buyNFT(address(nft), testTokenIds[i]);
            
            // 验证市场合约没有token持仓
            assertEq(token.balanceOf(address(market)), 0);
            vm.stopPrank();
        }
        
        // 最终验证
        assertEq(token.balanceOf(address(market)), 0);
    }
} 