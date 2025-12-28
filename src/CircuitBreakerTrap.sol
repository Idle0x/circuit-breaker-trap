// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
}

contract CircuitBreakerTrap is ITrap {
    // --- Mainnet Addresses ---
    AggregatorV3Interface public constant PRICE_FEED_ETH = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    AggregatorV3Interface public constant PRICE_FEED_USDC = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    IUniswapV3Pool public constant POOL_USDC_ETH = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    // --- Thresholds ---
    int256 public constant USDC_DEPEG_LIMIT = 99000000; // $0.99
    uint256 public constant ETH_VOLATILITY_THRESHOLD = 5; // 5% change
    uint256 public constant LIQUIDITY_DROP_THRESHOLD = 10; // 10% drop
    uint256 public constant ORACLE_TIMEOUT = 3600; // 1 hour staleness check

    function collect() external view returns (bytes memory) {
        // 1. Get ETH Price with Sanity Check
        (uint80 rIdEth, int256 ethPrice, , uint256 updateEth, ) = PRICE_FEED_ETH.latestRoundData();
        
        // 2. Get USDC Price with Sanity Check
        (uint80 rIdUsdc, int256 usdcPrice, , uint256 updateUsdc, ) = PRICE_FEED_USDC.latestRoundData();

        // 3. Get Liquidity
        uint128 poolLiquidity = POOL_USDC_ETH.liquidity();

        // 4. Validate Data Freshness (prevent stale oracle triggers)
        // If data is stale or invalid, we return empty bytes to be ignored
        if (ethPrice <= 0 || usdcPrice <= 0 || 
            block.timestamp - updateEth > ORACLE_TIMEOUT || 
            block.timestamp - updateUsdc > ORACLE_TIMEOUT) {
            return bytes(""); 
        }

        return abi.encode(ethPrice, usdcPrice, poolLiquidity);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        // FIX: Planner Safety - Ensure we have 2 blocks of data to compare
        if (data.length < 2 || data[0].length == 0 || data[1].length == 0) {
            return (false, bytes(""));
        }

        // Decode Current Block (Newest)
        (int256 currEth, int256 currUsdc, uint128 currLiq) = 
            abi.decode(data[0], (int256, int256, uint128));

        // Decode Previous Block (Oldest)
        (int256 prevEth, , uint128 prevLiq) = 
            abi.decode(data[1], (int256, int256, uint128));

        // CHECK 1: ETH Volatility (Absolute deviation > 5%)
        // Logic: |curr - prev| * 100 / prev > 5
        int256 ethDiff = currEth > prevEth ? currEth - prevEth : prevEth - currEth;
        bool isVolatile = (ethDiff * 100 / prevEth) > int256(ETH_VOLATILITY_THRESHOLD);

        // CHECK 2: USDC Depeg (Absolute check)
        bool isDepeg = currUsdc < USDC_DEPEG_LIMIT;

        // CHECK 3: Liquidity Drop (> 10% drop from previous block)
        // Logic: (prev - curr) * 100 / prev > 10
        bool isLiquidityDrain = false;
        if (prevLiq > 0 && currLiq < prevLiq) {
             uint256 liqDrop = uint256(prevLiq - currLiq) * 100 / uint256(prevLiq);
             isLiquidityDrain = liqDrop > LIQUIDITY_DROP_THRESHOLD;
        }

        if (isVolatile || isDepeg || isLiquidityDrain) {
            // Return TRUE and pass the CURRENT data payload to the responder
            return (true, data[0]);
        }

        return (false, bytes(""));
    }
}
