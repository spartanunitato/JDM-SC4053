// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import IERC20 interface
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityPool is Ownable {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityProviderBalances;

    uint256 public constant FEE_RATE = 3; // 0.3% fee

    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // Add liquidity to the pool
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 liquidityMinted = amountA + amountB;
        liquidityProviderBalances[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        reserveA += amountA;
        reserveB += amountB;
    }

    // Remove liquidity from the pool
    function removeLiquidity(uint256 liquidityAmount) external {
        require(liquidityProviderBalances[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        uint256 amountA = (liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (liquidityAmount * reserveB) / totalLiquidity;

        liquidityProviderBalances[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
    }

    // Swap tokens using the pool
    function swap(address fromToken, uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(fromToken == address(tokenA) || fromToken == address(tokenB), "Invalid token");

        bool isFromTokenA = fromToken == address(tokenA);

        IERC20 inputToken = isFromTokenA ? tokenA : tokenB;
        IERC20 outputToken = isFromTokenA ? tokenB : tokenA;

        uint256 inputReserve = isFromTokenA ? reserveA : reserveB;
        uint256 outputReserve = isFromTokenA ? reserveB : reserveA;

        // Transfer input tokens from sender
        inputToken.transferFrom(msg.sender, address(this), amountIn);

        // Calculate amount out with fee
        uint256 amountInWithFee = amountIn * (1000 - FEE_RATE);
        amountOut = (amountInWithFee * outputReserve) / (inputReserve * 1000 + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");

        // Update reserves
        if (isFromTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Transfer output tokens to sender
        outputToken.transfer(msg.sender, amountOut);
    }

    // Calculate price ratio
    function getPriceRatio() external view returns (uint256 priceA, uint256 priceB) {
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        priceA = (reserveB * 1e18) / reserveA;
        priceB = (reserveA * 1e18) / reserveB;
    }
}
