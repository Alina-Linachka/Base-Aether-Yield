// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract AetherYieldPool {
    struct StakePosition {
        uint256 amount;
        uint256 stakeTimestamp;
        uint256 lastRewardClaim;
        uint256 lockedUntil;
        bool exists;
    }

    address payable public immutable poolAdmin;
    string public poolName;
    uint256 public rewardRatePerSecond; // Фиксированная ставка наград
    uint256 public totalPoolStaked;
    uint256 public earlyUnstakePenaltyFee; // Процент штрафа (например, 5 = 5%)
    bool public isEmergencyPaused;

    mapping(address => StakePosition) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 lockDuration);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty);
    event PoolConfigUpdated(string newName, uint256 newRewardRate, uint256 newPenalty);
    event LockExtended(address indexed user, uint256 addedTime);
    event EmergencyStateToggled(bool isPaused);
    event TreasuryFunded(address indexed funder, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == poolAdmin, "AetherPool: Caller is not the admin");
        _;
    }

    modifier whenNotEmergency() {
        require(!isEmergencyPaused, "AetherPool: Protocol is paused");
        _;
    }

    constructor() {
        poolAdmin = payable(msg.sender);
        poolName = "Aether Base Yield Core v1";
        rewardRatePerSecond = 100 gwei; // Базовая ставка начислений
        earlyUnstakePenaltyFee = 5; // 5% штраф за ранний вывод
        isEmergencyPaused = false;
    }

    // 1. Пополнение казны наград пула
    function fundTreasury() external payable onlyAdmin {
        require(msg.value > 0, "AetherPool: Zero deposit rejected");
        emit TreasuryFunded(msg.sender, msg.value);
    }

    // 2. Стейкинг ETH с блокировкой по времени (в секундах)
    function stake(uint256 lockDurationSeconds) external payable whenNotEmergency {
        require(msg.value > 0, "AetherPool: Must stake positive value");

        StakePosition storage pos = stakes[msg.sender];
        uint256 newUnlock = block.timestamp + lockDurationSeconds;

        if (pos.exists) {
            pos.amount += msg.value;
            if (newUnlock > pos.lockedUntil) {
                pos.lockedUntil = newUnlock;
            }
        } else {
            stakes[msg.sender] = StakePosition({
                amount: msg.value,
                stakeTimestamp: block.timestamp,
                lastRewardClaim: block.timestamp,
                lockedUntil: newUnlock,
                exists: true
            });
        }

        totalPoolStaked += msg.value;
        emit Staked(msg.sender, msg.value, lockDurationSeconds);
    }

    // 3. Снятие накопленных наград
    function claimRewards() external whenNotEmergency {
        StakePosition storage pos = stakes[msg.sender];
        require(pos.exists && pos.amount > 0, "AetherPool: No active stake");

        uint256 timePassed = block.timestamp - pos.lastRewardClaim;
        require(timePassed > 0, "AetherPool: No time elapsed");

        uint256 rewards = (timePassed * rewardRatePerSecond * pos.amount) / 1 ether;
        pos.lastRewardClaim = block.timestamp;

        if (rewards > address(this).balance - totalPoolStaked) {
            rewards = address(this).balance - totalPoolStaked; // Лимит по казне
        }

        if (rewards > 0) {
            (bool sent, ) = payable(msg.sender).call{value: rewards}("");
            require(sent, "AetherPool: Reward transfer failed");
        }

        emit RewardsClaimed(msg.sender, rewards);
    }

    // 4. Продление времени блокировки
    function extendLock(uint256 extraSeconds) external whenNotEmergency {
        StakePosition storage pos = stakes[msg.sender];
        require(pos.exists && pos.amount > 0, "AetherPool: Position not found");
        require(extraSeconds > 0, "AetherPool: Invalid time");

        pos.lockedUntil += extraSeconds;
        emit LockExtended(msg.sender, extraSeconds);
    }

    // 5. Вывод депозита (с учетом штрафа, если таймер не истек)
    function withdrawStake(uint256 withdrawAmount) external {
        StakePosition storage pos = stakes[msg.sender];
        require(pos.exists && pos.amount >= withdrawAmount, "AetherPool: Invalid withdraw amount");

        uint256 penalty = 0;
        if (block.timestamp < pos.lockedUntil) {
            penalty = (withdrawAmount * earlyUnstakePenaltyFee) / 100;
        }

        uint256 payout = withdrawAmount - penalty;
        pos.amount -= withdrawAmount;
        totalPoolStaked -= withdrawAmount;

        (bool sent, ) = payable(msg.sender).call{value: payout}("");
        require(sent, "AetherPool: Payout failed");

        emit Withdrawn(msg.sender, payout, penalty);
    }

    // 6. Обновление параметров пула
    function updatePoolSettings(string calldata newName, uint256 newRate, uint256 newPenalty) external onlyAdmin {
        require(newPenalty <= 20, "AetherPool: Penalty too high");
        poolName = newName;
        rewardRatePerSecond = newRate;
        earlyUnstakePenaltyFee = newPenalty;

        emit PoolConfigUpdated(newName, newRate, newPenalty);
    }

    // 7. Аварийный стоп-кран (Pause/Unpause)
    function setEmergencyPause(bool paused) external onlyAdmin {
        isEmergencyPaused = paused;
        emit EmergencyStateToggled(paused);
    }

    // Просмотр статуса стейка
    function getStakeInfo(address user) external view returns (
        uint256 amount,
        uint256 lockedUntil,
        bool isLocked,
        uint256 pendingRewards
    ) {
        StakePosition memory pos = stakes[user];
        if (!pos.exists) return (0, 0, false, 0);

        uint256 timePassed = block.timestamp - pos.lastRewardClaim;
        uint256 rewards = (timePassed * rewardRatePerSecond * pos.amount) / 1 ether;
        bool locked = block.timestamp < pos.lockedUntil;

        return (pos.amount, pos.lockedUntil, locked, rewards);
    }
}