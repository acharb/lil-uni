// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./console.sol";

import "../LilFactory.sol";

contract FactoryTest is DSTest {
    LilFactory factory;

    ERC20 token;
    address payable exchange_addr;

    OtherPerson other_person;

    event Received(address a, uint v);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function setUp() public {
        console.log("setup start");

        factory = new LilFactory();

        token = new ERC20();
        // 100 for initial deposit, 1 to swap with
        token.mint(address(this), 101 * 1e18);
        assertEq(token.balanceOf(address(this)), 101 * 1e18);

    }

    function testRun() public {
        uint eth_start_balance = address(this).balance;

        /////// Set up exchange ///////
        address exchangeAddr = factory.createExchange(address(token));
        LilExchange exchange = LilExchange(payable(exchangeAddr));

        // allowing the exchange to move all of my erc20 token I own
        // (needed for addLiquidity)
        token.approve(address(exchange), token.balanceOf(address(this)));


        // create another player
        other_person = new OtherPerson(address(token), payable(address(exchange)));

        /////// Add Liquidity ///////
        uint uni_tokens = exchange.addLiquidity{value: 500 ether}(100 * 1e18);

        // make sure the reserves are correct
        assertEq(token.balanceOf(address(exchange)), 100 * 1e18);
        assertEq(address(exchange).balance, 500 ether);

        // i have 1 token now
        assertEq(token.balanceOf(address(this)), 1 * 1e18);

        /////// SWAP ///////
        // how much Eth will I get if I trade in 1 token?
        uint eth_received = exchange.swapTokenForEth(1 * 1e18);
        
        // ~ 4.93579 eth
        assertEq(eth_received / 1e13, 493579);
        assertEq(token.balanceOf(address(exchange)), 101 * 1e18);
        // ~ 495.06421 ether
        assertEq(address(exchange).balance / 1e12, 495064209);

        // I have 0 tokens now
        assertEq(token.balanceOf(address(this)), 0);


        // let's say I want to swap back (eth->token)
        uint token_received = exchange.swapEthForToken{value: eth_received}();
        // ~ .99406 tokens (notice how less bc of fees)
        assertEq(token_received / 1e13, 99406);
        // ~ 100.00593 tokens
        assertEq(token.balanceOf(address(exchange)) / 1e13, 10000593);
        assertEq(address(exchange).balance, 500 ether);

        // I have .99406 tokens now
        assertEq(token.balanceOf(address(this))/ 1e13, 99406);
        // I'm back to eth amount before I swapped
        assertEq(eth_start_balance - address(this).balance - 500 ether, 0);


        /////// OTHER PERSON SWAP ///////
        other_person.swap();
        // ~ 101.00593 tokens
        assertEq(token.balanceOf(address(exchange)) / 1e13, 10100593);
        // ~ 495.064499
        assertEq(address(exchange).balance / 1e12, 495064499);


        /////// REMOVE LIQUIDITY ///////
        (uint eth_returned, uint tok_returned) = exchange.removeLiquidity(uni_tokens);
        // ~ 495.064499 eth
        assertEq(eth_returned / 1e12, 495064499);
        // ~ 101.00593 tokens
        assertEq(tok_returned / 1e13, 10100593);

        // pool is empty now
        assertEq(token.balanceOf(address(exchange)), 0);
        assertEq(address(exchange).balance, 0);

        // I have ~4.93350 less eth, due to what the other person received for their swap
        // ~ 4.93550 eth
        assertEq((eth_start_balance - address(this).balance) / 1e13, 493550);
        
        // I've gained 1 token, bc the other person swapped it
        assertEq(token.balanceOf(address(this)), 102 * 1e18);


        console.log("done!");
        // SO, I'm net +1 token, and minus ~4.93350 eth
        // start value was 1 token = 5 Eth
        // so Ive gained ~ .0665 eth in value from providing liquidity
        // (the value loss from the fee of swapping I got back, since only LP)
    }
}


contract OtherPerson {

    ERC20 token;
    LilExchange exchange;

    receive() external payable {}


    constructor(address _token, address payable _exchange) public {
        token = ERC20(_token);
        exchange = LilExchange(_exchange);

        token.mint(address(this), 1 * 1e18);
        token.approve(_exchange, 1 * 1e18);
    }

    function swap() public {
        exchange.swapTokenForEth(1 * 1e18);
    }
}