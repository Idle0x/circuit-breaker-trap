// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CircuitBreakerResponse {
    event CircuitBreakerTriggered(
        string message, 
        int256 ethPrice,
        int256 usdcPrice, 
        uint128 liquidity
    );

    function breakCircuit(bytes calldata payload) external {
        (int256 ethPrice, int256 usdcPrice, uint128 liquidity) = 
            abi.decode(payload, (int256, int256, uint128));

        emit CircuitBreakerTriggered(
            "CRITICAL: Solvency Event Detected", 
            ethPrice, 
            usdcPrice, 
            liquidity
        );
    }
}
