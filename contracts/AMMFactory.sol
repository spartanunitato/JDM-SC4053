// contracts/AMMFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AMMFactory is Ownable(msg.sender) {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint allPairsLength);

    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        require(tokenA != tokenB, "AMMFactory: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "AMMFactory: ZERO_ADDRESS");

        // Normalize token order
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(getPair[token0][token1] == address(0), "AMMFactory: PAIR_EXISTS");

        LiquidityPool newPool = new LiquidityPool(token0, token1);
        pair = address(newPool);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // Reverse mapping for convenience
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function getPairAddress(address tokenA, address tokenB) external view returns (address pair) {
        // Normalize token order to always return the correct pair
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return getPair[token0][token1];
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function transferPoolOwnership(address tokenA, address tokenB, address newOwner) external onlyOwner {
        // Normalize token order
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address poolAddress = getPair[token0][token1];
        require(poolAddress != address(0), "AMMFactory: POOL_NOT_FOUND");
        LiquidityPool(poolAddress).transferOwnership(newOwner);
    }
}
