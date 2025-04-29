# BlockchainGambit: On-Chain Chess

## Abstract

This project implements a functional, minimalistic two-player chess game entirely on the blockchain using Solidity and Foundry. It focuses on minimizing storage costs by employing a highly compressed 256-bit representation for the complete game state, including piece positions, turn, castling rights, and en passant availability. All standard chess moves, including special cases like castling and en passant, are validated directly within the smart contract, ensuring rule adherence without external oracles. The system enforces player turns and detects checkmate and stalemate conditions, providing a verifiable and decentralized platform for chess gameplay.

## Background/Motivation

Traditional online chess platforms rely on centralized servers to manage game state and enforce rules. This introduces points of failure and requires trusting the platform operator. Blockchain technology offers an alternative by enabling decentralized applications. The motivations for building an on-chain chess game include:

-   **Decentralized Arbiter:** The smart contract itself acts as an impartial referee, enforcing the rules of chess transparently and automatically. There is no need for a central authority to validate moves or determine outcomes.
-   **Trustlessness:** Players do not need to trust each other or a third-party platform. The game's logic is encoded in immutable smart contracts, and the game state is recorded publicly on the blockchain.
-   **Verifiable Results:** Every move and the final outcome of the game are permanently recorded and publicly verifiable on the blockchain ledger.
-   **Accessibility:** Anyone with a blockchain wallet can potentially interact with the contract to play games, removing reliance on specific platform accounts.
-   **Exploration of Efficiency:** Pushing the boundaries of on-chain computation by implementing complex game logic like chess move validation within the constraints of blockchain environments (e.g., gas costs).

## Methods

The core of the project lies in its efficient state management and on-chain validation:

-   **Compressed State Representation:** The entire essential game state is encoded into a single `uint256` (256 bits). This is achieved by assigning 4 bits to each of the 64 squares on the chessboard. These 4 bits represent the piece type and color, or special states like an unmoved king/rook (for castling) or a pawn that just moved two squares (for en passant).
    -   **Piece Encoding:** Specific 4-bit IDs are assigned to each piece type and color (e.g., White Pawn, Black Knight). Special IDs (like `UNMOVED_KING_OR_ROOK`, `JUST_DOUBLE_MOVED_PAWN`, `KING_TO_MOVE`) are used to implicitly track castling rights, en passant targets, and the current player's turn without requiring separate storage slots. See `src/ChessLogic.sol` comments for the full encoding scheme.
    -   **Implicit State:** Castling rights are derived by checking for `UNMOVED_KING_OR_ROOK` on their starting squares. The en passant target square is derived from the position of a `JUST_DOUBLE_MOVED_PAWN`. The player turn is determined by locating the `KING_TO_MOVE` piece.
-   **On-Chain Validation:** The `ChessLogic.sol` library contains functions to decode the state, validate move legality (including piece movement rules, captures, check constraints, castling, en passant, promotion), apply valid moves, and re-encode the state. Crucially, it checks if a move leaves the player's own king in check.
-   **Game Management:** The main `Chess.sol` contract manages game creation between two players, stores the `uint256` state for each game, enforces turn-based interaction based on the decoded state and player addresses, and updates the game status upon checkmate or stalemate detection.
-   **Development Stack:** The project is built using the Foundry framework for Solidity development, testing, and deployment scripting.

## Results

The project successfully implements a playable on-chain chess game with the following features:

-   **Compact Storage:** Achieved the goal of storing the game state within a single `uint256`.
-   **Full Move Validation:** Supports and validates all standard chess moves, including castling, en passant, and pawn promotion, directly on-chain.
-   **Turn Enforcement:** Correctly enforces alternating turns between the two registered players.
-   **Endgame Detection:** Implements logic to detect checkmate and stalemate conditions, automatically ending the game and setting the appropriate status.
-   **Two-Player Interaction:** Allows users to initiate games against specific opponents.

**Excluded Features (Limitations):**

Due to complexity and gas cost considerations, the following features were explicitly excluded:

-   Time controls and game clocks.
-   50-move rule tracking.
-   3-fold repetition detection.
-   Integration with chess engines for analysis or AI opponents.

While the move validation logic is comprehensive, executing it fully on-chain (especially checkmate/stalemate detection which requires evaluating all potential moves) can be computationally intensive and may incur significant gas costs, making Layer 2 solutions a more practical deployment target for frequent use.

## Development

This project uses Foundry.

**Build:**
```bash
forge build
```

**Test:**
```bash
forge test
```

**Format:**
```bash
forge fmt
```

**Deploy (Script):**
```bash
forge script script/Chess.s.sol:ChessScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```