// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MultSign
 * @dev 简单的多签钱包合约，允许多个所有者共同管理资金
 */
contract MultSign {
    // 事件定义
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    // 交易结构体
    struct Transaction {
        address to; // 目标地址
        uint value; // 发送的ETH数量
        bytes data; // 调用数据
        bool executed; // 是否已执行
        uint numConfirmations; // 已确认数量
    }

    // 多签持有人地址列表
    address[] public owners;
    // 检查地址是否为多签持有人
    mapping(address => bool) public isOwner;
    // 确认需要的签名数量
    uint public numConfirmationsRequired;

    // 保存所有交易
    Transaction[] public transactions;
    // 交易确认记录：txIndex => owner => confirmed
    mapping(uint => mapping(address => bool)) public isConfirmed;

    // 修饰器：仅多签持有人可调用
    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultSign: not Owner");
        _;
    }

    // 修饰器：检查交易存在
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "MultSign: tx not exist");
        _;
    }

    // 修饰器：检查交易未执行
    modifier notExecuted(uint _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "MultSign: The transaction has been executed"
        );
        _;
    }

    // 修饰器：检查交易未被该持有人确认
    modifier notConfirmed(uint _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "MultSign: The transaction has been confirmed"
        );
        _;
    }

    /**
     * @dev 构造函数，创建多签钱包时设置多签持有人和签名门槛
     * @param _owners 多签持有人地址列表
     * @param _numConfirmationsRequired 签名门槛（需要的确认数量）
     */
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(
            _owners.length > 0,
            "MultSign: The holder of the multiple signature cannot be empty"
        );
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "MultSign: The confirmation threshold is invalid"
        );

        // 添加多签持有人
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            // 确保地址有效且不重复
            require(owner != address(0), "MultSign: invalid address");
            require(
                !isOwner[owner],
                "MultSign: Multiple signatories are duplicated"
            );

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @dev 接收ETH
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev 提交交易提案
     * @param _to 目标地址
     * @param _value 发送的ETH数量
     * @param _data 调用数据
     * @return txIndex 提案交易索引
     */
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner returns (uint txIndex) {
        txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * @dev 确认交易提案
     * @param _txIndex 交易索引
     */
    function confirmTransaction(
        uint _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev 执行交易
     * @param _txIndex 交易索引
     */
    function executeTransaction(
        uint _txIndex
    ) public txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "MultSign: Confirm that the quantity is insufficient"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "MultSign: Transaction execution failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev 撤销确认
     * @param _txIndex 交易索引
     */
    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(
            isConfirmed[_txIndex][msg.sender],
            "MultSign: The deal has not been confirmed"
        );

        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @dev 获取多签持有人列表
     * @return 多签持有人地址数组
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev 获取交易数量
     * @return 交易总数
     */
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
