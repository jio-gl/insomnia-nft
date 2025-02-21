// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "sablier/packages/protocol/contracts/interfaces/ISablier.sol";

import {InsomniaToken} from "./InsomniaToken.sol";

contract InsomniaNFT is ERC721Enumerable, Ownable {
    // Merkle roots for different phases
    bytes32 public phase1MerkleRoot;
    bytes32 public phase2MerkleRoot;

    // Payment token
    InsomniaToken public paymentToken;

    // Example pricing
    uint256 public discountPrice = 10 ether;
    uint256 public fullPrice = 20 ether;

    // Tracks minted supply
    uint256 public tokenCounter;

    ISablier public sablier;
    uint256 public vestingStreamId;
    uint256 public vestingEndTime;

    constructor(
        string memory name_,
        string memory symbol_,
        address paymentTokenAddress,
        address sablierAddress
    )
        ERC721(name_, symbol_)
        ERC721Enumerable()
        Ownable(msg.sender) // Ensure we pass the owner here
    {
        paymentToken = InsomniaToken(paymentTokenAddress);
        sablier = ISablier(sablierAddress);
    }

    // ==============================
    // New Functions
    // ==============================
    
    /**
     * @dev Sets the Merkle root for phase 1 (only owner can call).
     */
    function setPhase1MerkleRoot(bytes32 _root) external onlyOwner {
        phase1MerkleRoot = _root;
    }

    /**
     * @dev Sets the Merkle root for phase 2 (only owner can call).
     */
    function setPhase2MerkleRoot(bytes32 _root) external onlyOwner {
        phase2MerkleRoot = _root;
    }

    // Phase 1: Whitelisted free mint
    function mintPhase1(bytes32[] calldata proof) external {
        require(
            isValidMerkleProof(proof, phase1MerkleRoot, msg.sender),
            "Invalid Merkle proof for Phase 1"
        );
        _safeMint(msg.sender, tokenCounter++);
    }

    // Phase 2: Discounted mint (requires signature check)
    function mintPhase2(bytes32[] calldata proof, bytes calldata ownerSignature) external {
        require(
            isValidMerkleProof(proof, phase2MerkleRoot, msg.sender),
            "Invalid Merkle proof for Phase 2"
        );
        require(isValidSignature(ownerSignature), "Invalid signature from owner");

        // Transfer discounted mint fee from user to contract
        paymentToken.transferFrom(msg.sender, address(this), discountPrice);

        _safeMint(msg.sender, tokenCounter++);
    }

    // Phase 3: Public mint
    function mintPhase3() external {
        // Transfer full mint fee from user to contract
        paymentToken.transferFrom(msg.sender, address(this), fullPrice);

        _safeMint(msg.sender, tokenCounter++);
    }

    // ==============================
    // SABLIER VESTING
    // ==============================
    /**
     * @notice Lock minted fees into a linear vesting schedule for one year on Sablier.
     */
    function createVestingStream() external onlyOwner {
        require(vestingStreamId == 0, "Stream already created");

        // The entire balance of `paymentToken` in this contract will be vested
        uint256 deposit = paymentToken.balanceOf(address(this));
        require(deposit > 0, "No tokens to vest");

        // Approve sablier to pull these tokens
        paymentToken.approve(address(sablier), deposit);

        // Create the stream from now until one year from now
        uint256 startTime = block.timestamp;
        uint256 stopTime = block.timestamp + 365 days;

        // According to the provided ISablier interface:
        // createStream(address recipient, uint256 deposit, address tokenAddress, uint256 startTime, uint256 stopTime)
        vestingStreamId = sablier.createStream(
            owner(),     // recipient
            deposit,     // deposit
            address(paymentToken), 
            startTime,
            stopTime
        );
    }

    // Optionally, if you want to let the owner withdraw early from the stream:
    function ownerWithdrawFromStream(uint256 streamId, uint256 funds) external onlyOwner {
        sablier.withdrawFromStream(streamId, funds);
    }
    
    // ==============================
    // HELPER FUNCTIONS
    // ==============================
    function isValidMerkleProof(bytes32[] calldata proof, bytes32 root, address account)
        internal
        pure
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, root, leaf);
    }

    // Marked as 'pure' because we do not currently use 'signature'
    function isValidSignature(bytes calldata /* signature */) 
        internal 
        pure 
        returns (bool) 
    {
        // In actual implementation, you'd verify the signature properly
        return true;
    }
}
