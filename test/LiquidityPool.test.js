const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityPool", function () {
  let pool, lpToken, tokenA, tokenB, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    tokenA = await MockERC20.deploy("TokenA", "TKA", ethers.utils.parseEther("1000000"));
    tokenB = await MockERC20.deploy("TokenB", "TKB", ethers.utils.parseEther("1000000"));

    // Deploy pool
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    pool = await LiquidityPool.deploy(tokenA.address, tokenB.address);

    // Get LP Token
    const lpTokenAddress = await pool.lpToken();
    lpToken = await ethers.getContractAt("LiquidityProvider", lpTokenAddress);

    // Transfer tokens to addr1
    await tokenA.transfer(addr1.address, ethers.utils.parseEther("10000"));
    await tokenB.transfer(addr1.address, ethers.utils.parseEther("10000"));
  });

  it("Should add liquidity and mint LP tokens", async function () {
    const amountA = ethers.utils.parseEther("1000");
    const amountB = ethers.utils.parseEther("1000");

    // Approve tokens
    await tokenA.connect(addr1).approve(pool.address, amountA);
    await tokenB.connect(addr1).approve(pool.address, amountB);

    // Add liquidity
    await pool.connect(addr1).addLiquidity(amountA, amountB);

    // Check LP token balance
    const lpBalance = await lpToken.balanceOf(addr1.address);
    expect(lpBalance).to.be.gt(0);
  });

  it("Should swap tokens", async function () {
    // Add liquidity first
    const amountA = ethers.utils.parseEther("1000");
    const amountB = ethers.utils.parseEther("1000");
    await tokenA.connect(addr1).approve(pool.address, amountA);
    await tokenB.connect(addr1).approve(pool.address, amountB);
    await pool.connect(addr1).addLiquidity(amountA, amountB);

    // Swap tokenA for tokenB
    const swapAmount = ethers.utils.parseEther("100");
    await tokenA.connect(addr1).approve(pool.address, swapAmount);

    const balanceBefore = await tokenB.balanceOf(addr1.address);
    await pool.connect(addr1).swap(tokenA.address, swapAmount, 0);
    const balanceAfter = await tokenB.balanceOf(addr1.address);

    expect(balanceAfter).to.be.gt(balanceBefore);
  });

  it("Should remove liquidity and burn LP tokens", async function () {
    // Add liquidity first
    const amountA = ethers.utils.parseEther("1000");
    const amountB = ethers.utils.parseEther("1000");
    await tokenA.connect(addr1).approve(pool.address, amountA);
    await tokenB.connect(addr1).approve(pool.address, amountB);
    await pool.connect(addr1).addLiquidity(amountA, amountB);

    const lpBalance = await lpToken.balanceOf(addr1.address);

    // Approve LP tokens
    await lpToken.connect(addr1).approve(pool.address, lpBalance);

    // Remove liquidity
    await pool.connect(addr1).removeLiquidity(lpBalance);

    // Check LP token balance
    const lpBalanceAfter = await lpToken.balanceOf(addr1.address);
    expect(lpBalanceAfter).to.equal(0);
  });
});
