// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./XToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeDestination is Ownable {
    XToken public token;

    event TokensMinted(address indexed user, uint256 amount);

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = XToken(tokenAddress);
    }

    function mintTokens(address to, uint256 amount) external {
        // Only allow the owner of BridgeDestination to call this function
        require(msg.sender == owner(), "Not authorized");

        // The BridgeDestination contract must be the owner of XToken
        token.mint(to, amount);

        emit TokensMinted(to, amount);
    }
}
