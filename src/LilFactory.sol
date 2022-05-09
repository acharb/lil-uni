// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./LilExchange.sol";

contract LilFactory {
    mapping (address => address) internal token_to_exchange;

    function createExchange(address token) public returns (address) {
        require(token != address(0), "token address is 0");
        require(
            token_to_exchange[token] == address(0),
            "token is already added to exchange"
        );
        LilExchange exchange = new LilExchange();
        exchange.setup(token);
        token_to_exchange[token] = address(exchange);
        return address(exchange);
    }
}
