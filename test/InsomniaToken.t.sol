// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/InsomniaToken.sol";

contract InsomniaTokenTest is Test {
    InsomniaToken token;

    function setUp() public {
        token = new InsomniaToken("Token", "IPX", 1_000_000 ether);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), 1_000_000 ether);
    }

    function testTransfer() public {
        address alice = address(0x1234);
        token.transfer(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }
}
