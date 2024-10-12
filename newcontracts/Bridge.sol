// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin Contracts
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IBridgeToken
 * @dev Interface for the bridged ERC20 token with mint and burn functionalities.
 */
interface IBridgeToken is IERC20 {
    /**
     * @dev Mints `amount` tokens to the `to` address.
     * @param to The address to receive minted tokens.
     * @param amount The number of tokens to mint.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Burns `amount` tokens from the caller's account.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) external;
}

/**
 * @title Bridge
 * @dev Manages cross-chain transfer of tokens by handling locking and minting.
 */
contract Bridge is Ownable (msg.sender), ReentrancyGuard {
    // The ERC20 token being bridged
    IBridgeToken public token;

    // Mapping to track processed transaction IDs
    mapping(bytes32 => bool) private processedTransactions;

    // Events
    event TokensLocked(
        address indexed sender,
        uint256 amount,
        address indexed destinationAddress,
        bytes32 transactionId
    );

    event TokensMinted(
        address indexed to,
        uint256 amount,
        bytes32 transactionId
    );

    event TokensBurned(
        address indexed from,
        uint256 amount,
        bytes32 transactionId
    );

    /**
     * @dev Initializes the contract with the token address.
     * @param _token The address of the ERC20 token to be bridged.
     */
    constructor(IBridgeToken _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }

    /**
     * @dev Locks a specified amount of tokens in the bridge contract on the source chain.
     * Emits a {TokensLocked} event.
     * @param amount The number of tokens to lock.
     * @param destinationAddress The recipient address on the destination chain.
     */
    function lockTokens(uint256 amount, address destinationAddress)
        external
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than zero");
        require(
            destinationAddress != address(0),
            "Destination address cannot be zero"
        );

        // Transfer tokens from the sender to the bridge contract
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(
            abi.encodePacked(msg.sender, amount, destinationAddress, block.timestamp)
        );

        // Emit the TokensLocked event
        emit TokensLocked(msg.sender, amount, destinationAddress, transactionId);
    }

    /**
     * @dev Mints tokens on the destination chain corresponding to the locked tokens on the source chain.
     * Can only be called by the contract owner.
     * Emits a {TokensMinted} event.
     * @param to The address to receive minted tokens.
     * @param amount The number of tokens to mint.
     * @param transactionId The unique identifier of the cross-chain transfer.
     */
    function mintTokens(
        address to,
        uint256 amount,
        bytes32 transactionId
    ) external onlyOwner {
        require(to != address(0), "Recipient address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(
            !processedTransactions[transactionId],
            "Transaction already processed"
        );

        // Mark the transaction as processed
        processedTransactions[transactionId] = true;

        // Mint tokens to the recipient
        token.mint(to, amount);

        // Emit the TokensMinted event
        emit TokensMinted(to, amount, transactionId);
    }

    /**
     * @dev Burns tokens on the destination chain when transferring back to the source chain.
     * Emits a {TokensBurned} event.
     * @param amount The number of tokens to burn.
     */
    function burnTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        // Burn tokens from the sender's balance
        IBridgeToken(address(token)).burn(amount);

        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(
            abi.encodePacked(msg.sender, amount, block.timestamp)
        );

        // Emit the TokensBurned event
        emit TokensBurned(msg.sender, amount, transactionId);
    }

    /**
     * @dev Returns the status of a cross-chain transfer by checking if a transactionId has been processed.
     * @param transactionId The unique identifier of the cross-chain transfer.
     * @return bool indicating whether the transaction has been processed.
     */
    function getTransactionStatus(bytes32 transactionId)
        external
        view
        returns (bool)
    {
        return processedTransactions[transactionId];
    }
}
