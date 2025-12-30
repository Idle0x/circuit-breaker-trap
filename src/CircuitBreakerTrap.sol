// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Manual Interfaces to save gas
interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
}

contract CircuitBreakerTrap {
    
    // Hardcoded Addresses (Gas Saving)
    address constant ETH_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant USDC_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    // Thresholds
    int256 constant USDC_DEPEG_LIMIT = 98000000;    
    int256 constant ETH_VOLATILITY_THRESHOLD = 10; 
    uint256 constant LIQUIDITY_DROP_THRESHOLD = 15; 
    uint256 constant ORACLE_TIMEOUT = 3600;         

    function collect() external view returns (bytes memory) {
        (, int256 ethPrice, , uint256 updateEth, ) = AggregatorV3Interface(ETH_FEED).latestRoundData();
        (, int256 usdcPrice, , uint256 updateUsdc, ) = AggregatorV3Interface(USDC_FEED).latestRoundData();
        uint128 poolLiquidity = IUniswapV3Pool(POOL).liquidity();

        if (ethPrice <= 0 || usdcPrice <= 0 || 
            block.timestamp - updateEth > ORACLE_TIMEOUT || 
            block.timestamp - updateUsdc > ORACLE_TIMEOUT) {
            return bytes(""); 
        }

        return abi.encode(ethPrice, usdcPrice, poolLiquidity);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < 2 || data[0].length == 0 || data[1].length == 0) {
            return (false, bytes(""));
        }

        (int256 currEth, int256 currUsdc, uint128 currLiq) = abi.decode(data[0], (int256, int256, uint128));
        (int256 prevEth, , uint128 prevLiq) = abi.decode(data[1], (int256, int256, uint128));

        int256 ethDiff = currEth > prevEth ? currEth - prevEth : prevEth - currEth;
        
        bool isVolatile = (ethDiff * 100 / prevEth) > ETH_VOLATILITY_THRESHOLD;
        bool isDepeg = currUsdc < USDC_DEPEG_LIMIT;
        
        bool isLiquidityDrain = false;
        if (prevLiq > 0 && currLiq < prevLiq) {
             uint256 liqDrop = uint256(prevLiq - currLiq) * 100 / uint256(prevLiq);
             isLiquidityDrain = liqDrop > LIQUIDITY_DROP_THRESHOLD;
        }

        if (isVolatile || isDepeg || isLiquidityDrain) {
            return (true, data[0]);
        }

        return (false, bytes(""));
    }
}
