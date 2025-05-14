// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyEIP2612 is ERC20, ERC20Permit, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(initialOwner) {
        // 初始铸造 1000000 个代币给部署者
        _mint(initialOwner, 1000000 * 10 ** decimals());
    }

    /**
     * @dev 铸造新代币
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev 使用签名进行无 gas 转账
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 转账金额
     * @param deadline 签名过期时间
     * @param v 签名参数 v
     * @param r 签名参数 r
     * @param s 签名参数 s
     */
    function permitTransfer(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // 使用 ERC20Permit 的 permit 函数进行授权
        permit(owner, spender, value, deadline, v, r, s);
        // 执行转账
        transferFrom(owner, spender, value);
    }
}
