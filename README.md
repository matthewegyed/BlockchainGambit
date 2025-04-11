# BlockchainGambit
# On-Chain Chess

This project implements a minimalistic chess game on the blockchain using Solidity and Foundry.

## Goals

-   **Minimize Storage:** Utilize a highly compressed 256-bit representation for the entire board state, including piece positions, side to move, castling rights, and en passant availability.
-   **On-Chain Validation:** Ensure all moves made are validated against standard chess rules directly within the smart contract.
-   **Two-Player Gameplay:** Allow users to start games against specific opponents, with turn-based progression enforced.
-   **Efficiency:** Optimize computations for potential L2 deployment, although full move validation remains computationally intensive.

## Features

-   Stores the entire game state (excluding 50-move/repetition history) in a single `uint256`.
-   Supports all standard chess moves including castling and en passant.
-   Enforces player turns.
-   Validates move legality on-chain.
-   Detects checkmate and stalemate conditions.

## Excluded Features (for now)

-   Time controls.
-   50-move rule tracking.
-   3-fold repetition detection.
-   Game clocks or timers.
-   Chess engine evaluation.

## Compressed State Representation

See the comments within `src/Chess.sol` for the detailed 4-bit encoding scheme used to represent the 64 squares within the 256-bit state.

## Development

This project uses Foundry.

**Build:**
forge build

**Test:**
forge test

**Format:**
forge fmt

**Deploy (Script):**
forge script script/Chess.s.sol:ChessScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast


