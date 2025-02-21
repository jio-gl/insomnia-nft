# Insomnia NFT

## Description

This repository demonstrates a **Multi-Utility NFT contract** with:
1. **Phased Minting** (using Merkle Proofs).
2. **Discount Verification** with Signatures.
3. **Vesting Integration** (Sablier).
4. **Security Best Practices**.
5. A **Foundry Test Suite** (target: 80%+ Coverage).

## File Overview

- **src/InsomniaNFT.sol**  
  Main NFT contract implementing:
  - Phased minting (phase 1: free for whitelisted users, phase 2: discounted, phase 3: open to all).
  - Merkle proof verification.
  - Signature checking for discount eligibility.
  - Sablier vesting integration for mint fees.

- **src/InsomniaToken.sol**  
  ERC20 token used for mint payments.

- **test/**  
  Foundry test contracts covering:
  - Minting phases.
  - Merkle proof correctness.
  - Signature validation.
  - Vesting logic (Sablier).
  - Additional edge cases.

- **script/Deploy.s.sol**  
  A sample Foundry script to deploy both the ERC20 token and NFT contract on a chain.

## Getting Started

1. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone** the repository:
   ```bash
   git clone <REPO_LINK>
   cd insomnia-nft
   ```

3. **Install Dependencies**:
   ```bash
   forge install
   ```
   - This will download the required packages, including OpenZeppelin and Sablier (if configured).

4. **Build & Test**:
   ```bash
   forge build
   forge test
   ```

## Coverage

To generate the coverage report, make sure you have [llvm-cov or related requirements](https://book.getfoundry.sh/forge/commands#forge-coverage) installed, then run:
```bash
forge coverage
```
Your goal is to achieve **80% or higher** overall coverage.

## Security

The contract is designed with **security in mind**, addressing:
- **Reentrancy** protection (e.g., checks-effects-interactions, or modifiers like `nonReentrant` if needed).
- **Signature validation** (to ensure discounted minting can’t be exploited).
- **Merkle proof checks** (preventing unauthorized mints).
- **Access control** using `Ownable` (limit certain functions to the contract owner).
- **Input validation** and revert conditions.

## License

This project is licensed under the [MIT License](./LICENSE.md). Feel free to use it as a reference or baseline for your own projects.
