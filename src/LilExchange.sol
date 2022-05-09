// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./tokens/ERC20.sol";
import "./interfaces/IERC20.sol";

contract LilExchange is ERC20 {
    IERC20 _token;
    uint256 _totalUniSupply;

    function setup(address token) public {
        _token = IERC20(token);
    }

    function addLiquidity(uint256 depositingTokensAmount)
        public
        payable
        returns (uint256)
    {
        uint256 total_liquidity = _totalUniSupply;

        // first deposit
        if (total_liquidity == 0) {
            // transfer tokens from sender to this exchange
            _token.transferFrom(
                msg.sender,
                address(this),
                depositingTokensAmount
            );
            // totalSupply and the UNI tokens sender gets is this initial balance
            uint256 initial_liquidity = address(this).balance;
            _totalUniSupply = initial_liquidity;
            _balances[msg.sender] = initial_liquidity;

            return initial_liquidity;
        }

        // not first deposit
        uint256 eth_reserve = address(this).balance - msg.value;
        uint256 token_reserve = _token.balanceOf(address(this));
        uint256 token_amount = ((msg.value * token_reserve) / eth_reserve) + 1;
        uint256 liquidity_minted = (msg.value * total_liquidity) / eth_reserve;

        _balances[msg.sender] = _balances[msg.sender] + liquidity_minted;
        _totalUniSupply = total_liquidity + liquidity_minted;
        _token.transferFrom(msg.sender, address(this), token_amount);
        return liquidity_minted;
    }

    function removeLiquidity(uint256 uniAmount)
        public
        returns (uint256, uint256)
    {
        uint256 total_liquidity = _totalUniSupply;
        uint256 token_reserve = _token.balanceOf(address(this));
        uint256 eth_amount = (uniAmount * address(this).balance) /
            total_liquidity;
        uint256 token_amount = (uniAmount * token_reserve) / total_liquidity;

        // update contract state
        _balances[msg.sender] = _balances[msg.sender] - uniAmount;
        _totalUniSupply = total_liquidity - uniAmount;
        // transfer tokens from this exchange to sender
        _token.transfer(msg.sender, token_amount);
        // transfer eth to sender
        payable(msg.sender).transfer(eth_amount);
        return (eth_amount, token_amount);
    }

    function swapTokenForEth(uint256 tokenAmount) public returns (uint256) {
        uint256 token_reserve = _token.balanceOf(address(this));
        uint256 token_amount_with_fee = tokenAmount * 997;
        uint256 numerator = token_amount_with_fee * address(this).balance;
        uint256 denominator = token_reserve * 1000 + token_amount_with_fee;
        uint256 eth_bought = numerator / denominator;

        payable(msg.sender).transfer(eth_bought);
        _token.transferFrom(msg.sender, address(this), tokenAmount);
        return eth_bought;
    }

    function swapEthForToken() public payable returns (uint256) {
        uint256 token_reserve = _token.balanceOf(address(this));
        uint256 eth_reserve = address(this).balance - msg.value;

        uint256 input_amount_with_fee = msg.value * 997;
        uint256 numerator = input_amount_with_fee * token_reserve;

        uint256 denominator = (eth_reserve * 1000) + input_amount_with_fee;

        uint256 tokens_bought = numerator / denominator;

        _token.transfer(msg.sender, tokens_bought);
        return tokens_bought;
    }
}
