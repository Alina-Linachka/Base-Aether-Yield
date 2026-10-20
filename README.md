# Base Aether Yield Pool

A high-efficiency decentralized yield farming and staking protocol built on the Base L2 network. Aether Yield Pool allows liquidity providers to lock their assets in secure vaults to generate continuous, block-by-block reward distributions.

## Core Features
* **Dynamic APY Calculation:** Reward rates dynamically adjust based on total pool liquidity and specific asset utilization curves.
* **Auto-Compounding Architecture:** Designed to seamlessly integrate with external compounder bots, minimizing gas costs for individual stakers while maximizing yield.
* **Time-Weighted Rewards:** Implements strict timestamp differentials to calculate precise staking durations and prevent flash-loan reward manipulation.

## Security & Mechanics
Developed with Solidity `0.8.37`. The protocol heavily utilizes the Checks-Effects-Interactions pattern for all withdrawal and harvest functions to eliminate reentrancy risks. Total locked value (TVL) metrics are isolated in state variables to ensure constant O(1) read complexity.
