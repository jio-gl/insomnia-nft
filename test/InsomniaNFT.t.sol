// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import "../src/InsomniaNFT.sol";
import "../src/InsomniaToken.sol";
import "./MockSablier.sol";

contract InsomniaNFTTest is Test {
    InsomniaNFT internal nft;
    InsomniaToken internal token;
    MockSablier internal mockSablier;

    // Test addresses
    address internal owner;
    address internal alice;
    address internal bob; // Another test user

    // Example Merkle roots for phases
    bytes32 internal phase1Root; 
    bytes32 internal phase2Root;

    // For signature testing
    uint256 internal ownerPrivateKey;  

    function setUp() public {
        // -------------------------
        // 1) Setup addresses
        // -------------------------
        ownerPrivateKey = 0xA11CE; // Example private key - do not use in production!
        owner = vm.addr(ownerPrivateKey);
        alice = address(0x1234);
        bob   = address(0x5678);

        // Label addresses in Foundry's traces for readability
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob,   "Bob");

        // -------------------------
        // 2) Deploy Payment Token
        // -------------------------
        vm.startPrank(owner); // We impersonate the owner for deployments
        token = new InsomniaToken("Token", "IPX", 1_000_000 ether);

        // -------------------------
        // 3) Deploy MockSablier
        // -------------------------
        mockSablier = new MockSablier();

        // -------------------------
        // 4) Deploy NFT contract
        // -------------------------
        nft = new InsomniaNFT(
            "InsomniaNFT",
            "IIN",
            address(token),
            address(mockSablier)
        );
        vm.stopPrank();

        // -------------------------------------------------------------
        // 5) Setup a Phase 1 Merkle Tree (only Alice is whitelisted)
        // -------------------------------------------------------------
        bytes32[] memory leavesPhase1 = new bytes32[](1);
        leavesPhase1[0] = keccak256(abi.encodePacked(alice));
        phase1Root = leavesPhase1[0]; // single-leaf root

        // -------------------------------------------------------------
        // 6) Setup a Phase 2 Merkle Tree (Alice + Bob are whitelisted)
        // -------------------------------------------------------------
        bytes32[] memory leavesPhase2 = new bytes32[](2);
        leavesPhase2[0] = keccak256(abi.encodePacked(alice));
        leavesPhase2[1] = keccak256(abi.encodePacked(bob));

        // Sort them if needed
        if (leavesPhase2[0] > leavesPhase2[1]) {
            (leavesPhase2[0], leavesPhase2[1]) = (leavesPhase2[1], leavesPhase2[0]);
        }
        phase2Root = keccak256(abi.encodePacked(leavesPhase2[0], leavesPhase2[1]));

        // 7) Set the roots as the owner
        vm.prank(owner);
        nft.setPhase1MerkleRoot(phase1Root);
        vm.prank(owner);
        nft.setPhase2MerkleRoot(phase2Root);
    }

    // ------------------------------------------
    // PHASE 1 TEST
    // ------------------------------------------
    function testMintPhase1() public {
        // Alice should be able to mint for free with a valid proof
        bytes32[] memory aliceProof = _buildSingleLeafProof(alice, phase1Root);

        // Impersonate Alice
        vm.startPrank(alice);

        // Since Phase 1 is free, no token transfer is needed
        nft.mintPhase1(aliceProof);

        vm.stopPrank();

        // Check that Alice received NFT #0
        assertEq(nft.ownerOf(0), alice, "Alice should own token ID 0");
        assertEq(nft.balanceOf(alice), 1, "Alice should have 1 NFT");
    }

    // ------------------------------------------
    // PHASE 2 TEST
    // ------------------------------------------
    function testMintPhase2() public {
        bytes32[] memory aliceProof = _buildTwoLeafProof(alice, phase2Root);
        bytes memory sig = _signDiscountMessage(ownerPrivateKey, alice);

        // Give Alice some tokens
        vm.startPrank(owner);
        token.transfer(alice, 100 ether);
        vm.stopPrank();

        // Approve the NFT contract to pull the discount payment
        vm.startPrank(alice);
        token.approve(address(nft), 100 ether);
        nft.mintPhase2(aliceProof, sig);
        vm.stopPrank();

        // Verify result
        assertEq(nft.ownerOf(0), alice, "Alice should own token 0");
        assertEq(token.balanceOf(address(nft)), 10 ether, "NFT contract should have 10 tokens");
    }

    // ------------------------------------------
    // PHASE 3 TEST
    // ------------------------------------------
    function testMintPhase3() public {
        // Bob tries to mint in Phase 3
        uint256 fullPrice = nft.fullPrice();

        // Ensure Bob has enough tokens
        vm.startPrank(owner);
        token.transfer(bob, 100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(nft), 100 ether);

        // Mint
        nft.mintPhase3();
        vm.stopPrank();

        // Verify
        assertEq(nft.ownerOf(0), bob, "Bob should own token 0");
        assertEq(token.balanceOf(address(nft)), 20 ether, "NFT contract should have 20 tokens");
    }

    // ------------------------------------------
    // VESTING TEST
    // ------------------------------------------
    function testCreateVestingStream() public {
        // 1) Give the NFT contract some tokens to simulate minted fees.
        //    Here, we transfer 200 tokens from `owner` to the NFT contract.
        vm.startPrank(owner);
        token.transfer(address(nft), 200 ether); 
        vm.stopPrank();

        // Verify the NFT contract now holds 200 tokens
        assertEq(token.balanceOf(address(nft)), 200 ether, "NFT contract should have 200 tokens");

        // 2) Create the vesting stream as the owner.
        vm.prank(owner);
        nft.createVestingStream();

        // All 200 tokens should now be in the Sablier (mock) contract, leaving the NFT contract with zero.
        assertEq(token.balanceOf(address(nft)), 0, "NFT contract should have 0 after vesting stream creation");
        assertEq(token.balanceOf(address(mockSablier)), 200 ether, "Sablier mock should have 200 tokens");

        // Grab the streamId from the NFT contract.
        uint256 streamId = nft.vestingStreamId();
        assertTrue(streamId > 0, "streamId should be set to a valid ID");

        // 3) Check the stream details via the mock Sablier's getStream(...) function.
        (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddr,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        ) = mockSablier.getStream(streamId);

        // Verify basic correctness of the stream data
        assertEq(sender, address(nft), "NFT contract should be the sender");
        assertEq(recipient, owner, "Owner should be the recipient");
        assertEq(deposit, 200 ether, "Deposit should be 200 tokens");
        assertEq(tokenAddr, address(token), "Stream should be using our payment token");
        assertEq(remainingBalance, 200 ether, "All 200 tokens are locked in the stream");
        // We won't do an exact check on ratePerSecond or block timestamps unless we want more granularity.

        // 4) (Optional) Withdraw partial amount from the stream as the owner.
        //    We'll measure the difference in the owner's balance to ensure exactly 50 tokens were gained.
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        vm.startPrank(owner);
        mockSablier.withdrawFromStream(streamId, 50 ether);
        vm.stopPrank();
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 increase = ownerBalanceAfter - ownerBalanceBefore;

        // Owner should have gained exactly 50 tokens
        assertEq(increase, 50 ether, "Owner withdrew partial from the vesting stream");

        // The remaining stream balance should be 150 tokens
        (, , , , , , uint256 newRemaining, ) = mockSablier.getStream(streamId);
        assertEq(newRemaining, 150 ether, "Stream now has 150 tokens left");
    }

    // ==========================================
    // HELPER FUNCTIONS
    // ==========================================

    /**
     * @dev Builds a trivial Merkle proof for a single-leaf tree (phase1).
     *      For a 1-leaf tree, the proof is empty, but we still pass an empty array.
     */
    function _buildSingleLeafProof(address _account, bytes32 root)
        internal
        pure
        returns (bytes32[] memory)
    {
        // If your leaf is the root, there's no sibling. 
        // For demonstration, we just return an empty array. 
        bytes32[] memory proof = new bytes32[](0);
        require(
            keccak256(abi.encodePacked(_account)) == root,
            "Invalid root for single-leaf tree"
        );
        return proof;
    }

    /**
     * @dev Builds a "Merkle proof" for the 2-leaf scenario (phase2). 
     *      This is a naive approach. 
     *      In production, you'd generate an actual proof off-chain.
     */
    function _buildTwoLeafProof(address _account, bytes32 root)
        internal
        view
        returns (bytes32[] memory)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_account));
        bytes32[] memory proof = new bytes32[](1);

        proof[0] = (leaf == keccak256(abi.encodePacked(alice)))
            ? keccak256(abi.encodePacked(bob))
            : keccak256(abi.encodePacked(alice));
        
        // You could verify root or do extra checks here, but this is a simple example
        return proof;
    }

    /**
     * @dev Mocks discount signature creation. In a real scenario, you'd
     *      use EIP-712 or sign a specific message. 
     */
    function _signDiscountMessage(uint256 _privateKey, address _minter)
        internal
        returns (bytes memory)
    {
        // 1) Create message hash
        bytes32 msgHash = keccak256(abi.encodePacked("DISCOUNT", _minter));

        // 2) Sign it with Foundry's vm.sign() 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, msgHash);

        // 3) Encode signature
        return abi.encodePacked(r, s, v);
    }
}
