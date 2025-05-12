// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultSign} from "../src/MultSign.sol";

contract MultSignScript is Script {
    MultSign public multSign;
    
    // 从环境变量中获取多签持有人地址
    function getOwnersFromEnv() internal returns (address[] memory) {
        string memory ownersStr = vm.envString("OWNERS");
        // 解析由逗号分隔的地址字符串
        bytes memory ownersBytes = bytes(ownersStr);
        
        // 计算地址数量
        uint count = 1; // 至少有一个地址
        for (uint i = 0; i < ownersBytes.length; i++) {
            if (ownersBytes[i] == bytes1(",")) {
                count++;
            }
        }
        
        address[] memory owners = new address[](count);
        
        // 解析每个地址
        uint ownerIndex = 0;
        uint lastIndex = 0;
        for (uint i = 0; i <= ownersBytes.length; i++) {
            if (i == ownersBytes.length || ownersBytes[i] == bytes1(",")) {
                string memory addrStr;
                if (i == ownersBytes.length) {
                    addrStr = substring(ownersStr, lastIndex, i - lastIndex);
                } else {
                    addrStr = substring(ownersStr, lastIndex, i - lastIndex);
                    lastIndex = i + 1;
                }
                owners[ownerIndex] = parseAddr(addrStr);
                ownerIndex++;
            }
        }
        
        return owners;
    }
    
    // 辅助函数：获取子字符串
    function substring(string memory str, uint startIndex, uint length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(length);
        for (uint i = 0; i < length; i++) {
            result[i] = strBytes[startIndex + i];
        }
        return string(result);
    }
    
    // 辅助函数：将字符串解析为地址
    function parseAddr(string memory _a) internal pure returns (address) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("Deploying MultSign contract from address:", deployer);
        
        address[] memory owners = getOwnersFromEnv();
        console.log("Number of owners:", owners.length);
        for (uint i = 0; i < owners.length; i++) {
            console.log("Owner", i, ":", owners[i]);
        }
        
        uint256 confirmations = vm.envUint("REQUIRED_CONFIRMATIONS");
        console.log("Required confirmations:", confirmations);
        
        vm.startBroadcast(privateKey);
        
        multSign = new MultSign(owners, confirmations);
        console.log("MultSign deployed at:", address(multSign));
        
        vm.stopBroadcast();
    }
} 