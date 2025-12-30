# Circuit Breaker Trap ⚡

**Status:** Experimental / Research 🧪  
**Network:** Ethereum Mainnet  
**Focus:** DeFi Volatility & Depeg Protection

## Overview
The **Circuit Breaker** is an advanced multi-vector monitoring trap designed for the Drosera Network. It aggregates data from multiple on-chain sources (Chainlink Oracles and Uniswap V3 Pools) to provide a holistic "Health Score" for DeFi protocols.

Unlike simple monitors that check one metric, the Circuit Breaker correlates price volatility, stablecoin de-pegging, and liquidity crunches into a single binary trigger.

## Detection Vectors
This trap monitors three distinct market failures simultaneously:
1.  **Asset Volatility:** Triggers if ETH price moves > 10% in a single update.
2.  **Stablecoin Depeg:** Triggers if USDC price drops below $0.98.
3.  **Liquidity Crisis:** Triggers if Uniswap V3 pool liquidity drops > 15% instantly.

## Operational Logic
* **Oracles:** Chainlink `ETH/USD` and `USDC/USD`.
* **DEX:** Uniswap V3 `ETH/USDC` Pool.
* **Mechanism:** * Fetches `latestRoundData` from Chainlink.
    * Fetches `liquidity()` from Uniswap.
    * Compares current block data vs. historical data to calculate deltas.

## Development Note
This trap represents an optimized "Lite" implementation of multi-vector monitoring. It demonstrates the logic required to bundle complex oracle dependencies into a single Drosera Trap.

## Directory Structure
* `src/CircuitBreakerTrap.sol`: Main logic containing the multi-vector checks.
