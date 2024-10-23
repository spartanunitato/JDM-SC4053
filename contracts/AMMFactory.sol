// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AMMFactory is Ownable {

    constructor(address _priceFeedAddress) Ownable(_priceFeedAddress) {
        // Set the price feed address in the constructor
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    AggregatorV3Interface internal priceFeed;

    struct Order {
        address maker;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 remainingAmountIn;
        bool isBuyOrder;
        bool isActive;
        uint256 price; // Price condition for the order
        uint256 expiration; // Expiration or time-lock condition for the order
        bool executeAfter; // Time-lock flag
        uint256 volumeThreshold; // Volume-based condition for the order
    }

    mapping(address => mapping(address => Order[])) public buyOrders;
    mapping(address => mapping(address => Order[])) public sellOrders;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint allPairsLength);
    event OrderPlaced(address indexed maker, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, bool isBuyOrder);
    event OrderMatched(address indexed maker, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCancelled(address indexed maker, address indexed tokenIn, address indexed tokenOut);
    event VolumeConditionNotMet(address indexed maker, uint256 currentVolume, uint256 requiredVolume);
    event PriceConditionNotMet(address indexed maker, uint256 currentPrice, uint256 requiredPrice);

    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        require(tokenA != tokenB, "AMMFactory: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "AMMFactory: ZERO_ADDRESS");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(getPair[token0][token1] == address(0), "AMMFactory: PAIR_EXISTS");

        LiquidityPool newPool = new LiquidityPool(token0, token1);
        pair = address(newPool);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // Function to place a new limit order with conditional options (price, volume, time)
    function placeConditionalOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder,
        uint256 price, // Optional price threshold for the order
        uint256 expiration, // Optional expiration time
        bool executeAfter, // Time-lock flag
        uint256 volumeThreshold // Optional volume threshold
    ) external {
        require(tokenIn != tokenOut, "AMMFactory: INVALID_TRADE");
        require(amountIn > 0 && amountOut > 0, "AMMFactory: INVALID_AMOUNT");
        
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        Order memory newOrder = Order({
            maker: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            remainingAmountIn: amountIn,
            isBuyOrder: isBuyOrder,
            isActive: true,
            price: price,
            expiration: expiration,
            executeAfter: executeAfter,
            volumeThreshold: volumeThreshold
        });

        if (isBuyOrder) {
            buyOrders[token0][token1].push(newOrder);
        } else {
            sellOrders[token0][token1].push(newOrder);
        }

        emit OrderPlaced(msg.sender, tokenIn, tokenOut, amountIn, amountOut, isBuyOrder);

        // Try to match orders
        matchConditionalOrders(token0, token1, isBuyOrder);
    }

    // Function to match buy and sell orders based on price, volume, and time conditions
    function matchConditionalOrders(address token0, address token1, bool isBuyOrder) internal {
        Order[] storage buyOrderBook = buyOrders[token0][token1];
        Order[] storage sellOrderBook = sellOrders[token0][token1];

        LiquidityPool pool = LiquidityPool(getPair[token0][token1]);
        uint256 poolVolume = pool.getTotalVolume(); // Get the current volume from the pool

        uint256 i = 0;
        uint256 j = 0;

        while (i < buyOrderBook.length && j < sellOrderBook.length) {
            Order storage buyOrder = buyOrderBook[i];
            Order storage sellOrder = sellOrderBook[j];

            // Skip inactive orders
            if (!buyOrder.isActive || !sellOrder.isActive) {
                if (!buyOrder.isActive) { i++; }
                if (!sellOrder.isActive) { j++; }
                continue;
            }

            // **Time Condition Check**
            if (block.timestamp < buyOrder.expiration && buyOrder.executeAfter) {
                i++;
                continue;
            }

            if (block.timestamp < sellOrder.expiration && sellOrder.executeAfter) {
                j++;
                continue;
            }

            // **Volume Condition Check**
            if (buyOrder.volumeThreshold > 0 && poolVolume < buyOrder.volumeThreshold) {
                emit VolumeConditionNotMet(buyOrder.maker, poolVolume, buyOrder.volumeThreshold);
                i++;
                continue;
            }

            if (sellOrder.volumeThreshold > 0 && poolVolume < sellOrder.volumeThreshold) {
                emit VolumeConditionNotMet(sellOrder.maker, poolVolume, sellOrder.volumeThreshold);
                j++;
                continue;
            }

            // **Price Condition Check**
            if (buyOrder.price < sellOrder.price) {
                emit PriceConditionNotMet(buyOrder.maker, buyOrder.price, sellOrder.price);
                i++;
                j++;
                continue;
            }

            // Calculate trade amount (minimum of remaining amounts)
            uint256 tradeAmountIn = (buyOrder.remainingAmountIn < sellOrder.remainingAmountIn)
                ? buyOrder.remainingAmountIn
                : sellOrder.remainingAmountIn;

            // Update remaining amounts
            buyOrder.remainingAmountIn -= tradeAmountIn;
            sellOrder.remainingAmountIn -= tradeAmountIn;

            // Fulfill orders
            if (buyOrder.remainingAmountIn == 0) {
                buyOrder.isActive = false;
                i++;
            }

            if (sellOrder.remainingAmountIn == 0) {
                sellOrder.isActive = false;
                j++;
            }

            // Update pool volume after successful trade
            pool.updateVolume(tradeAmountIn);

            emit OrderMatched(buyOrder.maker, token0, token1, tradeAmountIn, tradeAmountIn);
        }
    }

    // Function to batch execute multiple orders
    function batchExecuteOrders(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut
    ) external onlyOwner {
        require(tokensIn.length == tokensOut.length && amountsIn.length == amountsOut.length, "AMMFactory: INVALID_BATCH_DATA");

        uint256 totalExecuted = 0;

        for (uint256 i = 0; i < tokensIn.length; i++) {
            address tokenIn = tokensIn[i];
            address tokenOut = tokensOut[i];
            uint256 amountIn = amountsIn[i];
            uint256 amountOut = amountsOut[i];

            (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

            uint256 tradedAmount = _executeTrade(token0, token1, amountIn, amountOut);
            totalExecuted += tradedAmount;
        }
    }

    // Internal function to execute individual trade within batch
    function _executeTrade(
        address token0,
        address token1,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        Order[] storage buyOrderBook = buyOrders[token0][token1];
        Order[] storage sellOrderBook = sellOrders[token0][token1];

        uint256 i = 0;
        uint256 j = 0;
        uint256 totalTraded = 0;

        while (i < buyOrderBook.length && j < sellOrderBook.length) {
            Order storage buyOrder = buyOrderBook[i];
            Order storage sellOrder = sellOrderBook[j];

            if (!buyOrder.isActive || !sellOrder.isActive) {
                if (!buyOrder.isActive) { i++; }
                if (!sellOrder.isActive) { j++; }
                continue;
            }

            if (buyOrder.price >= sellOrder.price) {
                uint256 tradeAmountIn = (buyOrder.remainingAmountIn < sellOrder.remainingAmountIn)
                    ? buyOrder.remainingAmountIn
                    : sellOrder.remainingAmountIn;

                buyOrder.remainingAmountIn -= tradeAmountIn;
                sellOrder.remainingAmountIn -= tradeAmountIn;

                if (buyOrder.remainingAmountIn == 0) {
                    buyOrder.isActive = false;
                    i++;
                }

                if (sellOrder.remainingAmountIn == 0) {
                    sellOrder.isActive = false;
                    j++;
                }

                totalTraded += tradeAmountIn;

                // Update pool volume after successful trade
                LiquidityPool pool = LiquidityPool(getPair[token0][token1]);
                pool.updateVolume(tradeAmountIn);

                emit OrderMatched(buyOrder.maker, token0, token1, tradeAmountIn, tradeAmountIn);
            } else {
                i++;
                j++;
            }
        }

        return totalTraded;
    }

    // Fetch the latest ETH/USD price from Chainlink
    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price; // ETH/USD price with 8 decimals
    }

    // Function to place a limit order based on an external price condition (e.g., ETH/USD)
    function placeOrderWithExternalPriceCondition(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder,
        uint256 ethPriceCondition // Condition to execute the order only if ETH price meets this threshold
    ) external {
        int256 latestPrice = getLatestPrice(); // Fetch current ETH price

        // Example condition: Execute only if ETH/USD is higher than the specified threshold
        require(latestPrice >= int256(ethPriceCondition), "AMMFactory: Price Condition Not Met");

        // Proceed with placing the order...
    }

    // Function to cancel an order
    function cancelOrder(
        address tokenIn,
        address tokenOut,
        uint256 orderIndex,
        bool isBuyOrder
    ) external {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        Order[] storage orders = isBuyOrder ? buyOrders[token0][token1] : sellOrders[token0][token1];
        require(orderIndex < orders.length, "AMMFactory: INVALID_ORDER_INDEX");

        Order storage orderToCancel = orders[orderIndex];
        require(orderToCancel.maker == msg.sender, "AMMFactory: NOT_ORDER_MAKER");
        require(orderToCancel.isActive, "AMMFactory: ORDER_ALREADY_CANCELLED");

        orderToCancel.isActive = false;

        emit OrderCancelled(msg.sender, tokenIn, tokenOut);
    }
}

