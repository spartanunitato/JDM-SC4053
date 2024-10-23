const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bridge", function () {
  let bridge, token, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy token
    const XToken = await ethers.getContractFactory("XToken");
    token = await XToken.deploy("BridgeToken", "BTK", 0, 0, owner.address);

    // Deploy bridge
    const Bridge = await ethers.getContractFactory("Bridge");
    bridge = await Bridge.deploy(token.address);

    // Transfer token ownership to bridge
    await token.transferOwnership(bridge.address);

    // Mint tokens to addr1 via bridge
    await bridge.mintTokens(addr1.address, ethers.utils.parseEther("1000"), ethers.utils.formatBytes32String("tx1"));
  });

  it("Should lock tokens and emit event", async function () {
    const amount = ethers.utils.parseEther("100");

    await token.connect(addr1).approve(bridge.address, amount);
    await bridge.connect(addr1).lockTokens(amount, addr1.address);

    const balance = await token.balanceOf(addr1.address);
    expect(balance).to.equal(ethers.utils.parseEther("900"));
  });

  it("Should prevent double processing of a transaction", async function () {
    const transactionId = ethers.utils.formatBytes32String("tx2");
    await bridge.mintTokens(addr1.address, ethers.utils.parseEther("100"), transactionId);

    await expect(
      bridge.mintTokens(addr1.address, ethers.utils.parseEther("100"), transactionId)
    ).to.be.revertedWith("Transaction already processed");
  });
});
