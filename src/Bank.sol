// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

contract Bank {
    address public admin;

    mapping(address => uint256) public balances;
    address[] public depositors;
    address[3] public top3;

    constructor() {
        admin = msg.sender;
    }

    receive() external payable  effectiveBalance{
        // 更新余额
        if (balances[msg.sender] == 0) {
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        // 更新 top3
        _updateTop3(msg.sender);
    }


    modifier effectiveBalance(){
        require(msg.value > 0.001 ether);
        _;
    }

    function withdraw() external {
        require(msg.sender == admin, "Only admin can withdraw");

        payable(admin).transfer(address(this).balance);
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function _updateTop3(address depositor) internal {
        // 如果已经是 top3 中的用户，只需要重新排序
        for (uint i = 0; i < 3; i++) {
            if (top3[i] == depositor) {
                _sortTop3();
                return;
            }
        }

        // 如果新用户的存款比当前 top3 中最小的多，则替换掉
        uint minIndex = 0;
        for (uint i = 1; i < 3; i++) {
            if (balances[top3[i]] < balances[top3[minIndex]]) {
                minIndex = i;
            }
        }

        if (balances[depositor] > balances[top3[minIndex]]) {
            top3[minIndex] = depositor;
            _sortTop3();
        }
    }

    // 冒泡排序 top3（按存款余额降序）
    function _sortTop3() internal {
        for (uint i = 0; i < 2; i++) {
            for (uint j = i + 1; j < 3; j++) {
                if (balances[top3[j]] > balances[top3[i]]) {
                    (top3[i], top3[j]) = (top3[j], top3[i]);
                }
            }
        }
    }

    function getTop3() external view returns (address[3] memory) {
        return top3;
    }
}


contract Admin{
    
}