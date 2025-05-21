// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockNFT} from "../src/MockNft.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockNFTScript is Script {
    MockNFT public nft;
    MockNFT public nftProxy;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockNFT implementation contract
        nft = new MockNFT();
        console.log("MockNFT implementation deployed at:", address(nft));

        // Set initial owner as the deployer
        address initialOwner = deployer;
        console.log("Initial owner address:", initialOwner);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            MockNFT.initialize.selector,
            initialOwner
        );

        // Deploy proxy contract and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(nft), initData);
        console.log("MockNFT proxy deployed at:", address(proxy));
        
        // Access NFT instance through proxy
        nftProxy = MockNFT(address(proxy));
        nftProxy.mint(deployer, 2);
        console.log("NFT name:", nftProxy.name());
        console.log("NFT symbol:", nftProxy.symbol());
        console.log("NFT owner:", nftProxy.owner());

        vm.stopBroadcast();
    }
} 