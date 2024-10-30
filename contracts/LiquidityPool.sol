// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./LiquidityProvider.sol";

contract LiquidityPool is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;
    LiquidityProvider public lpToken;

    uint256 private reserveA;
    uint256 private reserveB;
    uint256 public totalVolume;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, uint256 amountTokenA, uint256 amountTokenB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountTokenA, uint256 amountTokenB, uint256 liquidityBurned);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB, "LiquidityPool: IDENTICAL_ADDRESSES");
        require(_tokenA != address(0) && _tokenB != address(0), "LiquidityPool: ZERO_ADDRESS");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LiquidityProvider("LP Token", "LPT", address(this));
    }

    function addLiquidity(uint256 amountADesired, uint256 amountBDesired) external nonReentrant returns (uint256 liquidity) {
        require(amountADesired > 0 && amountBDesired > 0, "LiquidityPool: INVALID_AMOUNTS");

        uint256 actualAmountA = _transferTokenIn(tokenA, amountADesired);
        uint256 actualAmountB = _transferTokenIn(tokenB, amountBDesired);

        if (lpToken.totalSupply() == 0) {
            liquidity = sqrt(actualAmountA * actualAmountB);
        } else {
            liquidity = min((actualAmountA * lpToken.totalSupply()) / reserveA, (actualAmountB * lpToken.totalSupply()) / reserveB);
        }

        require(liquidity > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_MINTED");

        reserveA += actualAmountA;
        reserveB += actualAmountB;

        lpToken.mintLiquidityTokens(msg.sender, liquidity);
        emit LiquidityAdded(msg.sender, actualAmountA, actualAmountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "LiquidityPool: INVALID_LIQUIDITY_AMOUNT");

        uint256 totalSupply = lpToken.totalSupply();
        amountA = (reserveA * liquidity) / totalSupply;
        amountB = (reserveB * liquidity) / totalSupply;

        require(amountA > 0 && amountB > 0, "LiquidityPool: INSUFFICIENT_AMOUNTS");

        lpToken.burnLiquidityTokens(msg.sender, liquidity);
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "LiquidityPool: INVALID_TOKEN_IN");
        require(amountIn > 0, "LiquidityPool: INVALID_AMOUNT_IN");

        (IERC20 inputToken, IERC20 outputToken, uint256 inputReserve, uint256 outputReserve) = _getSwapTokens(tokenIn);
        uint256 actualAmountIn = _transferTokenIn(inputToken, amountIn);

        if (tokenIn == address(tokenA)) {
            reserveA += actualAmountIn;
        } else {
            reserveB += actualAmountIn;
        }

        uint256 amountInWithFee = actualAmountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * outputReserve;
        uint256 denominator = (inputReserve * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
        require(amountOut >= minAmountOut, "LiquidityPool: INSUFFICIENT_OUTPUT_AMOUNT");

        if (tokenIn == address(tokenA)) {
            reserveB -= amountOut;
        } else {
            reserveA -= amountOut;
        }

        totalVolume += amountOut;
        outputToken.safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, address(outputToken), actualAmountIn, amountOut);
    }

    function getTotalVolume() external view returns (uint256) {
        return totalVolume;
    }

    function updateVolume(uint256 tradeAmount) external onlyOwner {
        totalVolume += tradeAmount;
    }

    function _transferTokenIn(IERC20 token, uint256 amount) internal returns (uint256) {
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        return token.balanceOf(address(this)) - balanceBefore;
    }

    function _getSwapTokens(address tokenIn) internal view returns (IERC20 inputToken, IERC20 outputToken, uint256 inputReserve, uint256 outputReserve) {
        if (tokenIn == address(tokenA)) {
            return (tokenA, tokenB, reserveA, reserveB);
        } else {
            return (tokenB, tokenA, reserveB, reserveA);
        }
    }

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
        return x < y ? x : y;
    }
    // Add this function to LiquidityPool.sol
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }
}
