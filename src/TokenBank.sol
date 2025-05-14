// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// 导入Permit2接口
interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }
    
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }
    
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

/**
 * @title TokenBank
 * @dev ERC20 token bank contract with deposit and withdrawal functions
 */
contract TokenBank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Canonical Permit2 contract address
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    // Supported token addresses
    mapping(address => bool) public supportedTokens;
    
    // User balances: user address => token address => balance
    mapping(address => mapping(address => uint256)) public balances;
    
    // User deposit event
    event Deposit(address indexed user, address indexed token, uint256 amount);
    
    // User withdrawal event
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    
    // Token added event
    event TokenAdded(address indexed token);
    
    // Token removed event
    event TokenRemoved(address indexed token);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Add supported token
     * @param token Token contract address
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Zero address not allowed");
        require(!supportedTokens[token], "Token already supported");
        
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }
    
    /**
     * @dev Remove supported token
     * @param token Token contract address
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }
    
    /**
     * @dev Deposit function
     * @param token Token contract address
     * @param amount Deposit amount
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update balance
        balances[msg.sender][token] += amount;
        
        emit Deposit(msg.sender, token, amount);
    }
    
    /**
     * @dev Deposit with Permit2 signature authorization
     * @param token Token contract address
     * @param amount Deposit amount
     * @param nonce Unique nonce for the signature
     * @param deadline Expiration timestamp for the signature
     * @param signature Signature authorizing the transfer
     */
    function depositWithPermit2(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        // Create the permit data structure
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: token,
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });
        
        // Create the transfer details
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });
        
        // Call Permit2 to transfer tokens using signature
        IPermit2(PERMIT2).permitTransferFrom(
            permit,
            transferDetails,
            msg.sender, // owner
            signature
        );
        
        // Update balance
        balances[msg.sender][token] += amount;
        
        emit Deposit(msg.sender, token, amount);
    }
    
    /**
     * @dev Withdraw function
     * @param token Token contract address
     * @param amount Withdrawal amount
     */
    function withdraw(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender][token] >= amount, "Insufficient balance");
        
        // Update balance
        balances[msg.sender][token] -= amount;
        
        // Transfer tokens to user
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, token, amount);
    }
    
    /**
     * @dev Query user balance
     * @param user User address
     * @param token Token contract address
     * @return User token balance
     */
    function balanceOf(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
    
    /**
     * @dev Emergency withdrawal - only contract owner can call
     * @param token Token contract address
     * @param amount Withdrawal amount
     * @param to Recipient address
     */
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Recipient cannot be zero address");
        
        // Check contract balance
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient contract balance");
        
        // Transfer tokens
        IERC20(token).safeTransfer(to, amount);
    }
}
