const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityPool with Fee Token", function () {
  let pool, lpToken, feeToken, tokenB, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy fee token
    const XToken = await ethers.getContractFactory("XToken");
    feeToken = await XToken.deploy("FeeToken", "FTK", ethers.utils.parseEther("1000000"), 2, owner.address);
    await feeToken.setFeeEnabled(true);

    // Deploy regular token
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    tokenB = await MockERC20.deploy("TokenB", "TKB", ethers.utils.parseEther("1000000"));

    // Deploy pool
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    pool = await LiquidityPool.deploy(feeToken.address, tokenB.address);

    // Get LP Token
    const lpTokenAddress = await pool.lpToken();
    lpToken = await ethers.getContractAt("LiquidityProvider", lpTokenAddress);

    // Transfer tokens to addr1
    await feeToken.transfer(addr1.address, ethers.utils.parseEther("10000"));
    await tokenB.transfer(addr1.address, ethers.utils.parseEther("10000"));
  });

  it("Should add liquidity with fee token", async function () {
    const amountFeeToken = ethers.utils.parseEther("1000");
    const amountTokenB = ethers.utils.parseEther("1000");

    // Approve tokens
    await feeToken.connect(addr1).approve(pool.address, amountFeeToken);
    await tokenB.connect(addr1).approve(pool.address, amountTokenB);

    // Add liquidity
    await pool.connect(addr1).addLiquidity(amountFeeToken, amountTokenB);

    // Check LP token balance
    const lpBalance = await lpToken.balanceOf(addr1.address);
    expect(lpBalance).to.be.gt(0);

    // Check reserves
    const [reserveFeeToken, reserveTokenB] = await pool.getReserves();
    expect(reserveFeeToken).to.be.lt(amountFeeToken); // Due to fee
    expect(reserveTokenB).to.equal(amountTokenB);
  });
});
