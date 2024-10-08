const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

describe("LiquidityPool Contract", function () {
  let XToken, YToken, xToken, yToken, LiquidityPool, liquidityPool, owner, addr1;

  beforeEach(async function () {
    [owner, addr1, _] = await ethers.getSigners();

    XToken = await ethers.getContractFactory("XToken");
    YToken = await ethers.getContractFactory("XToken"); // Using XToken as a placeholder for YToken
    xToken = await XToken.deploy();
    yToken = await YToken.deploy();
    await xToken.deployed();
    await yToken.deployed();

    LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = await LiquidityPool.deploy(xToken.address, yToken.address);
    await liquidityPool.deployed();

    // Mint and approve tokens for liquidity pool
    await xToken.mint(owner.address, ethers.utils.parseEther("1000000"));
    await yToken.mint(owner.address, ethers.utils.parseEther("1000000"));
    await xToken.mint(addr1.address, ethers.utils.parseEther("1000000"));
    await yToken.mint(addr1.address, ethers.utils.parseEther("1000000"));

    await xToken.approve(liquidityPool.address, ethers.utils.parseEther("1000000"));
    await yToken.approve(liquidityPool.address, ethers.utils.parseEther("1000000"));
    await xToken.connect(addr1).approve(liquidityPool.address, ethers.utils.parseEther("1000000"));
    await yToken.connect(addr1).approve(liquidityPool.address, ethers.utils.parseEther("1000000"));
  });

  it("Should add liquidity correctly", async function () {
    await liquidityPool.addLiquidity(
      ethers.utils.parseEther("1000"),
      ethers.utils.parseEther("1000")
    );

    const reserveA = await liquidityPool.reserveA();
    const reserveB = await liquidityPool.reserveB();

    expect(reserveA).to.equal(ethers.utils.parseEther("1000"));
    expect(reserveB).to.equal(ethers.utils.parseEther("1000"));
  });

  it("Should allow swapping tokens", async function () {
    // Add liquidity
    await liquidityPool.addLiquidity(
      ethers.utils.parseEther("1000"),
      ethers.utils.parseEther("1000")
    );

    // Transfer tokens to addr1
    await xToken.transfer(addr1.address, ethers.utils.parseEther("100"));
    await xToken.connect(addr1).approve(liquidityPool.address, ethers.utils.parseEther("100"));

    // Swap XToken for YToken
    await liquidityPool
      .connect(addr1)
      .swap(xToken.address, ethers.utils.parseEther("10"));

    const addr1YBalance = await yToken.balanceOf(addr1.address);

    // Addr1 should have received YTokens
    expect(addr1YBalance).to.be.gt(ethers.constants.Zero);
  });

  it("Should remove liquidity correctly", async function () {
    // Add liquidity
    await liquidityPool.addLiquidity(
      ethers.utils.parseEther("1000"),
      ethers.utils.parseEther("1000")
    );

    const initialXBalance = await xToken.balanceOf(owner.address);
    const initialYBalance = await yToken.balanceOf(owner.address);

    // Remove liquidity
    await liquidityPool.removeLiquidity(ethers.utils.parseEther("500"));

    const finalXBalance = await xToken.balanceOf(owner.address);
    const finalYBalance = await yToken.balanceOf(owner.address);

    expect(finalXBalance).to.be.gt(initialXBalance);
    expect(finalYBalance).to.be.gt(initialYBalance);
  });
});
