// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

// --- Minimal Interfaces ---
interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
}

contract CircuitBreakerTrap is ITrap {
    // --- Mainnet Addresses ---
    // Chainlink ETH/USD
    AggregatorV3Interface public constant PRICE_FEED_ETH = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    // Chainlink USDC/USD
    AggregatorV3Interface public constant PRICE_FEED_USDC = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    // Uniswap V3 USDC/WETH (0.05% Fee Tier)
    IUniswapV3Pool public constant POOL_USDC_ETH = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    // --- Thresholds ---
    int256 public constant USDC_DEPEG_LIMIT = 99000000; // $0.99 (Chainlink has 8 decimals)
    uint128 public constant LIQUIDITY_MIN = 10000000000000000000; // Arbitrary low limit for safety

    function collect() external view returns (bytes memory) {
        // 1. Get ETH Price Data (Current and Previous Round for Volatility)
        (uint80 roundId, int256 ethPrice, , , ) = PRICE_FEED_ETH.latestRoundData();
        (, int256 prevEthPrice, , , ) = PRICE_FEED_ETH.getRoundData(roundId - 1);

        // 2. Get USDC Price
        (, int256 usdcPrice, , , ) = PRICE_FEED_USDC.latestRoundData();

        // 3. Get Uniswap Liquidity
        uint128 poolLiquidity = POOL_USDC_ETH.liquidity();

        // Package all data
        return abi.encode(ethPrice, prevEthPrice, usdcPrice, poolLiquidity);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        // Decode the data
        (int256 ethPrice, int256 prevEthPrice, int256 usdcPrice, uint128 poolLiquidity) = abi.decode(data[0], (int256, int256, int256, uint128));

        // CHECK 1: ETH Volatility (> 5% drop instantly)
        // 5% of price
        int256 volatilityThreshold = (prevEthPrice * 5) / 100;
        bool isCrash = ethPrice < (prevEthPrice - volatilityThreshold);

        // CHECK 2: USDC Depeg (Below $0.99)
        bool isDepeg = usdcPrice < USDC_DEPEG_LIMIT;

        // CHECK 3: Liquidity Crisis (Below Minimum)
        bool isDrained = poolLiquidity < LIQUIDITY_MIN;

        // Trigger if ANY condition is true
        if (isCrash || isDepeg || isDrained) {
            return (true, data[0]);
        }

        return (false, "");
    }
}
