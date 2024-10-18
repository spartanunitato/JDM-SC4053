// contracts/Bridge.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBridgeToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract Bridge is Ownable(msg.sender), ReentrancyGuard {
    IBridgeToken public token;
    mapping(bytes32 => bool) private processedTransactions;

    event TokensLocked(address indexed sender, uint256 amount, address indexed destinationAddress, bytes32 transactionId);
    event TokensMinted(address indexed to, uint256 amount, bytes32 transactionId);
    event TokensBurned(address indexed from, uint256 amount, bytes32 transactionId);

    constructor(IBridgeToken _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }

    function lockTokens(uint256 amount, address destinationAddress) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(destinationAddress != address(0), "Destination address cannot be zero");

        token.transferFrom(msg.sender, address(this), amount);
        token.burn(amount);

        bytes32 transactionId = keccak256(
            abi.encodePacked(msg.sender, amount, destinationAddress, block.number)
        );

        emit TokensLocked(msg.sender, amount, destinationAddress, transactionId);
    }

    function mintTokens(address to, uint256 amount, bytes32 transactionId) external onlyOwner {
        require(to != address(0), "Recipient address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(!processedTransactions[transactionId], "Transaction already processed");

        processedTransactions[transactionId] = true;
        token.mint(to, amount);

        emit TokensMinted(to, amount, transactionId);
    }

    function burnTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        token.burn(amount);

        bytes32 transactionId = keccak256(
            abi.encodePacked(msg.sender, amount, block.number)
        );

        emit TokensBurned(msg.sender, amount, transactionId);
    }

    function getTransactionStatus(bytes32 transactionId) external view returns (bool) {
        return processedTransactions[transactionId];
    }
}
