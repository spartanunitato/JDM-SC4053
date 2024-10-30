const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("XToken", function () {
  let token, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy token with 2% fee
    const XToken = await ethers.getContractFactory("XToken");
    token = await XToken.deploy("XToken", "XTK", ethers.utils.parseEther("1000000"), 2, owner.address);
  });

  it("Should transfer tokens without fee when fee is disabled", async function () {
    await token.transfer(addr1.address, ethers.utils.parseEther("1000"));
    const balance = await token.balanceOf(addr1.address);
    expect(balance).to.equal(ethers.utils.parseEther("1000"));
  });

  it("Should transfer tokens with fee when fee is enabled", async function () {
    await token.setFeeEnabled(true);
    await token.transfer(addr1.address, ethers.utils.parseEther("1000"));

    const balance = await token.balanceOf(addr1.address);
    expect(balance).to.equal(ethers.utils.parseEther("980")); // 2% fee applied
  });
});
