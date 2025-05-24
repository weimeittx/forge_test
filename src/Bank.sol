// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {AutomationCompatibleInterface} from "@chainlink/contracts@1.4.0/src/v0.8/automation/AutomationCompatible.sol";

contract Bank is AutomationCompatibleInterface {
    address public admin;

    mapping(address => uint256) public balances;
    address[] public depositors;
    
    // 可迭代双向链表用于存储前 10 名存款用户
    uint256 public constant MAX_TOP_USERS = 10;
    uint256 public topUsersCount;
    
    // 链表结构
    struct User {
        address userAddress;
        address prev;
        address next;
    }
    
    // 头部和尾部指针
    address public head;
    address public tail;
    
    // 用户在链表中的信息
    mapping(address => User) public topUsers;
    
    // 用户是否在链表中
    mapping(address => bool) public isInTopList;

    constructor() {
        admin = msg.sender;
        head = address(0);
        tail = address(0);
        topUsersCount = 0;
    }

    
      function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
      upkeepNeeded = address(this).balance > 10 wei;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //TODO 权限问题?
       payable(admin).transfer(address(this).balance);
    }

    receive() external payable effectiveBalance {
        // 更新余额
        if (balances[msg.sender] == 0) {
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        
        // 更新前 10 名用户列表
        _updateTopUsers(msg.sender);
    }

    modifier effectiveBalance() {
        require(msg.value > 1 wei);
        _;
    }

    function deposit() external payable effectiveBalance {
        // 更新余额
        if (balances[msg.sender] == 0) {
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;

        // 更新前 10 名用户列表
        _updateTopUsers(msg.sender);
        
    }

    function withdraw() external {
        require(msg.sender == admin, "Only admin can withdraw");

        payable(admin).transfer(address(this).balance);
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    /**
     * @dev 更新前 10 名用户列表
     * @param depositor 新的存款人
     */
    function _updateTopUsers(address depositor) internal {
        uint256 balance = balances[depositor];
        
        // 如果用户已经在链表中，先从链表中移除
        if (isInTopList[depositor]) {
            _removeFromList(depositor);
        }
        
        // 如果链表为空，直接插入
        if (head == address(0)) {
            _addToEmptyList(depositor);
            return;
        }
        
        // 如果用户余额大于当前最小的前10名用户，或者链表还没满10个
        if (topUsersCount < MAX_TOP_USERS || balance > balances[tail]) {
            // 在链表中找到合适的位置插入
            _insertSorted(depositor);
        }
    }
    
    /**
     * @dev 向空链表中添加用户
     */
    function _addToEmptyList(address user) internal {
        topUsers[user] = User({
            userAddress: user,
            prev: address(0),
            next: address(0)
        });
        
        head = user;
        tail = user;
        isInTopList[user] = true;
        topUsersCount = 1;
    }
    
    /**
     * @dev 从链表中移除用户
     */
    function _removeFromList(address user) internal {
        User memory currentUser = topUsers[user];
        
        // 如果是头部
        if (currentUser.prev == address(0)) {
            head = currentUser.next;
        } else {
            topUsers[currentUser.prev].next = currentUser.next;
        }
        
        // 如果是尾部
        if (currentUser.next == address(0)) {
            tail = currentUser.prev;
        } else {
            topUsers[currentUser.next].prev = currentUser.prev;
        }
        
        // 清除用户在链表中的记录
        delete topUsers[user];
        isInTopList[user] = false;
        topUsersCount--;
    }
    
    /**
     * @dev 按存款余额排序插入用户
     */
    function _insertSorted(address user) internal {
        uint256 balance = balances[user];
        
        // 从头部开始查找合适的位置
        address current = head;
        address previous = address(0);
        
        while (current != address(0) && balances[current] >= balance) {
            previous = current;
            current = topUsers[current].next;
        }
        
        // 插入到找到的位置
        if (previous == address(0)) {
            // 插入到头部
            topUsers[user] = User({
                userAddress: user,
                prev: address(0),
                next: head
            });
            
            if (head != address(0)) {
                topUsers[head].prev = user;
            }
            
            head = user;
            
            if (tail == address(0)) {
                tail = user;
            }
        } else if (current == address(0)) {
            // 插入到尾部
            topUsers[user] = User({
                userAddress: user,
                prev: previous,
                next: address(0)
            });
            
            topUsers[previous].next = user;
            tail = user;
        } else {
            // 插入到中间
            topUsers[user] = User({
                userAddress: user,
                prev: previous,
                next: current
            });
            
            topUsers[previous].next = user;
            topUsers[current].prev = user;
        }
        
        isInTopList[user] = true;
        topUsersCount++;
        
        // 如果超过了最大值，移除尾部元素
        if (topUsersCount > MAX_TOP_USERS) {
            _removeFromList(tail);
        }
    }
    
    /**
     * @dev 获取前N名存款用户
     * @param n 需要获取的用户数量
     * @return 前N名用户地址数组
     */
    function getTopUsers(uint256 n) external view returns (address[] memory) {
        uint256 count = n < topUsersCount ? n : topUsersCount;
        address[] memory result = new address[](count);
        
        address current = head;
        for (uint256 i = 0; i < count; i++) {
            result[i] = current;
            current = topUsers[current].next;
        }
        
        return result;
    }
    
    /**
     * @dev 获取前10名存款用户
     * @return 前10名用户地址数组
     */
    function getTop10() external view returns (address[] memory) {
        return this.getTopUsers(MAX_TOP_USERS);
    }
    
    /**
     * @dev 为了兼容性保留的函数
     * @return 前3名用户地址数组
     */
    function getTop3() external view returns (address[3] memory) {
        address[3] memory result;
        
        address current = head;
        for (uint256 i = 0; i < 3 && i < topUsersCount; i++) {
            result[i] = current;
            if (current != address(0)) {
                current = topUsers[current].next;
            }
        }
        
        return result;
    }
}
