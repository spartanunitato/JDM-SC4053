// contracts/LiquidityProvider.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityProvider
 * @dev ERC20 Token representing Liquidity Provider (LP) shares in the Liquidity Pool.
 */
contract LiquidityProvider is ERC20, Ownable(msg.sender) {
    address public liquidityPool;

    event LiquidityTokensMinted(address indexed to, uint256 amount);
    event LiquidityTokensBurned(address indexed from, uint256 amount);

    modifier onlyLiquidityPool() {
        require(msg.sender == liquidityPool, "Caller is not the LiquidityPool");
        _;
    }

    /**
     * @dev Constructor that initializes the LP token with a name, symbol, and owner.
     * @param _name Name of the LP token.
     * @param _symbol Symbol of the LP token.
     * @param _liquidityPool Address of the LiquidityPool contract.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _liquidityPool
    ) ERC20(_name, _symbol) {
        require(_liquidityPool != address(0), "LiquidityPool address cannot be zero");
        liquidityPool = _liquidityPool;
        transferOwnership(_liquidityPool); // Set LiquidityPool as the owner
    }

    /**
     * @dev Mints LP tokens to a specified address. Can only be called by the LiquidityPool.
     * @param to Address to receive the minted LP tokens.
     * @param amount Amount of LP tokens to mint.
     */
    function mintLiquidityTokens(address to, uint256 amount) external onlyLiquidityPool {
        _mint(to, amount);
        emit LiquidityTokensMinted(to, amount);
    }

    /**
     * @dev Burns LP tokens from a specified address. Can only be called by the LiquidityPool.
     * @param from Address from which to burn the LP tokens.
     * @param amount Amount of LP tokens to burn.
     */
    function burnLiquidityTokens(address from, uint256 amount) external onlyLiquidityPool {
        _burn(from, amount);
        emit LiquidityTokensBurned(from, amount);
    }
}
