const { ethers } = require("hardhat")
const { expect } = require("chai")



describe("AMMFactory", function () {
    let AMMFactory, factory, tokenA, tokenB, pool, owner, addr1, addr2;
    
    
    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        // Deploy token contracts and AMMFactory
        const Token = await ethers.getContractFactory("ERC20Mock");
        tokenA = await Token.deploy("TokenA", "TKA", 1000000);
        tokenB = await Token.deploy("TokenB", "TKB", 1000000);
        await tokenA.deployed();
        await tokenB.deployed();

        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        pool = await LiquidityPool.deploy(tokenA.address, tokenB.address);
        await pool.deployed();

        AMMFactory = await ethers.getContractFactory("AMMFactory");
        factory = await AMMFactory.deploy("0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419");
        await factory.deployed();

        // Create a liquidity pool
        await factory.createPair(tokenA.address, tokenB.address);
    });

    it("Should place a new limit order", async function () {
        await factory.placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            100, // Price condition
            0,   // Expiration time
            false, // No time lock
            0    // No volume condition
        );
        const orders = await factory.buyOrders(tokenA.address, tokenB.address);
        expect(orders.length).to.equal(1);
        expect(orders[0].amountIn).to.equal(100);
    });

    it("Should match buy and sell orders", async function () {
        await factory.placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            100, // Price condition
            0,
            false,
            0
        );
        await factory.placeConditionalOrder(
            tokenB.address,
            tokenA.address,
            50,
            100,
            false,
            100,
            0,
            false,
            0
        );
        const poolVolumeBefore = await pool.getTotalVolume();
        expect(poolVolumeBefore).to.equal(0);

        await factory.matchConditionalOrders(tokenA.address, tokenB.address, true);

        const poolVolumeAfter = await pool.getTotalVolume();
        expect(poolVolumeAfter).to.equal(50); // Volume after matching
    });

    it("Should cancel an order", async function () {
        await factory.placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            100,
            0,
            false,
            0
        );
        await factory.cancelOrder(tokenA.address, tokenB.address, 0, true);
        const orders = await factory.buyOrders(tokenA.address, tokenB.address);
        expect(orders[0].isActive).to.equal(false);
    });

    it("Should fail to execute if volume condition not met", async function () {
        await factory.placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            100,
            0,
            false,
            200 // Volume condition, which won't be met
        );
        const poolVolume = await pool.getTotalVolume();
        expect(poolVolume).to.equal(0);

        await expect(factory.matchConditionalOrders(tokenA.address, tokenB.address, true)).to.be.revertedWith("VolumeConditionNotMet");
    });

    it("Should check external price condition using Chainlink", async function () {
        const ethPriceCondition = 2000; // Example ETH/USD condition
        await expect(factory.placeOrderWithExternalPriceCondition(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            ethPriceCondition
        )).to.be.revertedWith("Price Condition Not Met");
    });

    it("Should execute batch orders", async function () {
        await factory.placeConditionalOrder(
            tokenA.address,
            tokenB.address,
            100,
            50,
            true,
            100,
            0,
            false,
            0
        );
        await factory.placeConditionalOrder(
            tokenB.address,
            tokenA.address,
            50,
            100,
            false,
            100,
            0,
            false,
            0
        );

        await factory.batchExecuteOrders(
            [tokenA.address, tokenB.address],
            [tokenB.address, tokenA.address],
            [100, 50],
            [50, 100]
        );

        const poolVolume = await pool.getTotalVolume();
        expect(poolVolume).to.equal(50);
    });
});
