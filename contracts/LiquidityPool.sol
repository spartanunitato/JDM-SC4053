// contracts/LiquidityPool.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./LiquidityProvider.sol";

contract LiquidityPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;
    LiquidityProvider public lpToken;

    uint256 private reserveA;
    uint256 private reserveB;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    uint256 public totalVolumeTraded; // Track total trade volume in the pool

    event LiquidityAdded(address indexed provider, uint256 amountTokenA, uint256 amountTokenB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountTokenA, uint256 amountTokenB, uint256 liquidityBurned);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event VolumeUpdated(uint256 newVolume);

    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != _tokenB, "Identical token addresses");
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address token");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        // Deploy LiquidityProvider with LiquidityPool as the owner and liquidityPool address
        lpToken = new LiquidityProvider("LP Token", "LPT", address(this));
        totalVolumeTraded = 0; // Initialize total volume to 0
    }

    // Function to update volume after each trade
    function updateVolume(uint256 tradeAmount) external {
        totalVolumeTraded += tradeAmount;
        emit VolumeUpdated(totalVolumeTraded);
    }

    // Function to get the total volume traded in the pool
    function getTotalVolume() external view returns (uint256) {
        return totalVolumeTraded;
    }

    function addLiquidity(uint256 amountADesired, uint256 amountBDesired) external nonReentrant returns (uint256 liquidity) {
        require(amountADesired > 0 && amountBDesired > 0, "Invalid token amounts");

        // Transfer tokens from user to the pool
        uint256 balanceABefore = tokenA.balanceOf(address(this));
        tokenA.safeTransferFrom(msg.sender, address(this), amountADesired);
        uint256 amountA = tokenA.balanceOf(address(this)) - balanceABefore;

        uint256 balanceBBefore = tokenB.balanceOf(address(this));
        tokenB.safeTransferFrom(msg.sender, address(this), amountBDesired);
        uint256 amountB = tokenB.balanceOf(address(this)) - balanceBBefore;

        // Calculate liquidity to mint
        if (lpToken.totalSupply() == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * lpToken.totalSupply()) / reserveA,
                (amountB * lpToken.totalSupply()) / reserveB
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        // Update reserves
        reserveA += amountA;
        reserveB += amountB;

        // Mint LP tokens to the provider
        lpToken.mintLiquidityTokens(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Invalid liquidity amount");

        uint256 totalSupply = lpToken.totalSupply();

        // Calculate amounts to return
        amountA = (reserveA * liquidity) / totalSupply;
        amountB = (reserveB * liquidity) / totalSupply;

        require(amountA > 0 && amountB > 0, "Insufficient amounts");

        // Burn LP tokens from the provider
        lpToken.burnLiquidityTokens(msg.sender, liquidity);

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfer tokens back to the user
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid tokenIn");
        require(amountIn > 0, "AmountIn must be greater than zero");

        IERC20 inputToken = IERC20(tokenIn);
        IERC20 outputToken = tokenIn == address(tokenA) ? tokenB : tokenA;

        // Transfer input tokens from the user
        uint256 balanceBefore = inputToken.balanceOf(address(this));
        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 actualAmountIn = inputToken.balanceOf(address(this)) - balanceBefore;

        // Update reserves
        if (tokenIn == address(tokenA)) {
            reserveA += actualAmountIn;
        } else {
            reserveB += actualAmountIn;
        }

        // Calculate output amount using the constant product formula
        uint256 inputReserve = tokenIn == address(tokenA) ? reserveA - actualAmountIn : reserveB - actualAmountIn;
        uint256 outputReserve = tokenIn == address(tokenA) ? reserveB : reserveA;

        uint256 amountInWithFee = actualAmountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * outputReserve;
        uint256 denominator = (inputReserve * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // Update reserves
        if (tokenIn == address(tokenA)) {
            reserveB -= amountOut;
        } else {
            reserveA -= amountOut;
        }

        // Transfer output tokens to the user
        outputToken.safeTransfer(msg.sender, amountOut);

        // Update the total volume traded with the actual amount input by the user
        this.updateVolume(actualAmountIn);

        emit TokensSwapped(msg.sender, tokenIn, address(outputToken), actualAmountIn, amountOut);
    }

    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    // Helper functions
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
}
