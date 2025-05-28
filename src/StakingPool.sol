// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./KKToken.sol";

/**
 * @title KK Token 
 */
interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title Staking Interface
 */
interface IStaking {
    /**
     * @dev 质押 ETH 到合约
     */
    function stake() payable external;

    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external; 

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external;

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256);
}

/**
 * @title StakingPool
 * @dev 质押池合约，允许用户质押 ETH 赚取 KK Token
 */
contract StakingPool is IStaking, Ownable, ReentrancyGuard {
    KKToken public immutable kkToken;
    
    // 每个区块产出的 KK Token 数量
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18; // 10 KK tokens
    
    // 总质押量
    uint256 public totalStaked;
    
    // 上次更新奖励的区块号
    uint256 public lastUpdateBlock;
    
    // 每单位质押的累积奖励
    uint256 public rewardPerTokenStored;
    
    // 用户信息
    struct UserInfo {
        uint256 stakedAmount;           // 质押数量
        uint256 userRewardPerTokenPaid; // 用户已支付的每单位奖励
        uint256 rewards;                // 待领取的奖励
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // 事件
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    constructor() Ownable(msg.sender) {
        kkToken = new KKToken();
        lastUpdateBlock = block.number;
    }
    
    /**
     * @dev 更新奖励
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        
        if (account != address(0)) {
            userInfo[account].rewards = earned(account);
            userInfo[account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }
    
    /**
     * @dev 计算每单位质押的奖励
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        
        uint256 blocksPassed = block.number - lastUpdateBlock;
        uint256 totalReward = blocksPassed * REWARD_PER_BLOCK;
        
        return rewardPerTokenStored + (totalReward * 1e18) / totalStaked;
    }
    
    /**
     * @dev 计算用户待领取的奖励
     */
    function earned(address account) public view returns (uint256) {
        UserInfo memory user = userInfo[account];
        return (user.stakedAmount * (rewardPerToken() - user.userRewardPerTokenPaid)) / 1e18 + user.rewards;
    }
    
    /**
     * @dev 质押 ETH
     */
    function stake() external payable updateReward(msg.sender) nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        userInfo[msg.sender].stakedAmount += msg.value;
        totalStaked += msg.value;
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev 赎回质押的 ETH
     */
    function unstake(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(userInfo[msg.sender].stakedAmount >= amount, "Insufficient staked amount");
        
        userInfo[msg.sender].stakedAmount -= amount;
        totalStaked -= amount;
        
        // 转账 ETH 给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取奖励
     */
    function claim() external updateReward(msg.sender) nonReentrant {
        uint256 reward = userInfo[msg.sender].rewards;
        require(reward > 0, "No rewards to claim");
        
        userInfo[msg.sender].rewards = 0;
        kkToken.mint(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    /**
     * @dev 获取用户质押数量
     */
    function balanceOf(address account) external view returns (uint256) {
        return userInfo[account].stakedAmount;
    }
    
    /**
     * @dev 紧急提取（仅限 owner）
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Emergency withdraw failed");
    }
    
    /**
     * @dev 获取合约 ETH 余额
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取总质押量
     */
    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }
    
    /**
     * @dev 获取当前区块号
     */
    function getCurrentBlock() external view returns (uint256) {
        return block.number;
    }
}

