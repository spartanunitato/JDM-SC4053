const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

describe("Cross-Chain Bridge Contracts", function () {
  let XToken, xToken, BridgeSource, bridgeSource, BridgeDestination, bridgeDestination, owner, user;

  beforeEach(async function () {
    [owner, user, _] = await ethers.getSigners();

    // Deploy token contract
    XToken = await ethers.getContractFactory("XToken");
    xToken = await XToken.deploy();
    await xToken.deployed();

    // Mint tokens to user before transferring ownership
    await xToken.mint(user.address, ethers.utils.parseEther("1000"));

    // Deploy source bridge
    BridgeSource = await ethers.getContractFactory("BridgeSource");
    bridgeSource = await BridgeSource.deploy(xToken.address);
    await bridgeSource.deployed();

    // Deploy destination bridge
    BridgeDestination = await ethers.getContractFactory("BridgeDestination");
    bridgeDestination = await BridgeDestination.deploy(xToken.address);
    await bridgeDestination.deployed();

    // Transfer ownership of XToken to BridgeDestination
    await xToken.transferOwnership(bridgeDestination.address);

    // Approve bridge contract to spend user's tokens
    await xToken.connect(user).approve(bridgeSource.address, ethers.utils.parseEther("1000"));
  });

  it("Should lock tokens on the source chain", async function () {
    // Arrange
    const amountToLock = ethers.utils.parseEther("100");
    const destinationAddress = "destinationAddress";

    // Act
    await bridgeSource.connect(user).lockTokens(amountToLock, destinationAddress);

    // Assert
    const bridgeBalance = await xToken.balanceOf(bridgeSource.address);
    expect(bridgeBalance).to.equal(amountToLock);

    const userBalance = await xToken.balanceOf(user.address);
    expect(userBalance).to.equal(ethers.utils.parseEther("900"));

    // You can also check that the event was emitted
    await expect(
      bridgeSource.connect(user).lockTokens(amountToLock, destinationAddress)
    ).to.emit(bridgeSource, "TokensLocked").withArgs(user.address, amountToLock, destinationAddress);
  });

  it("Should mint tokens on the destination chain", async function () {
    // Use the owner account to call mintTokens
    await bridgeDestination.connect(owner).mintTokens(user.address, ethers.utils.parseEther("100"));

    const userBalance = await xToken.balanceOf(user.address);
    expect(userBalance).to.equal(ethers.utils.parseEther("1100"));
  });
});
