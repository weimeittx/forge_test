// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {MockNFT} from "../src/MockNft.sol";
import {MockToken} from "../src/MockToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BankScript is Script {
    NFTMarket public market;
    MockNFT public nft;
    MockToken public token;
    MockNFT public nftProxy;
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        market = new NFTMarket();
        console.log("NFTMarket deployed at:", address(market));

        // 部署MockNFT
        nft = new MockNFT();
        console.log("MockNFT deployed at:", address(nft));

        address initialOwner = deployer;
        bytes memory initData = abi.encodeWithSelector(
            MockNFT.initialize.selector,
            initialOwner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(nft), initData);
        console.log("MockNFT Proxy deployed at:", address(proxy));

        nftProxy = MockNFT(address(proxy));
        nftProxy.mint(deployer, 1);

        // 部署MockToken
        token = new MockToken();
        console.log("MockToken deployed at:", address(token));
        token.mint(deployer, 10000 * 10 ** 18);

        token.approve(address(market), 10000 * 10 ** 18);
        nftProxy.setApprovalForAll(address(market), true);
        market.listNFT(address(nftProxy), 1, address(token), 100 * 10 ** 18);

        vm.stopBroadcast();
    }
}
