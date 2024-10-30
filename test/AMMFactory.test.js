const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMFactory", function () {
    let factory, tokenA, tokenB, owner;

    beforeEach(async function () {
        [owner] = await ethers.getSigners();

        // Deploy mock price feed
        const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
        const decimals = 8;
        const initialAnswer = ethers.utils.parseUnits("3000", decimals); // Mock ETH price at $3000
        const mockPriceFeed = await MockV3Aggregator.deploy(decimals, initialAnswer);
        await mockPriceFeed.deployed();

        // Deploy tokens
        const Token = await ethers.getContractFactory("MockERC20");
        tokenA = await Token.deploy("TokenA", "TKA", ethers.utils.parseEther("1000000"));
        tokenB = await Token.deploy("TokenB", "TKB", ethers.utils.parseEther("1000000"));

        // Deploy AMMFactory with mock price feed
        const AMMFactory = await ethers.getContractFactory("AMMFactory");
        factory = await AMMFactory.deploy(mockPriceFeed.address);
        await factory.deployed();

        // Create pair
        await factory.connect(owner).createPair(tokenA.address, tokenB.address);
    });

    it("Should place a new limit order", async function () {
        await factory.connect(owner).placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther("100"),
            ethers.utils.parseEther("50"),
            true,
            100,
            0,
            false,
            0
        );
    
        const orderLength = await factory.getBuyOrdersLength(tokenA.address, tokenB.address);
        expect(orderLength).to.equal(1);
    
        const order = await factory.getBuyOrder(tokenA.address, tokenB.address, 0);
        expect(order.amountIn).to.equal(ethers.utils.parseEther("100"));
    });
    

    it("Should match buy and sell orders", async function () {
        // Place buy order
        await factory.connect(owner).placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther("100"),
            ethers.utils.parseEther("50"),
            true,
            100,
            0,
            false,
            0
        );

        // Place sell order
        await factory.connect(owner).placeConditionalOrder(
            tokenB.address,
            tokenA.address,
            ethers.utils.parseEther("50"),
            ethers.utils.parseEther("100"),
            false,
            100,
            0,
            false,
            0
        );

        // Match orders
        await factory.connect(owner).matchConditionalOrders(tokenA.address, tokenB.address, true);

        // Access the pool and check the volume
        const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
        const pool = await ethers.getContractAt("LiquidityPool", pairAddress);
        const poolVolume = await pool.totalVolume();

        expect(poolVolume).to.equal(ethers.utils.parseEther("50"));
    });

    it("Should cancel an order", async function () {
        await factory.connect(owner).placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther("100"),
            ethers.utils.parseEther("50"),
            true,
            100,
            0,
            false,
            0
        );
    
        await factory.connect(owner).cancelOrder(
            tokenA.address,
            tokenB.address,
            0,    // orderIndex
            true  // isBuyOrder
        );
    
        // Use the helper function to get the order
        const order = await factory.getBuyOrder(tokenA.address, tokenB.address, 0);
        expect(order.isActive).to.equal(false);
    });
    

    it("Should fail to execute if volume condition not met", async function () {
        // Place buy order with volume threshold
        await factory.connect(owner).placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther("100"),
            ethers.utils.parseEther("50"),
            true,
            100,
            0,
            false,
            ethers.utils.parseEther("200") // Volume threshold not met
        );
    
        // Place a sell order to attempt to match with
        await factory.connect(owner).placeConditionalOrder(
            tokenB.address,
            tokenA.address,
            ethers.utils.parseEther("50"),
            ethers.utils.parseEther("100"),
            false,
            100,
            0,
            false,
            0 // No volume threshold for the sell order
        );
        
        const [token0Address, token1Address] = tokenA.address < tokenB.address
            ? [tokenA.address, tokenB.address]
            : [tokenB.address, tokenA.address];

        await factory.connect(owner).matchConditionalOrders(token0Address, token1Address, true);

        // Attempt to match orders and expect VolumeConditionNotMet event
        await expect(
            factory.connect(owner).matchConditionalOrders(tokenA.address, tokenB.address, true)
        ).to.emit(factory, "VolumeConditionNotMet").withArgs(
            owner.address,
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther("200"),
            ethers.utils.parseEther("0") // Assuming pool volume is 0
        );
    
        // Verify that the buy order is still active (since it was not matched)
        const buyOrder = await factory.getBuyOrder(tokenA.address, tokenB.address, 0);
        expect(buyOrder.isActive).to.equal(true);
    
        // Verify that the pool volume is still zero
        const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
        const pool = await ethers.getContractAt("LiquidityPool", pairAddress);
        const poolVolume = await pool.totalVolume();
        expect(poolVolume).to.equal(ethers.utils.parseEther("0"));
    });
    

    it("Should check external price condition using Chainlink", async function () {
        const ethPriceCondition = ethers.utils.parseUnits("4000", 8); // Condition price $4000

        await expect(
            factory.connect(owner).placeOrderWithExternalPriceCondition(
                tokenA.address,
                tokenB.address,
                ethers.utils.parseEther("100"),
                ethers.utils.parseEther("50"),
                true,
                ethPriceCondition
            )
        ).to.be.revertedWith("AMMFactory: Price Condition Not Met");
    });

    it("Should execute batch orders", async function () {
    await factory.connect(owner).batchExecuteOrders(
        [tokenA.address, tokenB.address],
        [tokenB.address, tokenA.address],
        [ethers.utils.parseEther("100"), ethers.utils.parseEther("50")],
        [ethers.utils.parseEther("50"), ethers.utils.parseEther("100")],
        [true, false] // isBuyOrder flags
    );

    const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
    const pool = await ethers.getContractAt("LiquidityPool", pairAddress);
    const poolVolume = await pool.totalVolume();

    expect(poolVolume).to.equal(ethers.utils.parseEther("50"));
});

});
