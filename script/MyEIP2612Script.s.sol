// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyEIP2612} from "../src/MyEIP2612.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyEIP2612Script is Script {
    MyEIP2612 public token;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        token = new MyEIP2612("MyEIP2612", "MEIP2612", deployer);
        console.log("token deployed at:", address(token));

        token.mint(deployer, 1000000 * 10 ** 18);
        vm.stopBroadcast();
    }
} 