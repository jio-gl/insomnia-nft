// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract InsomniaToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    )
        ERC20(name_, symbol_)
        Ownable(msg.sender) // Pass `msg.sender` as the initial owner
    {
        // Mint some tokens to the owner
        _mint(msg.sender, initialSupply);
    }
}
