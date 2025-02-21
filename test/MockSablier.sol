// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISablier} from "../lib/sablier/packages/protocol/contracts/interfaces/ISablier.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockSablier is ISablier {
    uint256 public nextStreamId = 1;

    struct Stream {
        address sender;
        address recipient;
        uint256 deposit;
        address token;
        uint256 startTime;
        uint256 stopTime;
        uint256 remainingBalance;
        uint256 ratePerSecond;
    }

    mapping(uint256 => Stream) public streams;

    function createStream(
        address recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    )
        external
        override
        returns (uint256 streamId)
    {
        require(stopTime > startTime, "Invalid time range");
        require(deposit > 0, "Invalid deposit");

        // Transfer deposit from the caller (the NFT contract) into this mock
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), deposit);

        streamId = nextStreamId++;
        uint256 duration = stopTime - startTime;
        uint256 rate = deposit / duration;

        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            deposit: deposit,
            token: tokenAddress,
            startTime: startTime,
            stopTime: stopTime,
            remainingBalance: deposit,
            ratePerSecond: rate
        });

        emit CreateStream(streamId, msg.sender, recipient, deposit, tokenAddress, startTime, stopTime);
    }

    function withdrawFromStream(uint256 streamId, uint256 funds) external override returns (bool) {
        Stream storage s = streams[streamId];
        require(s.sender != address(0), "Stream doesn't exist");
        require(msg.sender == s.recipient, "Only recipient can withdraw");

        require(funds <= s.remainingBalance, "Not enough balance in stream");
        s.remainingBalance -= funds;

        IERC20(s.token).transfer(s.recipient, funds);

        emit WithdrawFromStream(streamId, s.recipient, funds);
        return true;
    }

    function cancelStream(uint256 streamId) external override returns (bool) {
        Stream storage s = streams[streamId];
        require(s.sender != address(0), "Stream doesn't exist");
        // For simplicity, anyone can cancel in this mock. Adjust as needed.

        uint256 senderBalance = s.remainingBalance; // in a real implementation, you'd compute actual vested amounts
        uint256 recipientBalance = 0;

        s.remainingBalance = 0;

        IERC20(s.token).transfer(s.sender, senderBalance);

        emit CancelStream(streamId, s.sender, s.recipient, senderBalance, recipientBalance);
        return true;
    }

    function balanceOf(uint256 streamId, address who) external view override returns (uint256) {
        Stream memory s = streams[streamId];
        // In a real scenario, you'd calculate the actual vested, but we'll just do a naive approach
        if (who == s.recipient) {
            return s.remainingBalance;
        }
        return 0;
    }

    function getStream(uint256 streamId)
        external
        view
        override
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            address token,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        )
    {
        Stream memory s = streams[streamId];
        return (
            s.sender,
            s.recipient,
            s.deposit,
            s.token,
            s.startTime,
            s.stopTime,
            s.remainingBalance,
            s.ratePerSecond
        );
    }
}
