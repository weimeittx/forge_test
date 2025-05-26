// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @dev 代币归属合约，实现12个月cliff期和24个月线性释放
 * 
 * 归属计划：
 * - Cliff期：12个月（前12个月无法释放任何代币）
 * - 线性释放期：24个月（从第13个月开始，每月释放1/24的代币）
 * - 总归属期：36个月
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 事件
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingCreated(
        address indexed beneficiary,
        address indexed token,
        uint256 amount,
        uint256 startTime
    );

    // 归属信息结构体
    struct VestingSchedule {
        address beneficiary;        // 受益人地址
        address token;             // ERC20代币地址
        uint256 totalAmount;       // 总归属金额
        uint256 releasedAmount;    // 已释放金额
        uint256 startTime;         // 归属开始时间
        bool revoked;              // 是否已撤销
    }

    // 常量
    uint256 public constant CLIFF_DURATION = 365 days;      // 12个月cliff期
    uint256 public constant VESTING_DURATION = 730 days;    // 24个月线性释放期
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 总归属期36个月
    uint256 public constant VESTING_MONTHS = 24;            // 线性释放月数

    // 状态变量
    mapping(address => VestingSchedule) public vestingSchedules;
    address[] public beneficiaries;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev 创建归属计划
     * @param _beneficiary 受益人地址
     * @param _token ERC20代币地址
     * @param _amount 归属代币总量
     */
    function createVestingSchedule(
        address _beneficiary,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_token != address(0), "Token cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(vestingSchedules[_beneficiary].totalAmount == 0, "Vesting schedule already exists");

        // 转入代币到合约
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // 创建归属计划
        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            token: _token,
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            revoked: false
        });

        beneficiaries.push(_beneficiary);

        emit VestingCreated(_beneficiary, _token, _amount, block.timestamp);
    }

    /**
     * @dev 释放当前可释放的代币给受益人
     */
    function release() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        IERC20(schedule.token).safeTransfer(schedule.beneficiary, releasableAmount);

        emit TokensReleased(schedule.beneficiary, releasableAmount);
    }

    /**
     * @dev 计算当前可释放的代币数量
     * @param _beneficiary 受益人地址
     * @return amount 可释放的代币数量
     */
    function getReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        uint256 vestedAmount = getVestedAmount(_beneficiary);
        return vestedAmount - schedule.releasedAmount;
    }

    /**
     * @dev 计算已归属的代币数量
     * @param _beneficiary 受益人地址
     * @return amount 已归属的代币数量
     */
    function getVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;

        // 如果还在cliff期内，返回0
        if (elapsedTime < CLIFF_DURATION) {
            return 0;
        }

        // 如果超过总归属期，返回全部金额
        if (elapsedTime >= TOTAL_DURATION) {
            return schedule.totalAmount;
        }

        // 计算线性释放期内的归属金额
        uint256 vestingElapsed = elapsedTime - CLIFF_DURATION;
        uint256 vestedAmount = (schedule.totalAmount * vestingElapsed) / VESTING_DURATION;
        
        return vestedAmount;
    }

    /**
     * @dev 获取归属计划信息
     * @param _beneficiary 受益人地址
     * @return beneficiary 受益人地址
     * @return token 代币地址
     * @return totalAmount 总归属金额
     * @return releasedAmount 已释放金额
     * @return startTime 归属开始时间
     * @return revoked 是否已撤销
     */
    function getVestingSchedule(address _beneficiary) 
        external 
        view 
        returns (
            address beneficiary,
            address token,
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            bool revoked
        ) 
    {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        return (
            schedule.beneficiary,
            schedule.token,
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.revoked
        );
    }

    /**
     * @dev 获取剩余可归属的代币数量
     * @param _beneficiary 受益人地址
     * @return amount 剩余可归属的代币数量
     */
    function getRemainingAmount(address _beneficiary) external view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        return schedule.totalAmount - schedule.releasedAmount;
    }

    /**
     * @dev 获取距离下次释放的时间
     * @param _beneficiary 受益人地址
     * @return timeInSeconds 距离下次释放的秒数
     */
    function getTimeToNextRelease(address _beneficiary) external view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        
        // 如果还在cliff期内
        if (elapsedTime < CLIFF_DURATION) {
            return CLIFF_DURATION - elapsedTime;
        }

        // 如果已经完全归属
        if (elapsedTime >= TOTAL_DURATION) {
            return 0;
        }

        // 计算到下个月的时间（简化为30天一个月）
        uint256 vestingElapsed = elapsedTime - CLIFF_DURATION;
        uint256 monthsPassed = vestingElapsed / 30 days;
        uint256 nextMonthStart = (monthsPassed + 1) * 30 days;
        
        if (nextMonthStart > VESTING_DURATION) {
            return 0;
        }

        return (CLIFF_DURATION + nextMonthStart) - (schedule.startTime + elapsedTime);
    }

    /**
     * @dev 撤销归属计划（仅限所有者）
     * @param _beneficiary 受益人地址
     */
    function revokeVesting(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting schedule already revoked");

        // 先释放已归属的代币
        uint256 releasableAmount = getReleasableAmount(_beneficiary);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            IERC20(schedule.token).safeTransfer(schedule.beneficiary, releasableAmount);
            emit TokensReleased(schedule.beneficiary, releasableAmount);
        }

        // 标记为已撤销
        schedule.revoked = true;

        // 将剩余代币返还给所有者
        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            IERC20(schedule.token).safeTransfer(owner(), remainingAmount);
        }
    }

    /**
     * @dev 获取所有受益人列表
     * @return addresses 受益人地址数组
     */
    function getBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }

    /**
     * @dev 紧急提取代币（仅限所有者）
     * @param _token 代币地址
     * @param _amount 提取数量
     */
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }
} 