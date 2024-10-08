// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OrderBookDEX is Ownable {
    enum OrderType { Buy, Sell }

    struct Order {
        uint256 id;
        address trader;
        OrderType orderType;
        uint256 amount;
        uint256 price; // Price per token in wei
        uint256 filled;
    }

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    uint256[] public orderIds;

    // Fees
    uint256 public constant FEE_RATE = 10; // 1% fee
    address public feeAccount;

    // Events
    event NewOrder(uint256 id, address trader, OrderType orderType, uint256 amount, uint256 price);
    event OrderFilled(uint256 id, address trader, uint256 amount);
    event OrderCancelled(uint256 id, address trader);

    constructor(address _feeAccount) Ownable(msg.sender) {
        feeAccount = _feeAccount;
    }

    // Submit a new order
    function submitOrder(OrderType orderType, uint256 amount, uint256 price) external payable {
        require(amount > 0 && price > 0, "Invalid amount or price");

        if (orderType == OrderType.Buy) {
            // Calculate total cost without overflow
            uint256 totalCost = (amount * price) / 1 ether;
            require(msg.value >= totalCost, "Insufficient ETH sent");
        } else {
            // For Sell orders, tokens should be transferred to the contract
            // Implement token transfer logic here
        }

        orders[nextOrderId] = Order({
            id: nextOrderId,
            trader: msg.sender,
            orderType: orderType,
            amount: amount,
            price: price,
            filled: 0
        });

        orderIds.push(nextOrderId);

        emit NewOrder(nextOrderId, msg.sender, orderType, amount, price);

        nextOrderId++;
    }


    // Match orders
    function matchOrders() external onlyOwner {
        // Implement order matching logic here
        // This is a complex process involving sorting orders and matching them based on price and time
    }

    // Cancel an order
    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");

        // Refund logic
        if (order.orderType == OrderType.Buy) {
            uint256 remainingAmount = order.amount - order.filled;
            uint256 refundAmount = (remainingAmount * order.price) / 1 ether;
            payable(order.trader).transfer(refundAmount);
        } else {
            // Return tokens to the trader
            // Implement token return logic if applicable
        }

        // Remove the order
        delete orders[orderId];

        emit OrderCancelled(orderId, msg.sender);
    }

}
