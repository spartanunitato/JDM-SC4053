// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./XToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeSource is Ownable {
    XToken public token;

    event TokensLocked(address indexed user, uint256 amount, string destinationAddress);

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = XToken(tokenAddress);
    }

    function lockTokens(uint256 amount, string calldata destinationAddress) external {
        require(amount > 0, "Amount must be greater than zero");

        token.transferFrom(msg.sender, address(this), amount);

        emit TokensLocked(msg.sender, amount, destinationAddress);
    }

    // Optional: Function to release tokens in case of rollback
    function releaseTokens(address user, uint256 amount) external onlyOwner {
        token.transfer(user, amount);
    }
}
