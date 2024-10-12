// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin Contracts
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Import the LiquidityProvider contract interface
import "./LiquidityProvider.sol";

/**
 * @title LiquidityPool
 * @dev Manages the addition, swapping, and removal of liquidity based on the AMM model.
 */
contract LiquidityPool is Ownable (msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ERC20 Tokens managed by the pool
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Liquidity Provider (LP) token
    LiquidityProvider public lpToken;

    // Reserves of TokenA and TokenB
    uint256 private reserveA;
    uint256 private reserveB;

    // Constants for fee calculations (e.g., 0.3% fee)
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    // Events
    event LiquidityAdded(
        address indexed provider,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 liquidityMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 liquidityBurned
    );

    event TokensSwapped(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @dev Initializes the contract with two ERC20 tokens and deploys the LP token.
     * @param _tokenA Address of the first ERC20 token.
     * @param _tokenB Address of the second ERC20 token.
     */
    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB, "Identical token addresses");
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address token");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        // Deploy the LP token
        lpToken = new LiquidityProvider("LP Token", "LPT");
        lpToken.transferOwnership(msg.sender);
        lpToken.setLiquidityPool(address(this));
    }

    /**
     * @dev Adds liquidity to the pool by depositing TokenA and TokenB.
     * @param amountTokenA Amount of TokenA to deposit.
     * @param amountTokenB Amount of TokenB to deposit.
     * @return liquidityMinted Amount of LP tokens minted to the provider.
     */
    function addLiquidity(uint256 amountTokenA, uint256 amountTokenB)
        external
        nonReentrant
        returns (uint256 liquidityMinted)
    {
        require(amountTokenA > 0 && amountTokenB > 0, "Invalid token amounts");

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;

        if (_reserveA == 0 && _reserveB == 0) {
            // First liquidity provision, initialize reserves
            liquidityMinted = sqrt(amountTokenA * amountTokenB);
        } else {
            // Ensure the ratio of tokens is maintained
            uint256 optimalB = (amountTokenA * _reserveB) / _reserveA;
            require(amountTokenB >= optimalB, "Insufficient TokenB amount");

            liquidityMinted = (amountTokenA * lpToken.totalSupply()) / _reserveA;
        }

        require(liquidityMinted > 0, "Insufficient liquidity minted");

        // Transfer tokens from the provider to the pool
        tokenA.safeTransferFrom(msg.sender, address(this), amountTokenA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountTokenB);

        // Update reserves
        reserveA += amountTokenA;
        reserveB += amountTokenB;

        // Mint LP tokens to the provider
        lpToken.mintLiquidityTokens(msg.sender, liquidityMinted);

        emit LiquidityAdded(msg.sender, amountTokenA, amountTokenB, liquidityMinted);
    }

    /**
     * @dev Removes liquidity from the pool by burning LP tokens.
     * @param liquidityAmount Amount of LP tokens to burn.
     * @return amountTokenA Amount of TokenA returned to the provider.
     * @return amountTokenB Amount of TokenB returned to the provider.
     */
    function removeLiquidity(uint256 liquidityAmount)
        external
        nonReentrant
        returns (uint256 amountTokenA, uint256 amountTokenB)
    {
        require(liquidityAmount > 0, "Invalid liquidity amount");

        uint256 totalLiquidity = lpToken.totalSupply();
        require(totalLiquidity > 0, "No liquidity available");

        // Calculate amounts to return
        amountTokenA = (liquidityAmount * reserveA) / totalLiquidity;
        amountTokenB = (liquidityAmount * reserveB) / totalLiquidity;

        require(amountTokenA > 0 && amountTokenB > 0, "Insufficient liquidity burned");

        // Burn LP tokens from the provider
        lpToken.burnLiquidityTokens(msg.sender, liquidityAmount);

        // Update reserves
        reserveA -= amountTokenA;
        reserveB -= amountTokenB;

        // Transfer tokens to the provider
        tokenA.safeTransfer(msg.sender, amountTokenA);
        tokenB.safeTransfer(msg.sender, amountTokenB);

        emit LiquidityRemoved(msg.sender, amountTokenA, amountTokenB, liquidityAmount);
    }

    /**
     * @dev Swaps a specified amount of one token for another, adhering to the AMM formula.
     * @param amountIn Amount of input tokens to swap.
     * @param tokenIn Address of the input token.
     * @param tokenOut Address of the output token.
     * @param minAmountOut Minimum amount of output tokens expected (to protect against slippage).
     */
    function swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut
    ) external nonReentrant {
        require(amountIn > 0, "Invalid input amount");
        require(
            (tokenIn == address(tokenA) && tokenOut == address(tokenB)) ||
                (tokenIn == address(tokenB) && tokenOut == address(tokenA)),
            "Invalid token addresses"
        );

        IERC20 inputToken = IERC20(tokenIn);
        IERC20 outputToken = IERC20(tokenOut);

        // Transfer input tokens from the user to the pool
        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);

        // Calculate output amount based on AMM formula with fee
        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 reserveInput = (tokenIn == address(tokenA)) ? reserveA : reserveB;
        uint256 reserveOutput = (tokenOut == address(tokenA)) ? reserveA : reserveB;

        uint256 numerator = amountInWithFee * reserveOutput;
        uint256 denominator = reserveInput + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "Insufficient output amount");

        // Update reserves before transferring output tokens
        if (tokenIn == address(tokenA)) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Transfer output tokens to the user
        outputToken.safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @dev Returns the current reserves of TokenA and TokenB in the pool.
     * @return _reserveA Current reserve of TokenA.
     * @return _reserveB Current reserve of TokenB.
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    /**
     * @dev Calculates the amount of output tokens a user would receive for a given input amount.
     * @param amountIn Amount of input tokens.
     * @param tokenIn Address of the input token.
     * @return amountOut Calculated amount of output tokens.
     */
    function calculateAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(
            (tokenIn == address(tokenA) || tokenIn == address(tokenB)),
            "Invalid token address"
        );

        address tokenOut = (tokenIn == address(tokenA)) ? address(tokenB) : address(tokenA);
        IERC20 inputToken = IERC20(tokenIn);

        uint256 reserveInput = (tokenIn == address(tokenA)) ? reserveA : reserveB;
        uint256 reserveOutput = (tokenIn == address(tokenA)) ? reserveB : reserveA;

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 numerator = amountInWithFee * reserveOutput;
        uint256 denominator = reserveInput + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev Internal function to calculate the square root of a given number.
     * Uses the Babylonian method for computation.
     * @param y The number to calculate the square root of.
     * @return z The square root of the input number.
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }

    /**
     * @dev Internal function to return the minimum of two numbers.
     * @param x First number.
     * @param y Second number.
     * @return The minimum of x and y.
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y) ? x : y;
    }
}
