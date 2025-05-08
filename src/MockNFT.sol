// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockNFT is ERC721, Ownable {

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId) public onlyOwner returns (uint256) {
        _mint(to, tokenId);
        return tokenId;
    }
}