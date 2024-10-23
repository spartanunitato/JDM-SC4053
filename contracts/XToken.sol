// contracts/XToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title XToken
 * @dev ERC20 Token with mint and burn functionalities, inheriting from Ownable.
 */
contract XToken is ERC20, Ownable(msg.sender) {
    uint256 public feePercentage;
    bool public feeEnabled;

    event FeeEnabled(bool enabled);
    event FeeDisabled();

    /**
     * @dev Constructor that initializes the token with a name, symbol, initial supply, fee percentage, and owner.
     * @param name_ Name of the token.
     * @param symbol_ Symbol of the token.
     * @param initialSupply_ Initial total supply of the token.
     * @param feePercentage_ Fee percentage for transfers (e.g., 2 for 2%).
     * @param initialOwner Address of the initial owner.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 feePercentage_,
        address initialOwner
    ) ERC20(name_, symbol_) {
        require(initialOwner != address(0), "Owner address cannot be zero");
        _mint(initialOwner, initialSupply_);
        feePercentage = feePercentage_;
        feeEnabled = false;
        transferOwnership(initialOwner);
    }

    /**
     * @dev Mints tokens to a specified address. Only the owner can call this function.
     * @param to Address to receive the minted tokens.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's account.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from a specified address. Only the owner can call this function.
     * @param from Address from which to burn tokens.
     * @param amount Amount of tokens to burn.
     */
    function burnFrom(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev Enables or disables the fee on transfers. Only the owner can call this function.
     * @param _enabled Boolean indicating whether to enable or disable the fee.
     */
    function setFeeEnabled(bool _enabled) external onlyOwner {
        feeEnabled = _enabled;
        if (_enabled) {
            emit FeeEnabled(_enabled);
        } else {
            emit FeeDisabled();
        }
    }

    /**
     * @dev Overrides the ERC20 transfer function to include a fee if enabled.
     * @param recipient Address of the recipient.
     * @param amount Amount of tokens to transfer.
     * @return Boolean indicating whether the operation succeeded.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (feeEnabled && feePercentage > 0) {
            uint256 fee = (amount * feePercentage) / 100;
            uint256 amountAfterFee = amount - fee;

            _transfer(_msgSender(), owner(), fee); // Transfer fee to owner
            _transfer(_msgSender(), recipient, amountAfterFee);
        } else {
            _transfer(_msgSender(), recipient, amount);
        }
        return true;
    }

    /**
     * @dev Overrides the ERC20 transferFrom function to include a fee if enabled.
     * @param sender Address of the sender.
     * @param recipient Address of the recipient.
     * @param amount Amount of tokens to transfer.
     * @return Boolean indicating whether the operation succeeded.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (feeEnabled && feePercentage > 0) {
            uint256 fee = (amount * feePercentage) / 100;
            uint256 amountAfterFee = amount - fee;

            uint256 currentAllowance = allowance(sender, _msgSender());
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

            _transfer(sender, owner(), fee); // Transfer fee to owner
            _transfer(sender, recipient, amountAfterFee);

            _approve(sender, _msgSender(), currentAllowance - amount);
        } else {
            _transfer(sender, recipient, amount);

            uint256 currentAllowance = allowance(sender, _msgSender());
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return true;
    }
}
