// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChessLogic Library
 * @notice Handles the core logic for chess game state manipulation and move validation
 *         based on a compact 256-bit encoding.
 * @dev Uses a fixed-size 256-bit integer to represent the entire board state,
 *      including piece positions, castling rights, en passant target, and side to move.
 *      Encoding details: 64 squares, 4 bits per square (0=a1, 63=h8).
 *      Piece IDs:
 *      0: EMPTY
 *      1: W_PAWN
 *      2: B_PAWN
 *      13: JUST_DOUBLE_MOVED_PAWN (Color inferred: rank 3 = White pawn on 4th, rank 4 = Black pawn on 5th)
 *      3: W_KNIGHT
 *      4: B_KNIGHT
 *      5: W_BISHOP
 *      6: B_BISHOP
 *      7: W_ROOK (Moved or standard)
 *      8: B_ROOK (Moved or standard)
 *      9: W_QUEEN
 *      10: B_QUEEN
 *      11: W_KING (Moved or standard)
 *      12: B_KING (Moved or standard)
 *      14: KING_TO_MOVE (The king whose side's turn it is)
 *      15: UNMOVED_KING_OR_ROOK (Identity determined by initial square: e1/e8=K, a1/h1/a8/h8=R)
 *
 *      Castling rights are implicitly determined by the presence of UNMOVED_KING_OR_ROOK (15)
 *      on the respective king and rook starting squares (e1, a1, h1, e8, a8, h8).
 *      En passant target square is implicitly determined by the location of
 *      JUST_DOUBLE_MOVED_PAWN (13). Rank 3 means white pawn just moved, target square is rank 2.
 *      Rank 4 means black pawn just moved, target square is rank 5.
 *      Turn is determined by finding KING_TO_MOVE (14) and seeing if the other king is W_KING (11) or B_KING (12).
 */
library ChessLogic {
    // --- Piece Constants ---
    uint8 public constant EMPTY = 0;
    uint8 public constant W_PAWN = 1;
    uint8 public constant B_PAWN = 2;
    uint8 public constant W_KNIGHT = 3;
    uint8 public constant B_KNIGHT = 4;
    uint8 public constant W_BISHOP = 5;
    uint8 public constant B_BISHOP = 6;
    uint8 public constant W_ROOK = 7;
    uint8 public constant B_ROOK = 8;
    uint8 public constant W_QUEEN = 9;
    uint8 public constant B_QUEEN = 10;
    uint8 public constant W_KING = 11;
    uint8 public constant B_KING = 12;
    uint8 public constant JUST_DOUBLE_MOVED_PAWN = 13;
    uint8 public constant KING_TO_MOVE = 14;
    uint8 public constant UNMOVED_KING_OR_ROOK = 15;

    uint8 public constant SQUARE_MASK = 0xF;
    uint8 public constant BOARD_SIZE = 64;
    uint8 public constant WHITE = 0;
    uint8 public constant BLACK = 1;

    // Standard square indices
    uint8 constant A1 = 0;
    uint8 constant B1 = 1;
    uint8 constant C1 = 2;
    uint8 constant D1 = 3;
    uint8 constant E1 = 4;
    uint8 constant F1 = 5;
    uint8 constant G1 = 6;
    uint8 constant H1 = 7;
    uint8 constant A8 = 56;
    uint8 constant B8 = 57;
    uint8 constant C8 = 58;
    uint8 constant D8 = 59;
    uint8 constant E8 = 60;
    uint8 constant F8 = 61;
    uint8 constant G8 = 62;
    uint8 constant H8 = 63;

    // --- Errors ---
    error InvalidMove();
    error NotYourTurn();
    error PieceNotFound();
    error MoveLeavesKingInCheck();
    error InvalidPromotion();
    error InvalidEncoding();
    error InvalidSquare();

    // --- Decoded State Struct ---
    struct DecodedState {
        uint8[BOARD_SIZE] board;
        uint8 turn;
        int16 enPassantTargetSquare;
        bool whiteKingsideCastle;
        bool whiteQueensideCastle;
        bool blackKingsideCastle;
        bool blackQueensideCastle;
        uint8 whiteKingSquare;
        uint8 blackKingSquare;
    }

    // --- Core Functions ---

    /**
     * @notice Decodes the compact 256-bit state into a usable struct.
     * @param encodedState The uint256 representing the game state.
     * @return state The decoded game state struct.
     */
    function decode(
        uint256 encodedState
    ) internal pure returns (DecodedState memory state) {
        state.enPassantTargetSquare = -1; // Default: no en passant
        uint8 kingToMoveSquare = 255; // Sentinel value
        uint8 otherKingSquare = 255; // Sentinel value
        uint8 otherKingId = EMPTY;
        state.whiteKingSquare = 255; // Sentinel value
        state.blackKingSquare = 255; // Sentinel value

        // 1. Decode board, find kings, special pawns, and determine EP target
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            uint8 pieceId = uint8((encodedState >> (i * 4)) & SQUARE_MASK);
            state.board[i] = pieceId;

            // Identify En Passant Target Square based on JUST_DOUBLE_MOVED_PAWN location
            if (pieceId == JUST_DOUBLE_MOVED_PAWN) {
                uint8 rank = i / 8; // Rank where the pawn LANDED (0-indexed)
                if (rank == 3) {
                    // White pawn just moved e2-e4 (landed on 4th rank), target is behind it (3rd rank)
                    state.enPassantTargetSquare = int16(uint16(i - 8)); // e.g., if pawn on e4 (28), target is e3 (20)
                } else if (rank == 4) {
                    // Black pawn just moved e7-e5 (landed on 5th rank), target is behind it (6th rank)
                    state.enPassantTargetSquare = int16(uint16(i + 8)); // e.g., if pawn on d5 (35), target is d6 (43)
                } else {
                    // This indicates an invalid encoding (ID 13 on wrong rank)
                    revert InvalidEncoding();
                }
            }

            // Locate Kings - Initial Pass
            if (pieceId == KING_TO_MOVE) {
                kingToMoveSquare = i;
            } else if (pieceId == W_KING) {
                otherKingSquare = i;
                otherKingId = pieceId;
                state.whiteKingSquare = i;
            } else if (pieceId == B_KING) {
                otherKingSquare = i;
                otherKingId = pieceId;
                state.blackKingSquare = i;
            } else if (pieceId == UNMOVED_KING_OR_ROOK) {
                // If an unmoved piece is on a king start square, store it temporarily
                if (i == E1) state.whiteKingSquare = i;
                else if (i == E8) state.blackKingSquare = i;
            }
        }

        // 2. Determine whose turn it is based on King IDs
        if (kingToMoveSquare == 255) {
            // KING_TO_MOVE ID (14) wasn't found. This should only happen in the initial state
            // Let's re-verify king positions and IDs for robustness.
            state.whiteKingSquare = 255; // Reset sentinels
            state.blackKingSquare = 255;
            for (uint8 i = 0; i < BOARD_SIZE; i++) {
                uint8 pid = state.board[i];
                if (pid == W_KING || (pid == UNMOVED_KING_OR_ROOK && i == E1))
                    state.whiteKingSquare = i;
                else if (
                    pid == B_KING || (pid == UNMOVED_KING_OR_ROOK && i == E8)
                ) state.blackKingSquare = i;
                else if (pid == KING_TO_MOVE) kingToMoveSquare = i; // Found it after all?
            }

            if (kingToMoveSquare != 255) {
                // KING_TO_MOVE was found, proceed as in the 'else' block below
                if (kingToMoveSquare == state.whiteKingSquare) {
                    state.turn = WHITE;
                    if (state.blackKingSquare == 255) revert InvalidEncoding(); // Missing black king
                } else if (kingToMoveSquare == state.blackKingSquare) {
                    state.turn = BLACK;
                    if (state.whiteKingSquare == 255) revert InvalidEncoding(); // Missing white king
                } else {
                    revert InvalidEncoding(); // KING_TO_MOVE not on a king square
                }
            } else {
                // KING_TO_MOVE truly not found. Check if it's the initial state.
                if (
                    state.board[E1] == KING_TO_MOVE && state.board[E8] == B_KING
                ) {
                    state.turn = WHITE;
                    state.whiteKingSquare = E1;
                    state.blackKingSquare = E8;
                } else {
                    // Not initial state and KING_TO_MOVE missing -> error
                    revert InvalidEncoding();
                }
            }
        } else {
            // KING_TO_MOVE (14) was found directly
            // Find the other king (ID 11 or 12 or 15 on start square)
            state.whiteKingSquare = 255; // Reset sentinels
            state.blackKingSquare = 255;
            for (uint8 i = 0; i < BOARD_SIZE; i++) {
                uint8 pid = state.board[i];
                if (pid == W_KING || (pid == UNMOVED_KING_OR_ROOK && i == E1)) {
                    state.whiteKingSquare = i;
                    otherKingId = W_KING; // Treat unmoved as W_KING for turn logic
                } else if (
                    pid == B_KING || (pid == UNMOVED_KING_OR_ROOK && i == E8)
                ) {
                    state.blackKingSquare = i;
                    otherKingId = B_KING; // Treat unmoved as B_KING for turn logic
                }
            }

            // Now assign the kingToMoveSquare to the correct color based on the *other* king found
            if (otherKingId == W_KING) {
                // The standard/unmoved king is White, so KING_TO_MOVE (14) must be Black
                state.turn = BLACK;
                state.blackKingSquare = kingToMoveSquare; // Correct the black king square
                if (state.whiteKingSquare == 255) revert InvalidEncoding(); // White king missing
            } else if (otherKingId == B_KING) {
                // The standard/unmoved king is Black, so KING_TO_MOVE (14) must be White
                state.turn = WHITE;
                state.whiteKingSquare = kingToMoveSquare; // Correct the white king square
                if (state.blackKingSquare == 255) revert InvalidEncoding(); // Black king missing
            } else {
                // This implies only KING_TO_MOVE was found, and no other king ID (11, 12, or 15 on start sq)
                revert InvalidEncoding(); // Could not determine turn / missing other king
            }
        }

        // 3. Determine Castling Rights based on UNMOVED pieces on STARTING squares
        // White Kingside: UNMOVED King on e1 AND UNMOVED Rook on h1
        state.whiteKingsideCastle =
            state.board[E1] == UNMOVED_KING_OR_ROOK &&
            state.board[H1] == UNMOVED_KING_OR_ROOK;
        // White Queenside: UNMOVED King on e1 AND UNMOVED Rook on a1
        state.whiteQueensideCastle =
            state.board[E1] == UNMOVED_KING_OR_ROOK &&
            state.board[A1] == UNMOVED_KING_OR_ROOK;
        // Black Kingside: UNMOVED King on e8 AND UNMOVED Rook on h8
        state.blackKingsideCastle =
            state.board[E8] == UNMOVED_KING_OR_ROOK &&
            state.board[H8] == UNMOVED_KING_OR_ROOK;
        // Black Queenside: UNMOVED King on e8 AND UNMOVED Rook on a8
        state.blackQueensideCastle =
            state.board[E8] == UNMOVED_KING_OR_ROOK &&
            state.board[A8] == UNMOVED_KING_OR_ROOK;

        // Final check for king positions (redundant if above logic is perfect, but safe)
        if (state.whiteKingSquare == 255 || state.blackKingSquare == 255) {
            revert InvalidEncoding(); // Failed to locate both kings
        }
    }

    /**
     * @notice Encodes a decoded state back into the compact 256-bit integer.
     * @param state The decoded game state struct.
     * @return encodedState The uint256 representing the game state.
     */
    function encode(
        DecodedState memory state
    ) internal pure returns (uint256 encodedState) {
        encodedState = 0;
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            encodedState |= uint256(state.board[i]) << (i * 4);
        }
    }

    /**
     * @notice Gets the initial board state encoded as uint256.
     */
    function getInitialState() internal pure returns (uint256) {
        uint256 encodedState = 0;

        // Place UNMOVED Rooks and King placeholders first (ID 15)
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (A1 * 4); // a1
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (H1 * 4); // h1
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (E1 * 4); // e1 (placeholder)
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (A8 * 4); // a8
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (H8 * 4); // h8
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (E8 * 4); // e8 (placeholder)

        // Knights
        encodedState |= uint256(W_KNIGHT) << (B1 * 4);
        encodedState |= uint256(W_KNIGHT) << (G1 * 4);
        encodedState |= uint256(B_KNIGHT) << (B8 * 4);
        encodedState |= uint256(B_KNIGHT) << (G8 * 4);
        // Bishops
        encodedState |= uint256(W_BISHOP) << (C1 * 4);
        encodedState |= uint256(W_BISHOP) << (F1 * 4);
        encodedState |= uint256(B_BISHOP) << (C8 * 4);
        encodedState |= uint256(B_BISHOP) << (F8 * 4);
        // Queens
        encodedState |= uint256(W_QUEEN) << (D1 * 4);
        encodedState |= uint256(B_QUEEN) << (D8 * 4);

        // Pawns
        for (uint8 i = 8; i < 16; i++) {
            encodedState |= uint256(W_PAWN) << (i * 4);
        } // Rank 2
        for (uint8 i = 48; i < 56; i++) {
            encodedState |= uint256(B_PAWN) << (i * 4);
        } // Rank 7

        // Manually set correct King IDs for turn (White moves first)
        // Clear e1 (square 4) and e8 (square 60) placeholders first
        encodedState &= ~(SQUARE_MASK << (E1 * 4));
        encodedState &= ~(SQUARE_MASK << (E8 * 4));
        // Set White King to KING_TO_MOVE (14) on e1
        encodedState |= uint256(KING_TO_MOVE) << (E1 * 4);
        // Set Black King to B_KING (12) on e8
        encodedState |= uint256(B_KING) << (E8 * 4);

        return encodedState;
    }

    /**
     * @notice Processes a move, validates it fully, and returns the new encoded state.
     * @param encodedState Current state.
     * @param fromSquare Source square index (0-63).
     * @param toSquare Destination square index (0-63).
     * @param promotionPieceType Piece ID to promote pawn to (e.g., W_QUEEN), or EMPTY (0).
     * @param playerColor The color of the player making the move (WHITE or BLACK).
     * @return newEncodedState The state after the move.
     */
    function processMove(
        uint256 encodedState,
        uint8 fromSquare,
        uint8 toSquare,
        uint8 promotionPieceType,
        uint8 playerColor
    ) internal pure returns (uint256 newEncodedState) {
        // 1. Decode current state
        DecodedState memory state = decode(encodedState);

        // 2. Check turn
        if (state.turn != playerColor) {
            revert NotYourTurn();
        }

        // 3. Basic validation & Get Piece
        if (
            fromSquare >= BOARD_SIZE ||
            toSquare >= BOARD_SIZE ||
            fromSquare == toSquare
        ) {
            revert InvalidSquare();
        }
        uint8 pieceId = state.board[fromSquare];
        if (
            pieceId == EMPTY || getColor(state.board, fromSquare) != playerColor
        ) {
            revert InvalidMove(); // Trying to move empty square or opponent's piece
        }

        // 4. Check move pseudo-legality (geometry, captures, special move rules)
        if (
            !isMovePseudoLegal(state, fromSquare, toSquare, promotionPieceType)
        ) {
            revert InvalidMove();
        }

        // 5. Simulate the move to get the potential next board state
        DecodedState memory nextState = applyMove(
            state,
            fromSquare,
            toSquare,
            promotionPieceType
        );

        // 6. Check if the player's own king is in check *after* the simulated move
        uint8 kingSquareToCheck = (playerColor == WHITE)
            ? nextState.whiteKingSquare
            : nextState.blackKingSquare;
        if (
            isSquareAttacked(
                nextState.board,
                kingSquareToCheck,
                1 - playerColor
            )
        ) {
            // Check if attacked by opponent
            revert MoveLeavesKingInCheck();
        }

        // 7. Clear any JUST_DOUBLE_MOVED_PAWN from the *previous* turn.
        clearJustDoubleMovedPawn(nextState.board);

        // 8. Set JUST_DOUBLE_MOVED_PAWN if this move was a pawn double step
        uint8 movedBaseType = getBasePieceType(pieceId, fromSquare);
        if (movedBaseType == W_PAWN) {
            uint256 uDiff = (toSquare > fromSquare)
                ? toSquare - fromSquare
                : fromSquare - toSquare;
            if (uDiff == 16) {
                // Check for double step
                nextState.board[toSquare] = JUST_DOUBLE_MOVED_PAWN;
            }
        }

        // 9. Swap King IDs to change the turn indicator
        swapKingTurn(nextState.board, playerColor);

        // 10. Encode the final board state back to uint256
        return encode(nextState);
    }

    // --- Helper Functions ---

    /**
     * @notice Gets the color of a piece from the board
     * @param board The current board array
     * @param square The square index to check
     * @return color WHITE (0) or BLACK (1)
     */
    function getColor(
        uint8[BOARD_SIZE] memory board,
        uint8 square
    ) internal pure returns (uint8) {
        uint8 piece = board[square];

        if (piece == EMPTY) revert PieceNotFound();

        // Special handling for UNMOVED_KING_OR_ROOK based on position
        if (piece == UNMOVED_KING_OR_ROOK) {
            // Starting squares for white rooks/king
            if (square == A1 || square == E1 || square == H1) return WHITE;
            // Starting squares for black rooks/king
            if (square == A8 || square == E8 || square == H8) return BLACK;
            revert InvalidEncoding(); // UNMOVED_KING_OR_ROOK in invalid position
        }

        // Special handling for JUST_DOUBLE_MOVED_PAWN based on rank
        if (piece == JUST_DOUBLE_MOVED_PAWN) {
            uint8 rank = square / 8;
            if (rank == 3) return WHITE; // White pawn on rank 4
            if (rank == 4) return BLACK; // Black pawn on rank 5
            revert InvalidEncoding(); // JUST_DOUBLE_MOVED_PAWN in invalid position
        }

        // Special handling for KING_TO_MOVE based on position
        if (piece == KING_TO_MOVE) {
            // Need to check the decoded state to determine the turn
            // KING_TO_MOVE always represents the current player's king
            // This function is typically called after the decoded state is prepared
            // So this would be redundant, but we include it for completeness
            uint8 rank = square / 8;
            if (rank < 4) return WHITE; // King likely on bottom half of board
            return BLACK; // King likely on top half of board
        }

        // Standard pieces use even/odd pattern
        return (piece % 2 == 1) ? WHITE : BLACK;
    }

    /**
     * @notice Gets the base piece type (normalized across colors)
     * @param pieceId The piece ID
     * @param square The square where the piece is located (needed for context-dependent IDs)
     * @return baseType Basic piece type (1=Pawn, 2=Knight, etc.)
     */
    function getBasePieceType(
        uint8 pieceId,
        uint8 square
    ) internal pure returns (uint8) {
        // For UNMOVED_KING_OR_ROOK and KING_TO_MOVE, we need position context
        if (pieceId == UNMOVED_KING_OR_ROOK) {
            if (square == E1 || square == E8) return W_KING; // It's a king
            return W_ROOK; // It's a rook
        }

        if (pieceId == KING_TO_MOVE) return W_KING; // KING_TO_MOVE is a king

        if (pieceId == JUST_DOUBLE_MOVED_PAWN) return W_PAWN; // It's a pawn

        // For standard pieces, normalize by making the ID odd (white version)
        if (pieceId % 2 == 0) pieceId -= 1; // Convert black to white
        return pieceId;
    }

    /**
     * @notice Clears any JUST_DOUBLE_MOVED_PAWN from the board
     * @param board The board to modify (in-place)
     */
    function clearJustDoubleMovedPawn(
        uint8[BOARD_SIZE] memory board
    ) internal pure {
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            if (board[i] == JUST_DOUBLE_MOVED_PAWN) {
                uint8 rank = i / 8;
                board[i] = (rank == 3) ? W_PAWN : B_PAWN;
            }
        }
    }

    /**
     * @notice Swaps the king IDs to change the turn
     * @param board The board to modify (in-place)
     * @param currentColor The color that just moved
     */
    function swapKingTurn(
        uint8[BOARD_SIZE] memory board,
        uint8 currentColor
    ) internal pure {
        // Find both kings
        uint8 whiteKingSquare = 255;
        uint8 blackKingSquare = 255;
        uint8 whiteKingId = 0;
        uint8 blackKingId = 0;

        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            uint8 piece = board[i];
            if (piece == W_KING || piece == KING_TO_MOVE) {
                if (getColor(board, i) == WHITE) {
                    whiteKingSquare = i;
                    whiteKingId = piece;
                }
            } else if (piece == B_KING || piece == KING_TO_MOVE) {
                if (getColor(board, i) == BLACK) {
                    blackKingSquare = i;
                    blackKingId = piece;
                }
            } else if (piece == UNMOVED_KING_OR_ROOK) {
                if (i == E1) {
                    whiteKingSquare = i;
                    whiteKingId = piece;
                } else if (i == E8) {
                    blackKingSquare = i;
                    blackKingId = piece;
                }
            }
        }

        // Swap kings: current player's king becomes normal, opponent's becomes KING_TO_MOVE
        if (currentColor == WHITE) {
            // White just moved, black to move
            board[whiteKingSquare] = (whiteKingId == UNMOVED_KING_OR_ROOK)
                ? UNMOVED_KING_OR_ROOK
                : W_KING;
            board[blackKingSquare] = KING_TO_MOVE;
        } else {
            // Black just moved, white to move
            board[blackKingSquare] = (blackKingId == UNMOVED_KING_OR_ROOK)
                ? UNMOVED_KING_OR_ROOK
                : B_KING;
            board[whiteKingSquare] = KING_TO_MOVE;
        }
    }

    /**
     * @notice Checks if a move is pseudo-legal (follows piece rules, ignores self-check)
     */
    function isMovePseudoLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to,
        uint8 promotionPieceType
    ) internal pure returns (bool) {
        uint8 piece = state.board[from];
        uint8 targetPiece = state.board[to];
        uint8 movingColor = getColor(state.board, from);

        // Basic check: cannot capture own piece
        if (targetPiece != EMPTY && getColor(state.board, to) == movingColor) {
            return false;
        }

        // Get base type contextually for ID 15
        uint8 baseType = getBasePieceType(piece, from);

        // --- Piece Specific Logic ---
        if (baseType == W_PAWN) {
            return isPawnMoveLegal(state, from, to, promotionPieceType);
        }
        if (baseType == W_KNIGHT) {
            return isKnightMoveLegal(state, from, to);
        }
        if (baseType == W_BISHOP) {
            return isSlidingMoveLegal(state.board, from, to, true, false);
        }
        if (baseType == W_ROOK) {
            return isSlidingMoveLegal(state.board, from, to, false, true);
        }
        if (baseType == W_QUEEN) {
            return isSlidingMoveLegal(state.board, from, to, true, true);
        }
        if (baseType == W_KING) {
            return isKingMoveLegal(state, from, to);
        }

        return false;
    }

    /**
     * @notice Checks if a pawn move is legal
     */
    function isPawnMoveLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to,
        uint8 promotionPieceType
    ) internal pure returns (bool) {
        uint8 movingColor = getColor(state.board, from);
        uint256 uDiff = (to > from) ? to - from : from - to;
        bool movingForward = (movingColor == WHITE && to > from) ||
            (movingColor == BLACK && from > to);
        uint8 fromRank = from / 8;
        uint8 toRank = to / 8;
        uint8 fromFile = from % 8;
        uint8 toFile = to % 8;
        uint8 fileDiff = (toFile > fromFile)
            ? toFile - fromFile
            : fromFile - toFile;

        if (movingColor == WHITE) {
            // 1. Forward 1 square
            if (
                movingForward &&
                uDiff == 8 &&
                fileDiff == 0 &&
                state.board[to] == EMPTY
            ) {
                bool isPromotion = (toRank == 7);
                if (
                    isPromotion &&
                    !isValidPromotionPiece(WHITE, promotionPieceType)
                ) return false;
                if (!isPromotion && promotionPieceType != EMPTY) return false;
                return true;
            }
            // 2. Forward 2 squares (initial move)
            if (
                movingForward &&
                fromRank == 1 &&
                uDiff == 16 &&
                fileDiff == 0 &&
                state.board[from + 8] == EMPTY &&
                state.board[to] == EMPTY
            ) {
                return promotionPieceType == EMPTY; // Cannot promote on double move
            }
            // 3. Capture
            if (movingForward && (uDiff == 7 || uDiff == 9) && fileDiff == 1) {
                // Diagonal forward
                bool isPromotion = (toRank == 7);
                // Standard capture
                if (getColor(state.board, to) == BLACK) {
                    if (
                        isPromotion &&
                        !isValidPromotionPiece(WHITE, promotionPieceType)
                    ) return false;
                    if (!isPromotion && promotionPieceType != EMPTY)
                        return false;
                    return true;
                }
                // En passant capture
                if (to == uint8(uint16(state.enPassantTargetSquare))) {
                    return promotionPieceType == EMPTY; // Cannot promote on en passant
                }
            }
        } else {
            // BLACK pawn move
            // 1. Forward 1 square
            if (
                movingForward &&
                uDiff == 8 &&
                fileDiff == 0 &&
                state.board[to] == EMPTY
            ) {
                bool isPromotion = (toRank == 0);
                if (
                    isPromotion &&
                    !isValidPromotionPiece(BLACK, promotionPieceType)
                ) return false;
                if (!isPromotion && promotionPieceType != EMPTY) return false;
                return true;
            }
            // 2. Forward 2 squares (initial move)
            if (
                movingForward &&
                fromRank == 6 &&
                uDiff == 16 &&
                fileDiff == 0 &&
                state.board[from - 8] == EMPTY &&
                state.board[to] == EMPTY
            ) {
                return promotionPieceType == EMPTY; // Cannot promote on double move
            }
            // 3. Capture
            if (movingForward && (uDiff == 7 || uDiff == 9) && fileDiff == 1) {
                // Diagonal forward
                bool isPromotion = (toRank == 0);
                // Standard capture
                if (getColor(state.board, to) == WHITE) {
                    if (
                        isPromotion &&
                        !isValidPromotionPiece(BLACK, promotionPieceType)
                    ) return false;
                    if (!isPromotion && promotionPieceType != EMPTY)
                        return false;
                    return true;
                }
                // En passant capture
                if (to == uint8(uint16(state.enPassantTargetSquare))) {
                    return promotionPieceType == EMPTY; // Cannot promote on en passant
                }
            }
        }
        return false; // Not a valid pawn move
    }

    /**
     * @notice Checks if a knight move is legal
     */
    function isKnightMoveLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to
    ) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        uint8 file1 = from % 8;
        uint8 rank1 = from / 8;
        uint8 file2 = to % 8;
        uint8 rank2 = to / 8;
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;
        return (dFile == 1 && dRank == 2) || (dFile == 2 && dRank == 1);
    }

    /**
     * @notice Helper function to calculate absolute value of a signed integer
     */
    function abs(int8 x) internal pure returns (int8) {
        return x >= 0 ? x : -x;
    }

    /**
     * @notice Checks sliding moves (Bishop, Rook, Queen) for obstructions
     */
    function isSlidingMoveLegal(
        uint8[BOARD_SIZE] memory board,
        uint8 from,
        uint8 to,
        bool diagonal,
        bool orthogonal
    ) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        int8 file1 = int8(from % 8);
        int8 rank1 = int8(from / 8);
        int8 file2 = int8(to % 8);
        int8 rank2 = int8(to / 8);
        int8 dFile = file2 - file1;
        int8 dRank = rank2 - rank1;

        bool isDiagonal = abs(dFile) == abs(dRank) && dFile != 0;
        bool isOrthogonal = (dFile == 0 && dRank != 0) ||
            (dRank == 0 && dFile != 0);

        // Check if the move type is allowed
        if (!((diagonal && isDiagonal) || (orthogonal && isOrthogonal))) {
            return false;
        }

        // Determine step direction
        int8 stepFile = (dFile > 0)
            ? int8(1)
            : ((dFile < 0) ? int8(-1) : int8(0));
        int8 stepRank = (dRank > 0)
            ? int8(1)
            : ((dRank < 0) ? int8(-1) : int8(0));

        // Check squares between 'from' and 'to' for obstructions
        int8 currentFile = file1 + stepFile;
        int8 currentRank = rank1 + stepRank;
        while (currentFile != file2 || currentRank != rank2) {
            uint8 square = uint8((currentRank * 8) + currentFile);
            if (board[square] != EMPTY) {
                return false; // Path is obstructed
            }
            currentFile += stepFile;
            currentRank += stepRank;
        }

        return true;
    }

    /**
     * @notice Checks if a king move is legal (includes castling)
     */
    function isKingMoveLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to
    ) internal pure returns (bool) {
        uint8 file1 = from % 8;
        uint8 rank1 = from / 8;
        uint8 file2 = to % 8;
        uint8 rank2 = to / 8;
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;

        // Regular king move: one square in any direction
        if (dFile <= 1 && dRank <= 1) {
            return true; // Basic king movement
        }

        // Check for castling
        uint8 movingColor = getColor(state.board, from);
        if (dFile == 2 && dRank == 0) {
            // Potential castling
            if (movingColor == WHITE) {
                // White king at e1 (4)
                if (from == E1 && state.board[from] == UNMOVED_KING_OR_ROOK) {
                    if (to == G1 && state.whiteKingsideCastle) {
                        // Kingside castling
                        // Check squares between king and rook are empty
                        if (state.board[F1] != EMPTY) return false;
                        // Check king doesn't move through check
                        if (
                            isSquareAttacked(state.board, E1, BLACK) ||
                            isSquareAttacked(state.board, F1, BLACK)
                        ) {
                            return false;
                        }
                        return true;
                    } else if (to == C1 && state.whiteQueensideCastle) {
                        // Queenside castling
                        // Check squares between king and rook are empty
                        if (
                            state.board[D1] != EMPTY || state.board[B1] != EMPTY
                        ) {
                            return false;
                        }
                        // Check king doesn't move through check
                        if (
                            isSquareAttacked(state.board, E1, BLACK) ||
                            isSquareAttacked(state.board, D1, BLACK)
                        ) {
                            return false;
                        }
                        return true;
                    }
                }
            } else {
                // Black king at e8 (60)
                if (from == E8 && state.board[from] == UNMOVED_KING_OR_ROOK) {
                    if (to == G8 && state.blackKingsideCastle) {
                        // Kingside castling
                        // Check squares between king and rook are empty
                        if (state.board[F8] != EMPTY) return false;
                        // Check king doesn't move through check
                        if (
                            isSquareAttacked(state.board, E8, WHITE) ||
                            isSquareAttacked(state.board, F8, WHITE)
                        ) {
                            return false;
                        }
                        return true;
                    } else if (to == C8 && state.blackQueensideCastle) {
                        // Queenside castling
                        // Check squares between king and rook are empty
                        if (
                            state.board[D8] != EMPTY || state.board[B8] != EMPTY
                        ) {
                            return false;
                        }
                        // Check king doesn't move through check
                        if (
                            isSquareAttacked(state.board, E8, WHITE) ||
                            isSquareAttacked(state.board, D8, WHITE)
                        ) {
                            return false;
                        }
                        return true;
                    }
                }
            }
        }

        return false; // Not a valid king move
    }

    /**
     * @notice Checks if a square is attacked by a given color
     */
    function isSquareAttacked(
        uint8[BOARD_SIZE] memory board,
        uint8 square,
        uint8 attackingColor
    ) internal pure returns (bool) {
        uint8 file = square % 8;
        uint8 rank = square / 8;

        // Check for pawn attacks
        if (attackingColor == WHITE) {
            // Check for white pawn attacks diagonally forward
            if (rank > 0) {
                if (file > 0) {
                    uint8 attacker = board[square - 9];
                    if (
                        attacker == W_PAWN || attacker == JUST_DOUBLE_MOVED_PAWN
                    ) {
                        if (getColor(board, square - 9) == WHITE) return true;
                    }
                }
                if (file < 7) {
                    uint8 attacker = board[square - 7];
                    if (
                        attacker == W_PAWN || attacker == JUST_DOUBLE_MOVED_PAWN
                    ) {
                        if (getColor(board, square - 7) == WHITE) return true;
                    }
                }
            }
        } else {
            // Check for black pawn attacks diagonally forward
            if (rank < 7) {
                if (file > 0) {
                    uint8 attacker = board[square + 7];
                    if (
                        attacker == B_PAWN || attacker == JUST_DOUBLE_MOVED_PAWN
                    ) {
                        if (getColor(board, square + 7) == BLACK) return true;
                    }
                }
                if (file < 7) {
                    uint8 attacker = board[square + 9];
                    if (
                        attacker == B_PAWN || attacker == JUST_DOUBLE_MOVED_PAWN
                    ) {
                        if (getColor(board, square + 9) == BLACK) return true;
                    }
                }
            }
        }

        // Check for knight attacks
        int8[8] memory knightDeltaX = [
            int8(1),
            int8(2),
            int8(2),
            int8(1),
            int8(-1),
            int8(-2),
            int8(-2),
            int8(-1)
        ];
        int8[8] memory knightDeltaY = [
            int8(2),
            int8(1),
            int8(-1),
            int8(-2),
            int8(-2),
            int8(-1),
            int8(1),
            int8(2)
        ];
        for (uint8 i = 0; i < 8; i++) {
            int8 nx = int8(file) + knightDeltaX[i];
            int8 ny = int8(rank) + knightDeltaY[i];
            if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) {
                uint8 knightSquare = uint8(ny * 8 + nx);
                uint8 piece = board[knightSquare];
                if (
                    (attackingColor == WHITE && piece == W_KNIGHT) ||
                    (attackingColor == BLACK && piece == B_KNIGHT)
                ) {
                    return true;
                }
            }
        }

        // Check for sliding piece attacks (bishop, rook, queen)
        int8[8] memory slidingDeltaX = [
            int8(0),
            int8(1),
            int8(1),
            int8(1),
            int8(0),
            int8(-1),
            int8(-1),
            int8(-1)
        ];
        int8[8] memory slidingDeltaY = [
            int8(-1),
            int8(-1),
            int8(0),
            int8(1),
            int8(1),
            int8(1),
            int8(0),
            int8(-1)
        ];
        for (uint8 dir = 0; dir < 8; dir++) {
            int8 dx = slidingDeltaX[dir];
            int8 dy = slidingDeltaY[dir];
            int8 nx = int8(file) + dx;
            int8 ny = int8(rank) + dy;
            while (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) {
                uint8 checkSquare = uint8(ny * 8 + nx);
                uint8 piece = board[checkSquare];

                if (piece != EMPTY) {
                    // Found a piece
                    uint8 color = getColor(board, checkSquare);
                    if (color == attackingColor) {
                        // It's the attacking color's piece, check if it can attack in this direction
                        uint8 baseType = getBasePieceType(piece, checkSquare);
                        bool isDiagonal = (dx != 0 && dy != 0);
                        bool isOrthogonal = (dx == 0 || dy == 0);

                        if (
                            (baseType == W_BISHOP && isDiagonal) ||
                            (baseType == W_ROOK && isOrthogonal) ||
                            (baseType == W_QUEEN)
                        ) {
                            return true;
                        }

                        // King can only attack 1 square away
                        if (
                            baseType == W_KING &&
                            nx == int8(file) + dx &&
                            ny == int8(rank) + dy
                        ) {
                            return true;
                        }
                    }
                    break; // Stop checking this direction after finding any piece
                }

                // Continue in this direction
                nx += dx;
                ny += dy;
            }
        }

        return false; // Square is not attacked
    }

    /**
     * @notice Applies a move to a board state (creates a new state object)
     */
    function applyMove(
        DecodedState memory state,
        uint8 fromSquare,
        uint8 toSquare,
        uint8 promotionPieceType
    ) internal pure returns (DecodedState memory nextState) {
        // Create a shallow copy of the state first
        nextState = state;

        // Create a deep copy of the board
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            nextState.board[i] = state.board[i];
        }

        uint8 piece = state.board[fromSquare];
        uint8 movingColor = getColor(state.board, fromSquare);
        uint8 baseType = getBasePieceType(piece, fromSquare);

        // Handle special moves first

        // 1. En passant capture
        if (
            baseType == W_PAWN &&
            int16(uint16(toSquare)) == state.enPassantTargetSquare
        ) {
            // This is an en passant capture
            nextState.board[toSquare] = (movingColor == WHITE)
                ? W_PAWN
                : B_PAWN;
            nextState.board[fromSquare] = EMPTY;

            // Remove the captured pawn
            uint8 capturedPawnSquare = (movingColor == WHITE)
                ? uint8(uint16(toSquare - 8))
                : uint8(uint16(toSquare + 8));
            nextState.board[capturedPawnSquare] = EMPTY;
            return nextState;
        }

        // 2. Castling
        if (baseType == W_KING && piece == UNMOVED_KING_OR_ROOK) {
            if (movingColor == WHITE) {
                if (fromSquare == E1 && toSquare == G1) {
                    // White kingside castle
                    nextState.board[G1] = W_KING;
                    nextState.board[F1] = W_ROOK;
                    nextState.board[E1] = EMPTY;
                    nextState.board[H1] = EMPTY;
                    nextState.whiteKingSquare = G1;
                    return nextState;
                } else if (fromSquare == E1 && toSquare == C1) {
                    // White queenside castle
                    nextState.board[C1] = W_KING;
                    nextState.board[D1] = W_ROOK;
                    nextState.board[E1] = EMPTY;
                    nextState.board[A1] = EMPTY;
                    nextState.whiteKingSquare = C1;
                    return nextState;
                }
            } else {
                if (fromSquare == E8 && toSquare == G8) {
                    // Black kingside castle
                    nextState.board[G8] = B_KING;
                    nextState.board[F8] = B_ROOK;
                    nextState.board[E8] = EMPTY;
                    nextState.board[H8] = EMPTY;
                    nextState.blackKingSquare = G8;
                    return nextState;
                } else if (fromSquare == E8 && toSquare == C8) {
                    // Black queenside castle
                    nextState.board[C8] = B_KING;
                    nextState.board[D8] = B_ROOK;
                    nextState.board[E8] = EMPTY;
                    nextState.board[A8] = EMPTY;
                    nextState.blackKingSquare = C8;
                    return nextState;
                }
            }
        }

        // 3. Pawn promotion
        if (baseType == W_PAWN) {
            uint8 toRank = toSquare / 8;
            bool isPromotion = (movingColor == WHITE && toRank == 7) ||
                (movingColor == BLACK && toRank == 0);

            if (isPromotion) {
                // Apply promotion
                nextState.board[toSquare] = promotionPieceType;
                nextState.board[fromSquare] = EMPTY;
                return nextState;
            }
        }

        // 4. Regular piece movement
        // Standard moves and captures
        if (baseType == W_KING) {
            // Update king position
            if (movingColor == WHITE) {
                nextState.whiteKingSquare = toSquare;

                // Convert UNMOVED_KING_OR_ROOK to W_KING when moved
                if (piece == UNMOVED_KING_OR_ROOK) {
                    nextState.board[toSquare] = W_KING;
                } else {
                    nextState.board[toSquare] = piece;
                }
            } else {
                nextState.blackKingSquare = toSquare;

                // Convert UNMOVED_KING_OR_ROOK to B_KING when moved
                if (piece == UNMOVED_KING_OR_ROOK) {
                    nextState.board[toSquare] = B_KING;
                } else {
                    nextState.board[toSquare] = piece;
                }
            }
            nextState.board[fromSquare] = EMPTY;
        } else if (baseType == W_ROOK && piece == UNMOVED_KING_OR_ROOK) {
            // Convert UNMOVED_KING_OR_ROOK to W_ROOK/B_ROOK when moved
            nextState.board[toSquare] = (movingColor == WHITE)
                ? W_ROOK
                : B_ROOK;
            nextState.board[fromSquare] = EMPTY;
        } else {
            // Standard move for all other pieces
            nextState.board[toSquare] = piece;
            nextState.board[fromSquare] = EMPTY;
        }

        return nextState;
    }

    /**
     * @notice Checks if the promotion piece type is valid
     */
    function isValidPromotionPiece(
        uint8 color,
        uint8 pieceType
    ) internal pure returns (bool) {
        if (pieceType == EMPTY) return false; // Must specify a promotion piece

        if (color == WHITE) {
            return
                pieceType == W_KNIGHT ||
                pieceType == W_BISHOP ||
                pieceType == W_ROOK ||
                pieceType == W_QUEEN;
        } else {
            return
                pieceType == B_KNIGHT ||
                pieceType == B_BISHOP ||
                pieceType == B_ROOK ||
                pieceType == B_QUEEN;
        }
    }
}
