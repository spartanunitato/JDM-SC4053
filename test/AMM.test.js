// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("AMMFactory", function () {
//   let factory, owner, tokenA, tokenB, addr1;

//   beforeEach(async function () {
//     [owner, addr1] = await ethers.getSigners();

//     // Deploy tokens
//     const MockERC20 = await ethers.getContractFactory("MockERC20");
//     tokenA = await MockERC20.deploy("TokenA", "TKA", ethers.utils.parseEther("1000000"));
//     tokenB = await MockERC20.deploy("TokenB", "TKB", ethers.utils.parseEther("1000000"));

//     // Deploy factory
//     const AMMFactory = await ethers.getContractFactory("AMMFactory");
//     factory = await AMMFactory.deploy();
//   });

//   it("Should create a new liquidity pool", async function () {
//     await factory.createPair(tokenA.address, tokenB.address);

//     const pairAddress = await factory.getPairAddress(tokenA.address, tokenB.address);
//     expect(pairAddress).to.properAddress;

//     const allPairsLength = await factory.allPairsLength();
//     expect(allPairsLength).to.equal(1);
//   });

//   it("Should not allow creating the same pair twice", async function () {
//     await factory.createPair(tokenA.address, tokenB.address);

//     await expect(
//       factory.createPair(tokenA.address, tokenB.address)
//     ).to.be.revertedWith("AMMFactory: PAIR_EXISTS");
//   });
// });
