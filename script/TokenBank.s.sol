// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract TokenBankScript is Script {
    TokenBank public tokenBank;

    // 通过环境变量获取一些初始支持的代币地址
    function getSupportedTokensFromEnv() internal view returns (address[] memory) {
        string memory supportedTokensStr = vm.envOr("SUPPORTED_TOKENS", string(""));
        
        // 分析环境变量中的代币地址列表
        bytes memory supportedTokensBytes = bytes(supportedTokensStr);
        if (supportedTokensBytes.length == 0) {
            address[] memory emptyList = new address[](0);
            return emptyList;
        }

        // 计算地址数量 (每个地址长度为42字符，包括0x前缀，逗号分隔)
        uint256 numAddresses = 1;
        for (uint256 i = 0; i < supportedTokensBytes.length; i++) {
            if (supportedTokensBytes[i] == ',') {
                numAddresses++;
            }
        }

        address[] memory tokenAddresses = new address[](numAddresses);
        
        // 解析地址字符串
        uint256 startIdx = 0;
        uint256 addrIdx = 0;
        
        for (uint256 i = 0; i <= supportedTokensBytes.length; i++) {
            if (i == supportedTokensBytes.length || supportedTokensBytes[i] == ',') {
                string memory addrStr = substring(supportedTokensStr, startIdx, i - startIdx);
                tokenAddresses[addrIdx] = parseAddr(addrStr);
                startIdx = i + 1;
                addrIdx++;
            }
        }
        
        return tokenAddresses;
    }
    
    // 辅助函数：提取子字符串
    function substring(string memory str, uint256 startIndex, uint256 length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = strBytes[startIndex + i];
        }
        return string(result);
    }
    
    // 辅助函数：解析地址字符串
    function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        
        for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) b1 -= 87;
            else if ((b1 >= 65) && (b1 <= 70)) b1 -= 55;
            else if ((b1 >= 48) && (b1 <= 57)) b1 -= 48;
            if ((b2 >= 97) && (b2 <= 102)) b2 -= 87;
            else if ((b2 >= 65) && (b2 <= 70)) b2 -= 55;
            else if ((b2 >= 48) && (b2 <= 57)) b2 -= 48;
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 创建并部署TokenBank合约
        tokenBank = new TokenBank();
        
        // 添加初始支持的代币
        // address[] memory supportedTokens = getSupportedTokensFromEnv();
        // for (uint256 i = 0; i < supportedTokens.length; i++) {
        //     if (supportedTokens[i] != address(0)) {
        //         tokenBank.addSupportedToken(supportedTokens[i]);
        //         console.log("Added supported token: %s", supportedTokens[i]);
        //     }
        // }
        
        vm.stopBroadcast();
        
        console.log("TokenBank deployed at: %s", address(tokenBank));
    }
} 