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
 *      3: JUST_DOUBLE_MOVED_PAWN (Color inferred: rank 3 = White pawn on 4th, rank 4 = Black pawn on 5th)
 *      4: W_KNIGHT
 *      5: B_KNIGHT
 *      6: W_BISHOP
 *      7: B_BISHOP
 *      8: W_ROOK (Moved or standard)
 *      9: B_ROOK (Moved or standard)
 *      10: W_QUEEN
 *      11: B_QUEEN
 *      12: UNMOVED_KING_OR_ROOK (Identity determined by initial square: e1/e8=K, a1/h1/a8/h8=R)
 *      13: W_KING (Moved or standard)
 *      14: B_KING (Moved or standard)
 *      15: KING_TO_MOVE (The king whose side's turn it is)
 *
 *      Castling rights are implicitly determined by the presence of UNMOVED_KING_OR_ROOK (12)
 *      on the respective king and rook starting squares (e1, a1, h1, e8, a8, h8).
 *      En passant target square is implicitly determined by the location of
 *      JUST_DOUBLE_MOVED_PAWN (3). Rank 3 means white pawn just moved, target square is rank 2.
 *      Rank 4 means black pawn just moved, target square is rank 5.
 *      Turn is determined by finding KING_TO_MOVE (15) and seeing if the other king is W_KING (13) or B_KING (14).
 */
library ChessLogic {
    // --- Constants ---

    uint8 public constant EMPTY = 0;
    uint8 public constant W_PAWN = 1;
    uint8 public constant B_PAWN = 2;
    uint8 public constant JUST_DOUBLE_MOVED_PAWN = 3; // Color inferred by rank (3=W on 4th, 4=B on 5th)
    uint8 public constant W_KNIGHT = 4;
    uint8 public constant B_KNIGHT = 5;
    uint8 public constant W_BISHOP = 6;
    uint8 public constant B_BISHOP = 7;
    uint8 public constant W_ROOK = 8; // Moved rook
    uint8 public constant B_ROOK = 9; // Moved rook
    uint8 public constant W_QUEEN = 10;
    uint8 public constant B_QUEEN = 11;
    uint8 public constant UNMOVED_KING_OR_ROOK = 12; // Can be K, R (used for castling)
    uint8 public constant W_KING = 13; // Moved King or standard state
    uint8 public constant B_KING = 14; // Moved King or standard state
    uint8 public constant KING_TO_MOVE = 15; // The king whose side is to move

    uint8 public constant WHITE = 0;
    uint8 public constant BLACK = 1;

    uint8 public constant BOARD_SIZE = 64;
    uint256 public constant SQUARE_MASK = 0xF; // 4 bits for a square

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

    // --- Structs ---

    // Represents the fully decoded state for easier processing within functions
    struct DecodedState {
        uint8[BOARD_SIZE] board; // 64 squares, each with a piece ID (0-15)
        uint8 turn; // WHITE or BLACK
        int16 enPassantTargetSquare; // Index (0-63) or -1 if none (derived from JUST_DOUBLE_MOVED_PAWN)
        // Castling Rights (derived from UNMOVED_KING_OR_ROOK presence on start squares)
        bool whiteKingsideCastle;
        bool whiteQueensideCastle;
        bool blackKingsideCastle;
        bool blackQueensideCastle;
        uint8 whiteKingSquare; // Current square of the white king
        uint8 blackKingSquare; // Current square of the black king
    }

    // --- Errors ---
    error InvalidMove();
    error NotYourTurn(); // Should be caught by caller (Chess.sol) based on player address mapping
    error PieceNotFound(); // Trying to move an empty square or get color of empty
    error MoveLeavesKingInCheck();
    error InvalidPromotion(); // Invalid piece type selected for promotion
    error InvalidEncoding(); // Indicates corrupted or impossible state encoding
    error InvalidSquare(); // Move coordinates out of bounds

    // --- Encoding/Decoding ---

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
                    state.enPassantTargetSquare = int16(uint16(i - 8)); // e.g., if pawn on e4 (28), target is e3 (20)
                } else if (rank == 4) {
                    state.enPassantTargetSquare = int16(uint16(i + 8)); // black pawn on 5th, target is 6th
                }
            }

            // Locate Kings - Initial Pass
            if (pieceId == KING_TO_MOVE) {
                kingToMoveSquare = i;
            } else if (pieceId == W_KING) {
                state.whiteKingSquare = i;
            } else if (pieceId == B_KING) {
                state.blackKingSquare = i;
            } else if (pieceId == UNMOVED_KING_OR_ROOK) {
                // No-op for now, handled later for castling rights
            }
        }

        // 2. Determine whose turn it is based on King IDs
        if (kingToMoveSquare == 255) {
            // KING_TO_MOVE ID (15) wasn't found. This should only happen in the initial state
            // where White King is 15 and Black King is 14.
            // Let's re-verify king positions and IDs for robustness.
            state.whiteKingSquare = 255; // Reset sentinels
            state.blackKingSquare = 255;
            for (uint8 i = 0; i < BOARD_SIZE; i++) {
                uint8 pieceId = state.board[i];
                if (pieceId == W_KING) state.whiteKingSquare = i;
                if (pieceId == B_KING) state.blackKingSquare = i;
                if (pieceId == KING_TO_MOVE) kingToMoveSquare = i;
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
            // KING_TO_MOVE (15) was found directly
            // Find the other king (ID 13 or 14 or 12 on start square)
            state.whiteKingSquare = 255; // Reset sentinels
            state.blackKingSquare = 255;
            for (uint8 i = 0; i < BOARD_SIZE; i++) {
                uint8 pieceId = state.board[i];
                if (pieceId == W_KING) {
                    otherKingId = W_KING;
                    state.whiteKingSquare = i;
                }
                if (pieceId == B_KING) {
                    otherKingId = B_KING;
                    state.blackKingSquare = i;
                }
            }

            // Now assign the kingToMoveSquare to the correct color based on the *other* king found
            if (otherKingId == W_KING) {
                // The standard/unmoved king is White, so KING_TO_MOVE (15) must be Black
                state.turn = BLACK;
                state.blackKingSquare = kingToMoveSquare; // Correct the black king square
                if (state.whiteKingSquare == 255) revert InvalidEncoding(); // White king missing
            } else if (otherKingId == B_KING) {
                // The standard/unmoved king is Black, so KING_TO_MOVE (15) must be White
                state.turn = WHITE;
                state.whiteKingSquare = kingToMoveSquare; // Correct the white king square
                if (state.blackKingSquare == 255) revert InvalidEncoding(); // Black king missing
            } else {
                // If not W_KING or B_KING, fallback: assign turn to WHITE by default
                state.turn = WHITE;
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

        return state;
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

        // Place UNMOVED Rooks and King placeholders first (ID 12)
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
        // Set White King to KING_TO_MOVE (15) on e1
        encodedState |= uint256(KING_TO_MOVE) << (E1 * 4);
        // Set Black King to B_KING (14) on e8
        encodedState |= uint256(B_KING) << (E8 * 4);

        return encodedState;
    }

    // --- Move Validation & Execution ---

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
        uint8 playerColor // Passed from Chess.sol after checking msg.sender vs game players
    ) internal pure returns (uint256 newEncodedState) {
        // 1. Decode current state
        DecodedState memory state = decode(encodedState);

        // 2. Check turn (redundant if caller checks, but safe)
        if (state.turn != playerColor) {
            revert InvalidMove(); // Use generic invalid move, caller should prevent NotYourTurn scenario
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
        // This checks if the move is valid *ignoring* whether it leaves the king in check.
        // It also validates promotion piece type if applicable.
        if (
            !isMovePseudoLegal(state, fromSquare, toSquare, promotionPieceType)
        ) {
            revert InvalidMove();
        }

        // 5. Simulate the move to get the potential next board state
        // This applies the changes to a *copy* of the state.
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

        // --- Move is fully legal, finalize state changes ---

        // 7. Clear any JUST_DOUBLE_MOVED_PAWN from the *previous* turn.
        // This must be done *before* potentially setting a new one.
        // We operate on the `nextState.board` which is the result of `applyMove`.
        clearJustDoubleMovedPawn(nextState.board); // Clears ID 3 -> ID 1 or 2

        // 8. Set JUST_DOUBLE_MOVED_PAWN if this move was a pawn double step
        // Use getBasePieceType with context for pieceId
        uint8 movedBaseType = getBasePieceType(pieceId, fromSquare);
        if (movedBaseType == W_PAWN) {
            uint256 uDiff = (toSquare > fromSquare)
                ? toSquare - fromSquare
                : fromSquare - toSquare;
            if (uDiff == 16) {
                nextState.board[toSquare] = JUST_DOUBLE_MOVED_PAWN;
            }
        }

        // 9. Swap King IDs to change the turn indicator
        // Pass the color that just moved. This updates the opponent's king to KING_TO_MOVE.
        swapKingTurn(nextState.board, playerColor);

        // 10. Encode the final board state back to uint256
        return encode(nextState);
    }

    // --- Helper Functions (Core Logic) ---

    /**
     * @notice Checks if a move is pseudo-legal (follows piece rules, ignores self-check).
     * @dev Called by processMove. Includes checks for promotion validity.
     */
    function isMovePseudoLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to,
        uint8 promotionPieceType
    ) internal pure returns (bool) {
        uint8 piece = state.board[from];
        uint8 targetPiece = state.board[to];
        uint8 movingColor = getColor(state.board, from); // Use context-aware getColor

        // Basic checks: cannot capture own piece
        if (targetPiece != EMPTY && getColor(state.board, to) == movingColor) {
            return false;
        }

        // Get base type contextually for ID 12
        uint8 baseType = getBasePieceType(piece, from);

        // --- Piece Specific Logic ---
        if (baseType == W_PAWN) {
            // Generic Pawn type check
            return isPawnMoveLegal(state, from, to, promotionPieceType);
        }
        if (baseType == W_KNIGHT) {
            // Generic Knight type check
            return isKnightMoveLegal(state, from, to); // Target occupation checked above
        }
        if (baseType == W_BISHOP) {
            // Generic Bishop type check
            return isSlidingMoveLegal(state.board, from, to, true, false); // Diagonal=true, Orthogonal=false
        }
        if (baseType == W_ROOK) {
            // Generic Rook type check
            return isSlidingMoveLegal(state.board, from, to, false, true); // Diagonal=false, Orthogonal=true
        }
        if (baseType == W_QUEEN) {
            // Generic Queen type check
            return isSlidingMoveLegal(state.board, from, to, true, true); // Both diagonal and orthogonal
        }
        if (baseType == W_KING) {
            // Generic King type check
            return isKingMoveLegal(state, from, to);
        }

        // Should not be reached if all piece types are handled
        return false;
    }

    function isPawnMoveLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to,
        uint8 promotionPieceType
    ) internal pure returns (bool) {
        uint8 movingColor = getColor(state.board, from);
        // FIX: Calculate difference using uint256 and check sign/magnitude later
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
                if (
                    state.board[to] != EMPTY &&
                    getColor(state.board, to) == BLACK
                ) {
                    if (
                        isPromotion &&
                        !isValidPromotionPiece(WHITE, promotionPieceType)
                    ) return false;
                    if (!isPromotion && promotionPieceType != EMPTY)
                        return false;
                    return true;
                }
                // En passant capture
                // FIX: Check EP target >= 0 and cast EP target to uint8 for comparison
                if (
                    state.enPassantTargetSquare >= 0 &&
                    to == uint8(uint16(state.enPassantTargetSquare))
                ) {
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
                if (
                    state.board[to] != EMPTY &&
                    getColor(state.board, to) == WHITE
                ) {
                    if (
                        isPromotion &&
                        !isValidPromotionPiece(BLACK, promotionPieceType)
                    ) return false;
                    if (!isPromotion && promotionPieceType != EMPTY)
                        return false;
                    return true;
                }
                // En passant capture
                // FIX: Check EP target >= 0 and cast EP target to uint8 for comparison
                if (
                    state.enPassantTargetSquare >= 0 &&
                    to == uint8(uint16(state.enPassantTargetSquare))
                ) {
                    return promotionPieceType == EMPTY; // Cannot promote on en passant
                }
            }
        }
        return false; // Not a valid pawn move
    }

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
        // FIX: Calculate unsigned differences
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;
        return (dFile == 1 && dRank == 2) || (dFile == 2 && dRank == 1);
    }

    // Checks sliding moves (Bishop, Rook, Queen) for obstructions
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

        // FIX: Explicitly cast subtraction result to int8 before calling abs(int8)
        bool isDiagonal = abs(dFile) == abs(dRank) && dFile != 0;
        bool isOrthogonal = (dFile == 0 && dRank != 0) ||
            (dFile != 0 && dRank == 0);

        // Check if the move type is allowed
        if (!((diagonal && isDiagonal) || (orthogonal && isOrthogonal))) {
            return false;
        }

        // Determine step direction
        // FIX: Explicitly cast literals to int8 in ternary
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
            // Ensure intermediate coordinates are valid before accessing board
            if (
                currentRank < 0 ||
                currentRank > 7 ||
                currentFile < 0 ||
                currentFile > 7
            ) {
                revert InvalidEncoding(); // Path goes off board - should not happen with valid inputs
            }
            // FIX: Cast int8 rank/file directly to uint8 for square index calculation
            uint8 intermediateSquare = uint8(currentRank) *
                8 +
                uint8(currentFile);
            if (board[intermediateSquare] != EMPTY) {
                return false; // Path is blocked
            }
            currentFile += stepFile;
            currentRank += stepRank;
        }

        return true; // Path is clear
    }

    function isKingMoveLegal(
        DecodedState memory state,
        uint8 from,
        uint8 to
    ) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        uint8 movingColor = getColor(state.board, from);
        uint8 file1 = from % 8;
        uint8 rank1 = from / 8;
        uint8 file2 = to % 8;
        uint8 rank2 = to / 8;
        // FIX: Calculate unsigned differences
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;

        // 1. Standard move (1 square any direction)
        if (dFile <= 1 && dRank <= 1 && (dFile != 0 || dRank != 0)) {
            // Note: Moving into check is validated later by processMove
            return true;
        }

        // 2. Castling
        // FIX: Calculate unsigned difference
        uint256 uDiff = (to > from) ? to - from : from - to;
        if (uDiff == 2) {
            // Potential castle
            uint8 opponentColor = 1 - movingColor;

            // Check if King is currently in check - cannot castle out of check
            if (isSquareAttacked(state.board, from, opponentColor)) {
                return false;
            }

            if (movingColor == WHITE && from == E1) {
                if (to == G1 && state.whiteKingsideCastle) {
                    // Kingside O-O (e1 -> g1)
                    // Check path clear (f1, g1) and squares not attacked
                    return
                        state.board[F1] == EMPTY &&
                        state.board[G1] == EMPTY &&
                        !isSquareAttacked(state.board, F1, opponentColor) && // f1 not attacked
                        !isSquareAttacked(state.board, G1, opponentColor); // g1 not attacked (e1 already checked)
                }
                if (to == C1 && state.whiteQueensideCastle) {
                    // Queenside O-O-O (e1 -> c1)
                    // Check path clear (d1, c1, b1) and squares not attacked
                    return
                        state.board[D1] == EMPTY &&
                        state.board[C1] == EMPTY &&
                        state.board[B1] == EMPTY &&
                        !isSquareAttacked(state.board, D1, opponentColor) && // d1 not attacked
                        !isSquareAttacked(state.board, C1, opponentColor); // c1 not attacked (e1 already checked)
                }
            } else if (movingColor == BLACK && from == E8) {
                if (to == G8 && state.blackKingsideCastle) {
                    // Kingside O-O (e8 -> g8)
                    return
                        state.board[F8] == EMPTY &&
                        state.board[G8] == EMPTY &&
                        !isSquareAttacked(state.board, F8, opponentColor) &&
                        !isSquareAttacked(state.board, G8, opponentColor);
                }
                if (to == C8 && state.blackQueensideCastle) {
                    // Queenside O-O-O (e8 -> c8)
                    return
                        state.board[D8] == EMPTY &&
                        state.board[C8] == EMPTY &&
                        state.board[B8] == EMPTY &&
                        !isSquareAttacked(state.board, D8, opponentColor) &&
                        !isSquareAttacked(state.board, C8, opponentColor);
                }
            }
        }

        return false; // Not a valid standard king move or castle
    }

    /**
     * @notice Applies the move to a *copy* of the board state.
     * @dev Assumes the move is pseudo-legal. Does NOT handle turn switch or special pawn flags.
     *      Updates piece IDs (e.g., UNMOVED -> standard), performs captures, moves rook for castling.
     *      Returns the modified state struct (primarily the board and updated king positions).
     */
    function applyMove(
        DecodedState memory state, // Input state (will be copied)
        uint8 from,
        uint8 to,
        uint8 promotionPieceType
    ) internal pure returns (DecodedState memory nextState) {
        nextState = state; // Create a working copy
        uint8 pieceToMove = nextState.board[from];
        uint8 movingColor = getColor(nextState.board, from);

        // Determine base type contextually for ID 12
        uint8 baseType = getBasePieceType(pieceToMove, from);

        // 1. En Passant Capture: Remove the captured pawn
        // FIX: Check EP target >= 0 and cast EP target to uint8 for comparison
        if (
            baseType == W_PAWN &&
            state.enPassantTargetSquare >= 0 &&
            to == uint8(uint16(state.enPassantTargetSquare))
        ) {
            uint8 capturedPawnSquare;
            if (movingColor == WHITE) {
                capturedPawnSquare = to - 8; // Black pawn was on rank 4 (e.g., target f6 -> pawn f5)
            } else {
                // Black moving
                capturedPawnSquare = to + 8; // White pawn was on rank 3 (e.g., target c3 -> pawn c4)
            }
            // Ensure we are capturing the correct piece (should be opponent's pawn)
            if (
                nextState.board[capturedPawnSquare] != EMPTY &&
                getColor(nextState.board, capturedPawnSquare) != movingColor
            ) {
                nextState.board[capturedPawnSquare] = EMPTY; // Remove captured pawn
            } else {
                revert InvalidMove(); // EP capture logic error or invalid state
            }
        }

        // 2. Castling: Move the Rook in addition to the King
        // FIX: Calculate unsigned difference
        uint256 uDiff = (to > from) ? to - from : from - to;
        if (baseType == W_KING && uDiff == 2) {
            uint8 rookFrom;
            uint8 rookTo;
            uint8 rookType; // The ID the rook should become after moving
            if (to == G1) {
                // White Kingside (e1g1)
                rookFrom = H1;
                rookTo = F1;
                rookType = W_ROOK;
            } else if (to == C1) {
                // White Queenside (e1c1)
                rookFrom = A1;
                rookTo = D1;
                rookType = W_ROOK;
            } else if (to == G8) {
                // Black Kingside (e8g8)
                rookFrom = H8;
                rookTo = F8;
                rookType = B_ROOK;
            } else {
                // Black Queenside (e8c8) (to == C8)
                rookFrom = A8;
                rookTo = D8;
                rookType = B_ROOK;
            }
            // Move the rook (must be UNMOVED type initially)
            if (nextState.board[rookFrom] != UNMOVED_KING_OR_ROOK)
                revert InvalidMove(); // Should have been caught by pseudo-legal check
            nextState.board[rookTo] = rookType; // Place moved rook (standard ID)
            nextState.board[rookFrom] = EMPTY; // Empty original rook square
        }

        // --- Standard Move Execution ---
        uint8 pieceIdToPlace = pieceToMove; // Start with the moving piece's ID

        // --- Handle Post-Move ID Updates ---

        // 1. Update King/Rook IDs if they moved from start squares (lose castling rights implicitly)
        // If an UNMOVED_KING_OR_ROOK moves, it becomes its standard type.
        if (pieceToMove == UNMOVED_KING_OR_ROOK) {
            // Base type was already determined above based on 'from' square
            if (baseType == W_KING)
                pieceIdToPlace = (movingColor == WHITE) ? W_KING : B_KING;
            else if (baseType == W_ROOK)
                pieceIdToPlace = (movingColor == WHITE) ? W_ROOK : B_ROOK;
        }
        // Ensure King has correct standard ID after moving (handles KING_TO_MOVE becoming standard)
        else if (baseType == W_KING) {
            pieceIdToPlace = (movingColor == WHITE) ? W_KING : B_KING;
        }
        // Ensure Rook has correct standard ID after moving
        else if (baseType == W_ROOK) {
            pieceIdToPlace = (movingColor == WHITE) ? W_ROOK : B_ROOK;
        }

        // 2. Pawn Promotion
        uint8 toRank = to / 8;
        if (baseType == W_PAWN) {
            if (
                (movingColor == WHITE && toRank == 7) ||
                (movingColor == BLACK && toRank == 0)
            ) {
                // Promotion piece type validity was checked in isPawnMoveLegal
                pieceIdToPlace = promotionPieceType; // Place the chosen promotion piece
            }
        }

        // 3. Place the piece on the 'to' square, clear the 'from' square
        nextState.board[to] = pieceIdToPlace;
        nextState.board[from] = EMPTY;

        // 4. Update king positions in the state struct for subsequent check detection
        if (baseType == W_KING) {
            if (movingColor == WHITE) {
                nextState.whiteKingSquare = to;
            } else {
                nextState.blackKingSquare = to;
            }
        }
        // King positions don't change if another piece moved, so no else needed (copied from state)

        // Return the board state *after* the move is applied but *before* turn/flag updates
        return nextState; // Return the modified copy
    }

    /**
     * @notice Checks if a square is attacked by the opponent.
     * @param board The board state to check against.
     * @param square The square index (0-63) to check.
     * @param attackerColor The color of the pieces that might be attacking (opponent).
     * @return bool True if the square is attacked by any piece of attackerColor.
     */
    function isSquareAttacked(
        uint8[BOARD_SIZE] memory board,
        uint8 square,
        uint8 attackerColor
    ) internal pure returns (bool) {
        // Iterate through all squares to find opponent pieces
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            uint8 piece = board[i];
            // Check if the piece belongs to the attacker and is not empty
            if (piece != EMPTY) {
                uint8 currentPieceColor;
                // FIX: Handle KING_TO_MOVE ambiguity without try/catch
                if (piece == KING_TO_MOVE) {
                    // Infer color based on context (attackerColor)
                    currentPieceColor = attackerColor;
                } else {
                    // For other pieces, getColor is safe (or should revert on invalid state)
                    currentPieceColor = getColor(board, i);
                }

                if (currentPieceColor == attackerColor) {
                    // Check if this opponent piece's attack pattern covers the target square
                    if (canPieceAttackSquare(board, i, square)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * @notice Checks if a piece at `from` can attack `to` based purely on movement patterns.
     * @dev Simplified check used for `isSquareAttacked`. Ignores whose turn, check rules,
     *      and friendly fire on target square. Checks obstructions for sliding pieces.
     * @param board Current board state.
     * @param from Square of the potential attacking piece.
     * @param to Square being checked for attack.
     * @return bool True if the piece on `from` attacks `to`.
     */
    function canPieceAttackSquare(
        uint8[BOARD_SIZE] memory board,
        uint8 from,
        uint8 to
    ) internal pure returns (bool) {
        uint8 piece = board[from];
        if (piece == EMPTY) return false;

        // Determine base type and color contextually
        uint8 baseType = getBasePieceType(piece, from);
        uint8 attackerColor = 0; // Initialize attackerColor - needed for pawn check

        // FIX: Handle KING_TO_MOVE ambiguity without try/catch
        if (piece == KING_TO_MOVE) {
            // Cannot determine attacker color reliably here without full state context.
            // However, for attack checks, only the KING base type matters for its pattern.
            // If it's KING_TO_MOVE, we proceed assuming it's a king, color check happens in isSquareAttacked.
            if (baseType != W_KING) return false; // Should be king if KING_TO_MOVE
            // We don't need the exact color for the king's attack pattern check itself.
        } else {
            // For other pieces, getColor is safe (or should revert on invalid state)
            attackerColor = getColor(board, from);
        }

        // --- Piece Specific Attack Patterns ---
        if (baseType == W_PAWN) {
            // FIX: Calculate difference using uint256 and check sign/magnitude
            uint256 uDiff = (to > from) ? to - from : from - to;
            uint8 fileDiff = (to % 8 > from % 8)
                ? (to % 8) - (from % 8)
                : (from % 8) - (to % 8);
            if (attackerColor == WHITE) {
                // Need color here
                return to > from && (uDiff == 7 || uDiff == 9) && fileDiff == 1; // White pawns attack diagonally forward
            } else {
                // Black Pawn
                return from > to && (uDiff == 7 || uDiff == 9) && fileDiff == 1; // Black pawns attack diagonally forward
            }
        }
        if (baseType == W_KNIGHT) {
            uint8 file1 = from % 8;
            uint8 rank1 = from / 8;
            uint8 file2 = to % 8;
            uint8 rank2 = to / 8;
            // FIX: Calculate unsigned differences
            uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
            uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;
            return (dFile == 1 && dRank == 2) || (dFile == 2 && dRank == 1);
        }
        if (baseType == W_BISHOP) {
            return isSlidingMoveLegal(board, from, to, true, false); // Check diagonal path clear
        }
        if (baseType == W_ROOK) {
            return isSlidingMoveLegal(board, from, to, false, true); // Check orthogonal path clear
        }
        if (baseType == W_QUEEN) {
            return isSlidingMoveLegal(board, from, to, true, true); // Check both paths clear
        }
        if (baseType == W_KING) {
            // Covers W_KING, B_KING, KING_TO_MOVE
            uint8 file1 = from % 8;
            uint8 rank1 = from / 8;
            uint8 file2 = to % 8;
            uint8 rank2 = to / 8;
            // FIX: Calculate unsigned differences
            uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
            uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;
            return dFile <= 1 && dRank <= 1 && (dFile != 0 || dRank != 0); // King attacks adjacent squares
        }

        return false; // Should not happen if all pieces covered
    }

    // --- Utility Functions ---

    /**
     * @notice Gets the color of a piece ID, considering context for special IDs.
     * @param board The current board state (needed for context).
     * @param square The square of the piece.
     * @return color WHITE (0) or BLACK (1). Reverts for EMPTY or invalid encoding.
     * @dev Reverts with specific message if color depends on global state (KING_TO_MOVE).
     */
    function getColor(
        uint8[BOARD_SIZE] memory board,
        uint8 square
    ) internal pure returns (uint8 color) {
        uint8 pieceId = board[square];
        if (pieceId == EMPTY) revert PieceNotFound();

        // Standard White Pieces
        if (
            pieceId == W_PAWN ||
            pieceId == W_KNIGHT ||
            pieceId == W_BISHOP ||
            pieceId == W_ROOK ||
            pieceId == W_QUEEN ||
            pieceId == W_KING
        ) return WHITE;
        // Standard Black Pieces
        if (
            pieceId == B_PAWN ||
            pieceId == B_KNIGHT ||
            pieceId == B_BISHOP ||
            pieceId == B_ROOK ||
            pieceId == B_QUEEN ||
            pieceId == B_KING
        ) return BLACK;

        // Special Cases requiring context:
        if (pieceId == JUST_DOUBLE_MOVED_PAWN) {
            // Color depends on rank where it LANDED.
            uint8 rank = square / 8;
            if (rank == 3) return WHITE; // White pawn landed on 4th rank
            if (rank == 4) return BLACK; // Black pawn landed on 5th rank
            revert InvalidEncoding(); // ID 3 on wrong rank
        }
        if (pieceId == UNMOVED_KING_OR_ROOK) {
            // Color depends on starting position.
            if (square == A1 || square == H1 || square == E1) return WHITE; // White back rank
            if (square == A8 || square == H8 || square == E8) return BLACK; // Black back rank
            revert InvalidEncoding(); // ID 12 on unexpected square
        }
        if (pieceId == KING_TO_MOVE) {
            revert("Cannot determine color of KING_TO_MOVE in isolation");
        }

        revert InvalidEncoding(); // Unknown piece ID
    }

    /**
     * @notice Gets the base piece type (Pawn, Knight, Bishop, Rook, Queen, King)
     * @dev Ignores color, moved status, turn status. Useful for switch statements on behavior.
     *      Returns W_PAWN, W_KNIGHT, etc. as canonical types. Reverts for EMPTY.
     *      Handles special IDs by returning their underlying type. Requires square context for ID 12.
     * @param pieceId The ID of the piece.
     * @param square The square the piece is on (needed for ID 12 context).
     * @return baseTypeId The canonical base type ID.
     */
    function getBasePieceType(
        uint8 pieceId,
        uint8 square
    ) internal pure returns (uint8 baseTypeId) {
        if (pieceId == EMPTY) revert PieceNotFound();
        if (
            pieceId == W_PAWN ||
            pieceId == B_PAWN ||
            pieceId == JUST_DOUBLE_MOVED_PAWN
        ) return W_PAWN;
        if (pieceId == W_KNIGHT || pieceId == B_KNIGHT) return W_KNIGHT;
        if (pieceId == W_BISHOP || pieceId == B_BISHOP) return W_BISHOP;
        if (pieceId == W_ROOK || pieceId == B_ROOK) return W_ROOK; // Includes moved rooks
        if (pieceId == W_QUEEN || pieceId == B_QUEEN) return W_QUEEN;
        if (pieceId == W_KING || pieceId == B_KING || pieceId == KING_TO_MOVE)
            return W_KING;

        if (pieceId == UNMOVED_KING_OR_ROOK) {
            revert("getBasePieceType requires square context for ID 12");
        }

        revert InvalidEncoding(); // Unknown piece ID
    }
    /**
     * @notice Overload for getBasePieceType when square context is not available or needed.
     * @dev Reverts if called on UNMOVED_KING_OR_ROOK (ID 12).
     */
    function getBasePieceType(
        uint8 pieceId
    ) internal pure returns (uint8 baseTypeId) {
        if (pieceId == UNMOVED_KING_OR_ROOK) {
            revert(
                "getBasePieceType requires square context for UNMOVED_KING_OR_ROOK (ID 12)"
            );
        }
        // Use dummy square 0 for other pieces where context doesn't matter for base type
        return getBasePieceType(pieceId, 0);
    }

    /** @notice Clears any JUST_DOUBLE_MOVED_PAWN flags from the board (in memory). */
    function clearJustDoubleMovedPawn(
        uint8[BOARD_SIZE] memory board
    ) internal pure {
        for (uint i = 0; i < BOARD_SIZE; ++i) {
            if (board[i] == JUST_DOUBLE_MOVED_PAWN) {
                // Convert to normal pawn (color by rank)
                uint8 rank = uint8(i / 8);
                board[i] = (rank == 3) ? W_PAWN : B_PAWN;
            }
        }
    }

    /**
     * @notice Swaps the King IDs to indicate the turn change (operates on memory board).
     * @param board The board state *after* the move has been applied.
     * @param colorThatMoved The color (WHITE/BLACK) of the player who just finished their move.
     */
    function swapKingTurn(
        uint8[BOARD_SIZE] memory board,
        uint8 colorThatMoved
    ) internal pure {
        uint8 whiteKingActualSq = 255;
        uint8 blackKingActualSq = 255;
        uint8 movingKingSq = 255;
        uint8 opponentKingSq = 255;
        uint8 movingKingFinalId = (colorThatMoved == WHITE) ? W_KING : B_KING; // ID the moving king should have *now*

        // Find the squares of both kings. This needs to be robust to the different king IDs.
        for (uint8 i = 0; i < BOARD_SIZE; ++i) {
            uint8 pid = board[i];
            if (
                pid == W_KING ||
                pid == KING_TO_MOVE ||
                (pid == UNMOVED_KING_OR_ROOK && i == E1)
            ) {
                // Could be white king
                if (whiteKingActualSq == 255) whiteKingActualSq = i;
                else revert InvalidEncoding(); // Found two white kings?
            } else if (
                pid == B_KING ||
                (pid == KING_TO_MOVE && whiteKingActualSq != i) ||
                (pid == UNMOVED_KING_OR_ROOK && i == E8)
            ) {
                // Could be black king (ensure KING_TO_MOVE isn't double counted if white king was also KING_TO_MOVE)
                if (blackKingActualSq == 255) blackKingActualSq = i;
                else revert InvalidEncoding(); // Found two black kings?
            }
        }

        if (whiteKingActualSq == 255 || blackKingActualSq == 255) {
            revert InvalidEncoding(); // Couldn't find both kings
        }

        // Determine which square belongs to the mover and opponent based on colorThatMoved
        if (colorThatMoved == WHITE) {
            movingKingSq = whiteKingActualSq;
            opponentKingSq = blackKingActualSq;
        } else {
            movingKingSq = blackKingActualSq;
            opponentKingSq = whiteKingActualSq;
        }

        // Ensure the king that moved has its standard ID (W_KING or B_KING)
        // applyMove should have already done this, but double-check.
        board[movingKingSq] = movingKingFinalId;

        // Set the opponent king's ID to KING_TO_MOVE
        board[opponentKingSq] = KING_TO_MOVE;
    }

    /** @notice Checks if a promotion piece type is valid for the color */
    function isValidPromotionPiece(
        uint8 color,
        uint8 promotionPieceType
    ) internal pure returns (bool) {
        // Allow EMPTY only if not actually promoting (checked by caller context)
        if (promotionPieceType == EMPTY) return false; // Must choose a piece when promoting

        if (color == WHITE) {
            return
                promotionPieceType == W_QUEEN ||
                promotionPieceType == W_ROOK ||
                promotionPieceType == W_BISHOP ||
                promotionPieceType == W_KNIGHT;
        } else {
            // BLACK
            return
                promotionPieceType == B_QUEEN ||
                promotionPieceType == B_ROOK ||
                promotionPieceType == B_BISHOP ||
                promotionPieceType == B_KNIGHT;
        }
    }

    /** @notice Absolute value for int8 */
    function abs(int8 x) internal pure returns (int8) {
        return x >= 0 ? x : -x;
    }

    // --- Checkmate/Stalemate (Requires Move Generation - Complex) ---

    /**
     * @notice Checks if the current player is in checkmate.
     * @dev A player is in checkmate if their king is in check and they have no legal moves.
     *      This function optimizes move generation by focusing on pieces near the king or attacking pieces.
     * @param encodedState The current encoded game state.
     * @return bool True if the current player is in checkmate, false otherwise.
     */
    function isCheckmate(uint256 encodedState) internal pure returns (bool) {
        DecodedState memory state = decode(encodedState);
        uint8 kingSquare = (state.turn == WHITE)
            ? state.whiteKingSquare
            : state.blackKingSquare;
        uint8 opponentColor = 1 - state.turn;

        // 1. Is the king currently in check?
        if (!isSquareAttacked(state.board, kingSquare, opponentColor)) {
            return false; // Not in check, so not checkmate
        }

        // 2. Can the current player make *any* legal move?
        // Optimization: Only generate moves for pieces near the king or attacking pieces
        if (canPlayerMakeAnyLegalMove(state, kingSquare)) {
            return false; // Legal move exists, so not checkmate
        }

        return true; // No legal moves and in check -> Checkmate
    }

    /**
     * @notice Checks if the current player is in stalemate.
     * @dev A player is in stalemate if their king is not in check but they have no legal moves.
     *      This function optimizes move generation by focusing on pieces near the king or attacking pieces.
     * @param encodedState The current encoded game state.
     * @return bool True if the current player is in stalemate, false otherwise.
     */
    function isStalemate(uint256 encodedState) internal pure returns (bool) {
        DecodedState memory state = decode(encodedState);
        uint8 kingSquare = (state.turn == WHITE)
            ? state.whiteKingSquare
            : state.blackKingSquare;
        uint8 opponentColor = 1 - state.turn;

        // 1. Is the king currently in check?
        if (isSquareAttacked(state.board, kingSquare, opponentColor)) {
            return false; // In check, so not stalemate
        }

        // 2. Can the current player make *any* legal move?
        // Optimization: Only generate moves for pieces near the king or attacking pieces
        if (canPlayerMakeAnyLegalMove(state, kingSquare)) {
            return false; // Legal move exists, so not stalemate
        }

        return true; // No legal moves and not in check -> Stalemate
    }

    /**
     * @notice Determines if the current player can make any legal move.
     * @dev This function generates pseudo-legal moves for all pieces of the current player and checks
     *      if any move is legal (i.e., does not leave the king in check).
     * @param state The decoded game state.
     * @param kingSquare The square of the current player's king.
     * @return bool True if at least one legal move exists, false otherwise.
     */
    function canPlayerMakeAnyLegalMove(
        DecodedState memory state,
        uint8 kingSquare
    ) internal pure returns (bool) {
        uint8 playerColor = state.turn;

        for (uint8 from = 0; from < BOARD_SIZE; from++) {
            uint8 piece = state.board[from];
            if (piece == EMPTY || getColor(state.board, from) != playerColor) {
                continue;
            }

            // Generate pseudo-legal moves for the piece
            for (uint8 to = 0; to < BOARD_SIZE; to++) {
                if (from == to) continue;
                if (!isMovePseudoLegal(state, from, to, 0)) continue;
                // Simulate move
                DecodedState memory nextState = applyMove(state, from, to, 0);
                uint8 kingSq = (playerColor == WHITE)
                    ? nextState.whiteKingSquare
                    : nextState.blackKingSquare;
                if (
                    !isSquareAttacked(nextState.board, kingSq, 1 - playerColor)
                ) {
                    return true;
                }
            }
        }

        return false; // No legal moves found
    }
}
