
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/ERC20.sol";
import "./lib/Ownable.sol";

// This contract is used really only for superficial purposes so that it's easier to see which pool is which
// Tokens are actually held in the iStaxMarket.sol contract

contract iStaxMarketToken is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);

    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}