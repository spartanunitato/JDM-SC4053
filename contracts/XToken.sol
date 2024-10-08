// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin ERC20 implementation
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XToken is ERC20, Ownable {
    constructor() ERC20("XToken", "XTK") Ownable(msg.sender) {
        // Mint initial supply to the contract deployer
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    // Mint new tokens (only owner)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Burn tokens from caller's account
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
