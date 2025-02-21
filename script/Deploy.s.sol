// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/InsomniaNFT.sol";
import "../src/InsomniaToken.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1) Deploy the ERC20 payment token
        InsomniaToken token = new InsomniaToken(
            "Token",
            "IPX",
            1_000_000 ether
        );

        // 2) Hardcode your existing Sablier address here
        address sablierAddress = 0x0000000000000000000000000000000000000000;

        // 3) Deploy the NFT contract 
        //    Now pass all 4 constructor arguments: name, symbol, token address, sablier address
        InsomniaNFT nft = new InsomniaNFT(
            "InsomniaNFT",
            "IIN",
            address(token),
            sablierAddress
        );

        vm.stopBroadcast();
    }
}
