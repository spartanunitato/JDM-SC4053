// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AMMFactory is Ownable(msg.sender) {
    AggregatorV3Interface internal priceFeed;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    struct Order {
        address maker;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 remainingAmountIn;
        bool isBuyOrder;
        bool isActive;
        uint256 price;
        uint256 expiration;
        bool executeAfter;
        uint256 volumeThreshold;
    }

    mapping(address => mapping(address => Order[])) public buyOrders;
    mapping(address => mapping(address => Order[])) public sellOrders;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint allPairsLength);
    event OrderPlaced(address indexed maker, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, bool isBuyOrder);
    event OrderMatched(address indexed maker, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCancelled(address indexed maker, address indexed tokenIn, address indexed tokenOut);
    event VolumeConditionNotMet(
    address indexed maker,
    address tokenIn,
    address tokenOut,
    uint256 requiredVolume,
    uint256 currentVolume
);

    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        require(tokenA != tokenB, "AMMFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(getPair[token0][token1] == address(0), "AMMFactory: PAIR_EXISTS");
        LiquidityPool newPool = new LiquidityPool(token0, token1);
        pair = address(newPool);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function placeConditionalOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder,
        uint256 price,
        uint256 expiration,
        bool executeAfter,
        uint256 volumeThreshold
    ) public {
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
        matchConditionalOrders(token0, token1, isBuyOrder);
    }

    function placeOrderWithExternalPriceCondition(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder,
        uint256 ethPriceCondition
    ) external {
        int256 latestPrice = getLatestPrice();
        require(latestPrice >= int256(ethPriceCondition), "AMMFactory: Price Condition Not Met");
        placeConditionalOrder(tokenIn, tokenOut, amountIn, amountOut, isBuyOrder, ethPriceCondition, 0, false, 0);
    }

    function matchConditionalOrders(address tokenIn, address tokenOut, bool isBuyOrder) public {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        Order[] storage buyOrderBook = buyOrders[token0][token1];
        Order[] storage sellOrderBook = sellOrders[token0][token1];

        LiquidityPool pool = LiquidityPool(getPair[token0][token1]);
        uint256 poolVolume = pool.getTotalVolume();

        uint256 i = 0;
        uint256 j = 0;

        while (i < buyOrderBook.length && j < sellOrderBook.length) {
            Order storage buyOrder = buyOrderBook[i];
            Order storage sellOrder = sellOrderBook[j];

            if (!buyOrder.isActive || !sellOrder.isActive) {
                if (!buyOrder.isActive) { i++; }
                if (!sellOrder.isActive) { j++; }
                continue;
            }

            // Check volume condition for buy order
            if (buyOrder.volumeThreshold > 0 && poolVolume < buyOrder.volumeThreshold) {
                // Volume condition not met, skip this order
                emit VolumeConditionNotMet(
                    buyOrder.maker,
                    buyOrder.tokenIn,
                    buyOrder.tokenOut,
                    buyOrder.volumeThreshold,
                    poolVolume
                );
                i++;
                continue;
            }

            // Check volume condition for sell order
            if (sellOrder.volumeThreshold > 0 && poolVolume < sellOrder.volumeThreshold) {
                // Volume condition not met, skip this order
                emit VolumeConditionNotMet(
                    sellOrder.maker,
                    sellOrder.tokenIn,
                    sellOrder.tokenOut,
                    sellOrder.volumeThreshold,
                    poolVolume
                );
                j++;
                continue;
            }

            // Price matching logic
            if (buyOrder.price < sellOrder.price) {
                i++;
                j++;
                continue;
            }

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

            pool.updateVolume(tradeAmountIn);
            emit OrderMatched(buyOrder.maker, token0, token1, tradeAmountIn, tradeAmountIn);
        }
    }


    function batchExecuteOrders(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        bool[] calldata isBuyOrders
    ) external {
        require(
            tokensIn.length == tokensOut.length &&
            tokensIn.length == amountsIn.length &&
            tokensIn.length == amountsOut.length &&
            tokensIn.length == isBuyOrders.length,
            "Arrays must be the same length"
        );

        for (uint256 i = 0; i < tokensIn.length; i++) {
            placeConditionalOrder(
                tokensIn[i],
                tokensOut[i],
                amountsIn[i],
                amountsOut[i],
                isBuyOrders[i],
                0,
                0,
                false,
                0
            );
        }
    }


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

    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }
    function getBuyOrdersLength(address tokenIn, address tokenOut) external view returns (uint256) {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        return buyOrders[token0][token1].length;
    }

    function getBuyOrder(address tokenIn, address tokenOut, uint256 index) external view returns (Order memory) {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        return buyOrders[token0][token1][index];
    }

    function getSellOrdersLength(address tokenIn, address tokenOut) external view returns (uint256) {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        return sellOrders[token0][token1].length;
    }

    function getSellOrder(address tokenIn, address tokenOut, uint256 index) external view returns (Order memory) {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        return sellOrders[token0][token1][index];
    }

}