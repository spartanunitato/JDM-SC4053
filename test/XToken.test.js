const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

describe("XToken Contract", function () {
  let XToken, xtoken, owner, addr1, addr2;

  beforeEach(async function () {
    XToken = await ethers.getContractFactory("XToken");
    [owner, addr1, addr2, _] = await ethers.getSigners();
    xtoken = await XToken.deploy();
    await xtoken.deployed();
  });

  it("Should assign initial supply to the owner", async function () {
    const ownerBalance = await xtoken.balanceOf(owner.address);
    const totalSupply = await xtoken.totalSupply();
    expect(ownerBalance).to.equal(totalSupply);
  });

  it("Should allow owner to mint tokens", async function () {
    await xtoken.mint(addr1.address, ethers.utils.parseEther("1000"));
    const addr1Balance = await xtoken.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(ethers.utils.parseEther("1000"));
  });

  it("Should prevent non-owners from minting tokens", async function () {
    await expect(
      xtoken.connect(addr1).mint(addr1.address, ethers.utils.parseEther("1000"))
    ).to.be.revertedWith("OwnableUnauthorizedAccount");
  });

  it("Should allow users to burn their tokens", async function () {
    await xtoken.transfer(addr1.address, ethers.utils.parseEther("500"));
    await xtoken.connect(addr1).burn(ethers.utils.parseEther("200"));
    const addr1Balance = await xtoken.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(ethers.utils.parseEther("300"));
  });

  it("Should allow transfers between accounts", async function () {
    await xtoken.transfer(addr1.address, ethers.utils.parseEther("100"));
    await xtoken.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("50"));
    const addr2Balance = await xtoken.balanceOf(addr2.address);
    expect(addr2Balance).to.equal(ethers.utils.parseEther("50"));
  });
});
