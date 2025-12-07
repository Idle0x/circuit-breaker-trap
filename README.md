# Circuit Breaker Trap (Ethereum Mainnet)

A high-performance "Solvency & Security" trap designed for the Drosera Network on Ethereum Mainnet. This trap implements a **Triple-Vector Detection System** to protect protocols against catastrophic market events.

## Detection Logic

The trap monitors three critical DeFi vectors simultaneously in every block:

1.  **Market Volatility (ETH/USD):**
    * **Source:** Chainlink Oracle.
    * **Trigger:** Detects >5% instant price deviation between Oracle rounds (Flash Crash detection).

2.  **Stablecoin Stability (USDC/USD):**
    * **Source:** Chainlink Oracle.
    * **Trigger:** Detects if USDC depegs below $0.99. This protects against systemic stablecoin failure.

3.  **Liquidity Depth (Uniswap V3):**
    * **Source:** Uniswap V3 USDC/WETH Pool.
    * **Trigger:** Detects sudden liquidity drains (>10% drop), signaling potential whale exits or rug pulls.

## Response Mechanism

**Function:** `breakCircuit(bytes[] calldata data)`

When any of the three vectors are triggered, the trap calls the response contract to emit a permanent on-chain alert (`CircuitBreakerTriggered`). In a production environment, this function would be connected to a protocol's `pause()` or `emergencyShutdown()` module.

## Technical Details

* **Network:** Ethereum Mainnet
* **Oracles:** Chainlink (ETH/USD, USDC/USD)
* **Integration:** Uniswap V3 Core
* **Dependencies:** Drosera Network ITrap Interface
