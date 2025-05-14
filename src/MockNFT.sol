// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockNFT is ERC721Enumerable, Ownable {

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId) public returns (uint256) {
        _mint(to, tokenId);
        return tokenId;
    }
}