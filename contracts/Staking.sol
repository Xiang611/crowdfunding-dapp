// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";

contract Staking {
    Token public token;
    address public owner;

    struct StakeInfo {
        uint amount;
        uint since;
    }

    mapping(address => StakeInfo) public stakes;

    uint public rewardRatePerDay = 1; // 1 CTK per 10 CTK staked per day

    event Staked(address indexed user, uint amount);
    event Unstaked(address indexed user, uint amount, uint reward);

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
        owner = msg.sender;
    }

    // ── Step 1: User calls approve() on Token first, then calls this
    function stake(uint amount) public {
        require(amount > 0, "Amount must be > 0");
        require(
            token.balanceOf(msg.sender) >= amount,
            "Insufficient CTK balance"
        );

        // If already staking, collect existing reward first
        if (stakes[msg.sender].amount > 0) {
            uint pendingReward = calculateReward(msg.sender);
            if (pendingReward > 0) {
                token.mint(msg.sender, pendingReward);
            }
        }

        token.transferFrom(msg.sender, address(this), amount);

        stakes[msg.sender] = StakeInfo({
            amount: stakes[msg.sender].amount + amount,
            since: block.timestamp
        });

        emit Staked(msg.sender, amount);
    }

    // ── Calculate reward: 1 CTK per 10 CTK staked per day
    function calculateReward(address user) public view returns (uint) {
        StakeInfo memory s = stakes[user];
        if (s.amount == 0) return 0;

        uint secondsStaked = block.timestamp - s.since;
        uint daysStaked = secondsStaked / 1 days;

        // reward = (amount / 10) * rewardRatePerDay * daysStaked
        uint reward = (s.amount / (10 * 1e18)) *
            rewardRatePerDay *
            daysStaked *
            1e18;
        return reward;
    }

    // ── Unstake everything + collect rewards
    function unstake() public {
        StakeInfo memory s = stakes[msg.sender];
        require(s.amount > 0, "Nothing staked");

        // ✅ Add this lock check
        require(
            block.timestamp >= s.since + 7 days,
            "Tokens locked for 7 days"
        );

        uint reward = calculateReward(msg.sender);
        delete stakes[msg.sender];

        if (reward > 0) {
            token.mint(msg.sender, reward);
        }

        token.transfer(msg.sender, s.amount);
        emit Unstaked(msg.sender, s.amount, reward);
    }

    // ── View stake details
    function getStake(
        address user
    ) public view returns (uint amount, uint since, uint pendingReward) {
        StakeInfo memory s = stakes[user];
        return (s.amount, s.since, calculateReward(user));
    }

    // ── Check if user is currently staking
    function isStaking(address user) public view returns (bool) {
        return stakes[user].amount > 0;
    }

    // ── Owner can update reward rate
    function setRewardRate(uint newRate) public {
        require(msg.sender == owner, "Only owner");
        rewardRatePerDay = newRate;
    }

    function timeUntilUnlock(address user) public view returns (uint) {
        StakeInfo memory s = stakes[user];
        if (s.amount == 0) return 0;
        uint unlockTime = s.since + 7 days;
        if (block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp; // returns seconds remaining
    }
}
