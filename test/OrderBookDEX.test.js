const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

describe("OrderBookDEX Contract", function () {
  let OrderBookDEX, orderBookDEX, owner, trader1, trader2;

  beforeEach(async function () {
    [owner, trader1, trader2, _] = await ethers.getSigners();

    OrderBookDEX = await ethers.getContractFactory("OrderBookDEX");
    orderBookDEX = await OrderBookDEX.deploy(owner.address);
    await orderBookDEX.deployed();
  });

  it("Should allow submitting buy orders", async function () {
    const amount = ethers.utils.parseEther("1"); // 1 token in wei
    const price = ethers.utils.parseEther("0.1"); // Price per token in wei (0.1 ETH)
  
    // Adjusted totalCost calculation
    const totalCost = amount.mul(price).div(ethers.utils.parseEther("1"));
  
    await orderBookDEX.connect(trader1).submitOrder(0, amount, price, { value: totalCost });
  
    const order = await orderBookDEX.orders(0);
    expect(order.trader).to.equal(trader1.address);
    expect(order.orderType).to.equal(0); // Buy order
    expect(order.amount).to.equal(amount);
    expect(order.price).to.equal(price);
  });
  

  it("Should allow submitting sell orders", async function () {
    const amount = ethers.utils.parseEther("1"); // 1 token
    const price = ethers.utils.parseEther("0.1"); // 0.1 ETH per token

    // Assume tokens are transferred to the contract for sell orders (not implemented)

    await orderBookDEX.connect(trader2).submitOrder(1, amount, price);

    const order = await orderBookDEX.orders(0);
    expect(order.trader).to.equal(trader2.address);
    expect(order.orderType).to.equal(1); // Sell order
    expect(order.amount).to.equal(amount);
    expect(order.price).to.equal(price);
  });

    it("Should allow cancelling orders", async function () {
    const amount = ethers.utils.parseEther("1");
    const price = ethers.utils.parseEther("0.1");
    const totalCost = amount.mul(price).div(ethers.utils.parseEther("1"));

    // Submit a buy order
    await orderBookDEX.connect(trader1).submitOrder(0, amount, price, { value: totalCost });

    // Cancel the order
    await orderBookDEX.connect(trader1).cancelOrder(0);

    const order = await orderBookDEX.orders(0);
    expect(order.trader).to.equal(ethers.constants.AddressZero);
    });

});
