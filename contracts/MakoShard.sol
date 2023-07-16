// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MakoShard is ERC20 {
    uint256 public constant REQUEST_AMOUNT = 10 * 10**18; // 10 tokens, adjusted for decimals

    constructor() ERC20("MakoShard", "MKS") {
        _mint(address(this), 2000 * 10**18); // Initial supply of 2000 tokens, minted to the contract itself
    }

    function requestTokens(address to) public {
        uint256 balance = balanceOf(address(this));

        require(balance >= REQUEST_AMOUNT, "MakoShard: Not enough tokens left to fulfill request");

        _transfer(address(this), to, REQUEST_AMOUNT);
    }
}
