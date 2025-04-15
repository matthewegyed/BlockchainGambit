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
    uint8 public constant W_ROOK = 8; // Moved rook or standard state after move
    uint8 public constant B_ROOK = 9; // Moved rook or standard state after move
    uint8 public constant W_QUEEN = 10;
    uint8 public constant B_QUEEN = 11;
    uint8 public constant UNMOVED_KING_OR_ROOK = 12; // Can be K, R (used for castling)
    uint8 public constant W_KING = 13; // Moved King or standard state after move
    uint8 public constant B_KING = 14; // Moved King or standard state after move
    uint8 public constant KING_TO_MOVE = 15; // The king whose side is to move

    uint8 public constant WHITE = 0;
    uint8 public constant BLACK = 1;

    uint8 public constant BOARD_SIZE = 64;
    uint256 public constant SQUARE_MASK = 0xF; // 4 bits for a square

    // Standard square indices
    uint8 constant A1 = 0; uint8 constant B1 = 1; uint8 constant C1 = 2; uint8 constant D1 = 3;
    uint8 constant E1 = 4; uint8 constant F1 = 5; uint8 constant G1 = 6; uint8 constant H1 = 7;
    uint8 constant A2 = 8; uint8 constant B2 = 9; uint8 constant C2 = 10; uint8 constant D2 = 11;
    uint8 constant E2 = 12; uint8 constant F2 = 13; uint8 constant G2 = 14; uint8 constant H2 = 15;
    uint8 constant A3 = 16; uint8 constant B3 = 17; uint8 constant C3 = 18; uint8 constant D3 = 19;
    uint8 constant E3 = 20; uint8 constant F3 = 21; uint8 constant G3 = 22; uint8 constant H3 = 23;
    uint8 constant A4 = 24; uint8 constant B4 = 25; uint8 constant C4 = 26; uint8 constant D4 = 27;
    uint8 constant E4 = 28; uint8 constant F4 = 29; uint8 constant G4 = 30; uint8 constant H4 = 31;
    uint8 constant A5 = 32; uint8 constant B5 = 33; uint8 constant C5 = 34; uint8 constant D5 = 35;
    uint8 constant E5 = 36; uint8 constant F5 = 37; uint8 constant G5 = 38; uint8 constant H5 = 39;
    uint8 constant A6 = 40; uint8 constant B6 = 41; uint8 constant C6 = 42; uint8 constant D6 = 43;
    uint8 constant E6 = 44; uint8 constant F6 = 45; uint8 constant G6 = 46; uint8 constant H6 = 47;
    uint8 constant A7 = 48; uint8 constant B7 = 49; uint8 constant C7 = 50; uint8 constant D7 = 51;
    uint8 constant E7 = 52; uint8 constant F7 = 53; uint8 constant G7 = 54; uint8 constant H7 = 55;
    uint8 constant A8 = 56; uint8 constant B8 = 57; uint8 constant C8 = 58; uint8 constant D8 = 59;
    uint8 constant E8 = 60; uint8 constant F8 = 61; uint8 constant G8 = 62; uint8 constant H8 = 63;

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
    function decode(uint256 encodedState) internal pure returns (DecodedState memory state) {
        state.enPassantTargetSquare = -1; // Default: no en passant
        state.whiteKingSquare = 255; // Sentinel value
        state.blackKingSquare = 255; // Sentinel value
        uint8 kingToMoveIdSquare = 255; // Track square with ID 15

        // 1. Decode board, find kings, special pawns, and determine EP target
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            uint8 pieceId = uint8((encodedState >> (i * 4)) & SQUARE_MASK);
            state.board[i] = pieceId;

            // Identify En Passant Target Square based on JUST_DOUBLE_MOVED_PAWN location
            if (pieceId == JUST_DOUBLE_MOVED_PAWN) {
                uint8 rank = i / 8; // Rank where the pawn LANDED (0-indexed)
                if (rank == 3) { // White pawn just moved e2-e4 (landed on 4th rank), target is behind it (3rd rank)
                    state.enPassantTargetSquare = int16(uint16(i - 8)); // e.g., if pawn on e4 (28), target is e3 (20)
                } else if (rank == 4) { // Black pawn just moved e7-e5 (landed on 5th rank), target is behind it (6th rank)
                     state.enPassantTargetSquare = int16(uint16(i + 8)); // e.g., if pawn on d5 (35), target is d6 (43)
                } else {
                     revert InvalidEncoding(); // ID 3 on wrong rank
                }
            }

            // Locate Kings - Find squares for all possible king representations
            if (pieceId == W_KING || (pieceId == UNMOVED_KING_OR_ROOK && i == E1)) {
                if (state.whiteKingSquare != 255) revert InvalidEncoding(); // Found second white king
                state.whiteKingSquare = i;
            } else if (pieceId == B_KING || (pieceId == UNMOVED_KING_OR_ROOK && i == E8)) {
                if (state.blackKingSquare != 255) revert InvalidEncoding(); // Found second black king
                state.blackKingSquare = i;
            } else if (pieceId == KING_TO_MOVE) {
                if (kingToMoveIdSquare != 255) revert InvalidEncoding(); // Found second KING_TO_MOVE
                kingToMoveIdSquare = i;
            }
        }

        // 2. Determine whose turn it is and finalize king squares
        if (kingToMoveIdSquare != 255) {
            // KING_TO_MOVE ID (15) was found. Determine which king it is.
            if (state.whiteKingSquare == 255 && state.blackKingSquare != 255) {
                // The other king found is Black (ID 14 or 12 on E8). So, ID 15 must be White.
                state.whiteKingSquare = kingToMoveIdSquare;
                state.turn = WHITE;
            } else if (state.blackKingSquare == 255 && state.whiteKingSquare != 255) {
                // The other king found is White (ID 13 or 12 on E1). So, ID 15 must be Black.
                state.blackKingSquare = kingToMoveIdSquare;
                state.turn = BLACK;
            } else {
                // Found both standard kings OR neither standard king along with ID 15. Invalid state.
                revert InvalidEncoding();
            }
        } else {
            // KING_TO_MOVE ID (15) was NOT found. This should only be the initial state.
            // In the initial state, White King is 15, Black King is 14.
            // getInitialState() sets board[E1]=15, board[E8]=14.
            // Our loop above should have found blackKingSquare=E8 (ID 14) and whiteKingSquare=255.
            // We need to check if the piece at E1 is indeed KING_TO_MOVE.
            if (state.board[E1] == KING_TO_MOVE && state.board[E8] == B_KING && state.whiteKingSquare == 255 && state.blackKingSquare == E8) {
                 state.whiteKingSquare = E1; // Correctly assign E1 to white king
                 state.turn = WHITE;
            } else {
                 // Not the initial state and KING_TO_MOVE ID is missing.
                 revert InvalidEncoding();
            }
        }

        // Final check: Ensure both kings were located.
        if (state.whiteKingSquare == 255 || state.blackKingSquare == 255) {
            revert InvalidEncoding(); // Failed to locate both kings
        }

        // 3. Determine Castling Rights based on UNMOVED pieces on STARTING squares
        // Check if the piece on the king's square is UNMOVED_KING_OR_ROOK (ID 12) or the initial KING_TO_MOVE/B_KING
        bool whiteKingUnmovedCheck = state.board[E1] == UNMOVED_KING_OR_ROOK || state.board[E1] == KING_TO_MOVE; // ID 15 implies unmoved initially
        bool blackKingUnmovedCheck = state.board[E8] == UNMOVED_KING_OR_ROOK || state.board[E8] == B_KING; // ID 14 implies unmoved initially

        // Check if the piece on the rook's square is UNMOVED_KING_OR_ROOK (ID 12)
        bool whiteHRookUnmovedCheck = state.board[H1] == UNMOVED_KING_OR_ROOK;
        bool whiteARookUnmovedCheck = state.board[A1] == UNMOVED_KING_OR_ROOK;
        bool blackHRookUnmovedCheck = state.board[H8] == UNMOVED_KING_OR_ROOK;
        bool blackARookUnmovedCheck = state.board[A8] == UNMOVED_KING_OR_ROOK;

        state.whiteKingsideCastle = whiteKingUnmovedCheck && whiteHRookUnmovedCheck;
        state.whiteQueensideCastle = whiteKingUnmovedCheck && whiteARookUnmovedCheck;
        state.blackKingsideCastle = blackKingUnmovedCheck && blackHRookUnmovedCheck;
        state.blackQueensideCastle = blackKingUnmovedCheck && blackARookUnmovedCheck;
    }


    /**
     * @notice Encodes a decoded state back into the compact 256-bit integer.
     * @param state The decoded game state struct.
     * @return encodedState The uint256 representing the game state.
     */
    function encode(DecodedState memory state) internal pure returns (uint256 encodedState) {
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
        // encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (E1 * 4); // e1 placeholder - will be overwritten
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (A8 * 4); // a8
        encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (H8 * 4); // h8
        // encodedState |= uint256(UNMOVED_KING_OR_ROOK) << (E8 * 4); // e8 placeholder - will be overwritten

        // Knights
        encodedState |= uint256(W_KNIGHT) << (B1 * 4); encodedState |= uint256(W_KNIGHT) << (G1 * 4);
        encodedState |= uint256(B_KNIGHT) << (B8 * 4); encodedState |= uint256(B_KNIGHT) << (G8 * 4);
        // Bishops
        encodedState |= uint256(W_BISHOP) << (C1 * 4); encodedState |= uint256(W_BISHOP) << (F1 * 4);
        encodedState |= uint256(B_BISHOP) << (C8 * 4); encodedState |= uint256(B_BISHOP) << (F8 * 4);
        // Queens
        encodedState |= uint256(W_QUEEN) << (D1 * 4);
        encodedState |= uint256(B_QUEEN) << (D8 * 4);

        // Pawns
        for (uint8 i = 8; i < 16; i++) { encodedState |= uint256(W_PAWN) << (i * 4); } // Rank 2
        for (uint8 i = 48; i < 56; i++) { encodedState |= uint256(B_PAWN) << (i * 4); } // Rank 7

        // Manually set correct King IDs for turn (White moves first)
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
        if (fromSquare >= BOARD_SIZE || toSquare >= BOARD_SIZE || fromSquare == toSquare) {
             revert InvalidSquare();
        }
        uint8 pieceId = state.board[fromSquare];
        if (pieceId == EMPTY || getColor(state.board, fromSquare, playerColor) != playerColor) { // Pass context color
             revert InvalidMove(); // Trying to move empty square or opponent's piece
        }

        // 4. Check move pseudo-legality (geometry, captures, special move rules)
        // This checks if the move is valid *ignoring* whether it leaves the king in check.
        // It also validates promotion piece type if applicable.
        if (!isMovePseudoLegal(state, fromSquare, toSquare, promotionPieceType)) {
             revert InvalidMove();
        }

        // 5. Simulate the move to get the potential next board state
        // This applies the changes to a *copy* of the state.
        DecodedState memory nextState = applyMove(state, fromSquare, toSquare, promotionPieceType);

        // 6. Check if the player's own king is in check *after* the simulated move
        uint8 kingSquareToCheck = (playerColor == WHITE) ? nextState.whiteKingSquare : nextState.blackKingSquare;
        if (isSquareAttacked(nextState.board, kingSquareToCheck, 1 - playerColor)) { // Check if attacked by opponent
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
        if (movedBaseType == W_PAWN) { // W_PAWN is the base type for pawns
            uint256 uDiff = (toSquare > fromSquare) ? toSquare - fromSquare : fromSquare - toSquare;
            if (uDiff == 16) { // Check for double step
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
        uint8 movingColor = getColor(state.board, from, state.turn); // Pass current turn as context

        // Basic checks: cannot capture own piece
        if (targetPiece != EMPTY && getColor(state.board, to, state.turn) == movingColor) { // Pass context color
            return false;
        }

        // Get base type contextually for ID 12
        uint8 baseType = getBasePieceType(piece, from);

        // --- Piece Specific Logic ---
        if (baseType == W_PAWN) { // Generic Pawn type check
             return isPawnMoveLegal(state, from, to, promotionPieceType);
        }
        if (baseType == W_KNIGHT) { // Generic Knight type check
             return isKnightMoveLegal(state, from, to); // Target occupation checked above
        }
        if (baseType == W_BISHOP) { // Generic Bishop type check
             return isSlidingMoveLegal(state.board, from, to, true, false); // Diagonal=true, Orthogonal=false
        }
        if (baseType == W_ROOK) { // Generic Rook type check
             return isSlidingMoveLegal(state.board, from, to, false, true); // Diagonal=false, Orthogonal=true
        }
        if (baseType == W_QUEEN) { // Generic Queen type check
             return isSlidingMoveLegal(state.board, from, to, true, true); // Both diagonal and orthogonal
        }
        if (baseType == W_KING) { // Generic King type check
             return isKingMoveLegal(state, from, to);
        }

        // Should not be reached if all piece types are handled
        return false;
    }

    function isPawnMoveLegal(DecodedState memory state, uint8 from, uint8 to, uint8 promotionPieceType) internal pure returns (bool) {
        uint8 movingColor = getColor(state.board, from, state.turn); // Pass context color
        uint256 uDiff = (to > from) ? to - from : from - to;
        bool movingForward = (movingColor == WHITE && to > from) || (movingColor == BLACK && from > to);
        uint8 fromRank = from / 8;
        uint8 toRank = to / 8;
        uint8 fromFile = from % 8;
        uint8 toFile = to % 8;
        uint8 fileDiff = (toFile > fromFile) ? toFile - fromFile : fromFile - toFile;

        if (movingColor == WHITE) {
            // 1. Forward 1 square
            if (movingForward && uDiff == 8 && fileDiff == 0 && state.board[to] == EMPTY) {
                bool isPromotion = (toRank == 7);
                if (isPromotion && !isValidPromotionPiece(WHITE, promotionPieceType)) return false;
                if (!isPromotion && promotionPieceType != EMPTY) return false;
                return true;
            }
            // 2. Forward 2 squares (initial move)
            if (movingForward && fromRank == 1 && uDiff == 16 && fileDiff == 0 && state.board[from + 8] == EMPTY && state.board[to] == EMPTY) {
                return promotionPieceType == EMPTY; // Cannot promote on double move
            }
            // 3. Capture
            if (movingForward && (uDiff == 7 || uDiff == 9) && fileDiff == 1) { // Diagonal forward
                bool isPromotion = (toRank == 7);
                // Standard capture
                if (state.board[to] != EMPTY && getColor(state.board, to, state.turn) == BLACK) { // Pass context color
                    if (isPromotion && !isValidPromotionPiece(WHITE, promotionPieceType)) return false;
                    if (!isPromotion && promotionPieceType != EMPTY) return false;
                    return true;
                }
                // En passant capture
                if (state.enPassantTargetSquare >= 0 && to == uint8(uint16(state.enPassantTargetSquare))) {
                    // Check the square *behind* the target square actually has the opponent's pawn (which must be JUST_DOUBLE_MOVED_PAWN)
                    if (state.board[to - 8] == JUST_DOUBLE_MOVED_PAWN) {
                         return promotionPieceType == EMPTY; // Cannot promote on en passant
                    }
                }
            }
        } else { // BLACK pawn move
            // 1. Forward 1 square
            if (movingForward && uDiff == 8 && fileDiff == 0 && state.board[to] == EMPTY) {
                bool isPromotion = (toRank == 0);
                if (isPromotion && !isValidPromotionPiece(BLACK, promotionPieceType)) return false;
                if (!isPromotion && promotionPieceType != EMPTY) return false;
                return true;
            }
            // 2. Forward 2 squares (initial move)
            if (movingForward && fromRank == 6 && uDiff == 16 && fileDiff == 0 && state.board[from - 8] == EMPTY && state.board[to] == EMPTY) {
                return promotionPieceType == EMPTY; // Cannot promote on double move
            }
            // 3. Capture
            if (movingForward && (uDiff == 7 || uDiff == 9) && fileDiff == 1) { // Diagonal forward
                 bool isPromotion = (toRank == 0);
                 // Standard capture
                if (state.board[to] != EMPTY && getColor(state.board, to, state.turn) == WHITE) { // Pass context color
                    if (isPromotion && !isValidPromotionPiece(BLACK, promotionPieceType)) return false;
                    if (!isPromotion && promotionPieceType != EMPTY) return false;
                    return true;
                }
                // En passant capture
                if (state.enPassantTargetSquare >= 0 && to == uint8(uint16(state.enPassantTargetSquare))) {
                     // Check the square *behind* the target square actually has the opponent's pawn (which must be JUST_DOUBLE_MOVED_PAWN)
                     if (state.board[to + 8] == JUST_DOUBLE_MOVED_PAWN) {
                         return promotionPieceType == EMPTY; // Cannot promote on en passant
                     }
                }
            }
        }
        return false; // Not a valid pawn move
    }

    function isKnightMoveLegal(DecodedState memory state, uint8 from, uint8 to) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        uint8 file1 = from % 8; uint8 rank1 = from / 8;
        uint8 file2 = to % 8;   uint8 rank2 = to / 8;
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;
        return (dFile == 1 && dRank == 2) || (dFile == 2 && dRank == 1);
    }

    // Checks sliding moves (Bishop, Rook, Queen) for obstructions
    function isSlidingMoveLegal(uint8[BOARD_SIZE] memory board, uint8 from, uint8 to, bool diagonal, bool orthogonal) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        int8 file1 = int8(uint8(from % 8)); int8 rank1 = int8(uint8(from / 8)); // Cast to uint8 first
        int8 file2 = int8(uint8(to % 8));   int8 rank2 = int8(uint8(to / 8));   // Cast to uint8 first
        int8 dFile = file2 - file1; int8 dRank = rank2 - rank1;

        bool isDiagonal = abs(dFile) == abs(dRank) && dFile != 0;
        bool isOrthogonal = (dFile == 0 && dRank != 0) || (dFile != 0 && dRank == 0);

        // Check if the move type is allowed
        if (!((diagonal && isDiagonal) || (orthogonal && isOrthogonal))) {
            return false;
        }

        // Determine step direction
        int8 stepFile = (dFile > 0) ? int8(1) : ((dFile < 0) ? int8(-1) : int8(0));
        int8 stepRank = (dRank > 0) ? int8(1) : ((dRank < 0) ? int8(-1) : int8(0));

        // Check squares between 'from' and 'to' for obstructions
        int8 currentFile = file1 + stepFile;
        int8 currentRank = rank1 + stepRank;
        while (currentFile != file2 || currentRank != rank2) {
            // Ensure intermediate coordinates are valid before accessing board
            if (currentRank < 0 || currentRank > 7 || currentFile < 0 || currentFile > 7) {
                revert InvalidEncoding(); // Path goes off board - should not happen with valid inputs
            }
            // FIX: Cast int8 directly to uint8 for square index calculation
            uint8 intermediateSquare = uint8(currentRank) * 8 + uint8(currentFile);
            if (board[intermediateSquare] != EMPTY) {
                return false; // Path is blocked
            }
            currentFile += stepFile;
            currentRank += stepRank;
        }

        return true; // Path is clear
    }

    function isKingMoveLegal(DecodedState memory state, uint8 from, uint8 to) internal pure returns (bool) {
        // Target square occupation (own piece) checked in isMovePseudoLegal caller
        uint8 movingColor = getColor(state.board, from, state.turn); // Pass context color
        uint8 file1 = from % 8; uint8 rank1 = from / 8;
        uint8 file2 = to % 8;   uint8 rank2 = to / 8;
        uint8 dFile = (file2 > file1) ? file2 - file1 : file1 - file2;
        uint8 dRank = (rank2 > rank1) ? rank2 - rank1 : rank1 - rank2;

        // 1. Standard move (1 square any direction)
        if (dFile <= 1 && dRank <= 1 && (dFile != 0 || dRank != 0)) {
            // Note: Moving into check is validated later by processMove
            return true;
        }

        // 2. Castling
        uint256 uDiff = (to > from) ? to - from : from - to;
        if (uDiff == 2 && dRank == 0) { // Potential castle (must be horizontal)
            uint8 opponentColor = 1 - movingColor;

            // Check if King is currently in check - cannot castle out of check
            if (isSquareAttacked(state.board, from, opponentColor)) {
                return false;
            }

            if (movingColor == WHITE && from == E1) {
                if (to == G1 && state.whiteKingsideCastle) { // Kingside O-O (e1 -> g1)
                    // Check path clear (f1, g1) and squares not attacked
                    return state.board[F1] == EMPTY && state.board[G1] == EMPTY &&
                           !isSquareAttacked(state.board, F1, opponentColor) && // f1 not attacked
                           !isSquareAttacked(state.board, G1, opponentColor);   // g1 not attacked (e1 already checked)
                }
                if (to == C1 && state.whiteQueensideCastle) { // Queenside O-O-O (e1 -> c1)
                    // Check path clear (d1, c1, b1) and squares not attacked
                    return state.board[D1] == EMPTY && state.board[C1] == EMPTY && state.board[B1] == EMPTY &&
                           !isSquareAttacked(state.board, D1, opponentColor) && // d1 not attacked
                           !isSquareAttacked(state.board, C1, opponentColor);   // c1 not attacked (e1 already checked)
                }
            } else if (movingColor == BLACK && from == E8) {
                 if (to == G8 && state.blackKingsideCastle) { // Kingside O-O (e8 -> g8)
                    return state.board[F8] == EMPTY && state.board[G8] == EMPTY &&
                           !isSquareAttacked(state.board, F8, opponentColor) &&
                           !isSquareAttacked(state.board, G8, opponentColor);
                }
                 if (to == C8 && state.blackQueensideCastle) { // Queenside O-O-O (e8 -> c8)
                    return state.board[D8] == EMPTY && state.board[C8] == EMPTY && state.board[B8] == EMPTY &&
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
        uint8 movingColor = getColor(nextState.board, from, state.turn); // Pass context color

        // Determine base type contextually for ID 12
        uint8 baseType = getBasePieceType(pieceToMove, from);

        // 1. En Passant Capture: Remove the captured pawn
        if (baseType == W_PAWN && state.enPassantTargetSquare >= 0 && to == uint8(uint16(state.enPassantTargetSquare)))
        {
            uint8 capturedPawnSquare;
            if (movingColor == WHITE) {
                capturedPawnSquare = to - 8; // Black pawn was on rank 4 (e.g., target f6 -> pawn f5)
            } else { // Black moving
                capturedPawnSquare = to + 8; // White pawn was on rank 3 (e.g., target c3 -> pawn c4)
            }
            // Ensure we are capturing the correct piece (should be opponent's pawn)
            // The piece being captured EP *must* have the JUST_DOUBLE_MOVED_PAWN ID
            if (nextState.board[capturedPawnSquare] == JUST_DOUBLE_MOVED_PAWN) {
                nextState.board[capturedPawnSquare] = EMPTY; // Remove captured pawn
            } else {
                revert InvalidMove(); // EP capture logic error or invalid state
            }
        }

        // 2. Castling: Move the Rook in addition to the King
        uint256 uDiff = (to > from) ? to - from : from - to;
        if (baseType == W_KING && uDiff == 2 && (from / 8 == to / 8)) // Check horizontal move by 2
        {
            uint8 rookFrom;
            uint8 rookTo;
            uint8 rookType; // The ID the rook should become after moving
            if (to == G1) { // White Kingside (e1g1)
                rookFrom = H1; rookTo = F1; rookType = W_ROOK;
            } else if (to == C1) { // White Queenside (e1c1)
                rookFrom = A1; rookTo = D1; rookType = W_ROOK;
            } else if (to == G8) { // Black Kingside (e8g8)
                rookFrom = H8; rookTo = F8; rookType = B_ROOK;
            } else if (to == C8) { // Black Queenside (e8c8)
                rookFrom = A8; rookTo = D8; rookType = B_ROOK;
            } else {
                 revert InvalidMove(); // King move by 2 not on back rank or not to c/g file
            }
            // Move the rook (must be UNMOVED type initially)
            if (nextState.board[rookFrom] != UNMOVED_KING_OR_ROOK) revert InvalidMove(); // Should have been caught by pseudo-legal check
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
            if (baseType == W_KING) pieceIdToPlace = (movingColor == WHITE) ? W_KING : B_KING;
            else if (baseType == W_ROOK) pieceIdToPlace = (movingColor == WHITE) ? W_ROOK : B_ROOK;
        }
        // Ensure King has correct standard ID after moving (handles KING_TO_MOVE becoming standard)
        else if (baseType == W_KING) {
             pieceIdToPlace = (movingColor == WHITE) ? W_KING : B_KING;
        }
        // Ensure Rook has correct standard ID after moving
         else if (baseType == W_ROOK) {
             // This case handles a rook that might have already moved (ID 8 or 9) moving again.
             // No ID change needed here, it stays W_ROOK or B_ROOK.
             // pieceIdToPlace = (movingColor == WHITE) ? W_ROOK : B_ROOK; // Redundant
         }

        // 2. Pawn Promotion
        uint8 toRank = to / 8;
        if (baseType == W_PAWN) {
            if ((movingColor == WHITE && toRank == 7) || (movingColor == BLACK && toRank == 0)) {
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
    function isSquareAttacked(uint8[BOARD_SIZE] memory board, uint8 square, uint8 attackerColor) internal pure returns (bool) {
        // Iterate through all squares to find opponent pieces
        for (uint8 i = 0; i < BOARD_SIZE; i++) {
            uint8 piece = board[i];
            if (piece != EMPTY) {
                 // Determine the color of the piece at square 'i'.
                 // We need the context of whose turn it *would* be if this piece were KING_TO_MOVE.
                 // Since we are checking attacks *by* attackerColor, the context turn is the *other* color.
                 uint8 contextTurn = 1 - attackerColor;
                 uint8 currentPieceColor = getColor(board, i, contextTurn);

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
    function canPieceAttackSquare(uint8[BOARD_SIZE] memory board, uint8 from, uint8 to) internal pure returns (bool) {
        uint8 piece = board[from];
        if (piece == EMPTY) return false;

        // Determine base type contextually
        uint8 baseType = getBasePieceType(piece, from);

        // --- Piece Specific Attack Patterns ---
        if (baseType == W_PAWN) {
            // Need color to determine attack direction
            uint8 attackerColor;
            // Determine color based on standard IDs or position for special IDs.
            // This doesn't need the global turn context because we only care about the piece's inherent color for its attack pattern.
            if (piece == W_PAWN || (piece == JUST_DOUBLE_MOVED_PAWN && from / 8 == 3)) attackerColor = WHITE;
            else if (piece == B_PAWN || (piece == JUST_DOUBLE_MOVED_PAWN && from / 8 == 4)) attackerColor = BLACK;
            else return false; // Not a pawn type that can attack

            uint256 uDiff = (to > from) ? to - from : from - to;
            uint8 fileDiff = (to % 8 > from % 8) ? (to % 8) - (from % 8) : (from % 8) - (to % 8);
            if (attackerColor == WHITE) {
                return to > from && (uDiff == 7 || uDiff == 9) && fileDiff == 1; // White pawns attack diagonally forward
            } else { // Black Pawn
                return from > to && (uDiff == 7 || uDiff == 9) && fileDiff == 1; // Black pawns attack diagonally forward
            }
        }
        if (baseType == W_KNIGHT) {
            uint8 file1 = from % 8; uint8 rank1 = from / 8;
            uint8 file2 = to % 8;   uint8 rank2 = to / 8;
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
         if (baseType == W_KING) { // Covers W_KING, B_KING, KING_TO_MOVE, UNMOVED_KING_OR_ROOK on E1/E8
            uint8 file1 = from % 8; uint8 rank1 = from / 8;
            uint8 file2 = to % 8;   uint8 rank2 = to / 8;
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
     * @param contextTurnColor The color whose turn it currently is (needed for KING_TO_MOVE).
     * @return color WHITE (0) or BLACK (1). Reverts for EMPTY or invalid encoding.
     */
    function getColor(uint8[BOARD_SIZE] memory board, uint8 square, uint8 contextTurnColor) internal pure returns (uint8 color) {
        uint8 pieceId = board[square];
        if (pieceId == EMPTY) revert PieceNotFound();

        // Standard White Pieces
        if (pieceId == W_PAWN || pieceId == W_KNIGHT || pieceId == W_BISHOP || pieceId == W_ROOK || pieceId == W_QUEEN || pieceId == W_KING ) return WHITE;
        // Standard Black Pieces
        if (pieceId == B_PAWN || pieceId == B_KNIGHT || pieceId == B_BISHOP || pieceId == B_ROOK || pieceId == B_QUEEN || pieceId == B_KING ) return BLACK;

        // Special Cases requiring context:
        if (pieceId == JUST_DOUBLE_MOVED_PAWN) {
            uint8 rank = square / 8;
            if (rank == 3) return WHITE; // White pawn landed on 4th rank
            if (rank == 4) return BLACK; // Black pawn landed on 5th rank
            revert InvalidEncoding(); // ID 3 on wrong rank
        }
        if (pieceId == UNMOVED_KING_OR_ROOK) {
            if (square == A1 || square == H1 || square == E1) return WHITE; // White back rank
            if (square == A8 || square == H8 || square == E8) return BLACK; // Black back rank
             revert InvalidEncoding(); // ID 12 on unexpected square
        }
         if (pieceId == KING_TO_MOVE) {
             // The piece with ID 15 has the color whose turn it IS.
             return contextTurnColor;
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
    function getBasePieceType(uint8 pieceId, uint8 square) internal pure returns (uint8 baseTypeId) {
         if (pieceId == EMPTY) revert PieceNotFound();
         if (pieceId == W_PAWN || pieceId == B_PAWN || pieceId == JUST_DOUBLE_MOVED_PAWN) return W_PAWN;
         if (pieceId == W_KNIGHT || pieceId == B_KNIGHT) return W_KNIGHT;
         if (pieceId == W_BISHOP || pieceId == B_BISHOP) return W_BISHOP;
         if (pieceId == W_ROOK || pieceId == B_ROOK) return W_ROOK; // Includes moved rooks
         if (pieceId == W_QUEEN || pieceId == B_QUEEN) return W_QUEEN;
         if (pieceId == W_KING || pieceId == B_KING || pieceId == KING_TO_MOVE) return W_KING;

         if (pieceId == UNMOVED_KING_OR_ROOK) {
             if (square == E1 || square == E8) return W_KING;
             if (square == A1 || square == H1 || square == A8 || square == H8) return W_ROOK;
             revert InvalidEncoding(); // ID 12 on unexpected square
         }

         revert InvalidEncoding(); // Unknown piece ID
     }
    /** @notice Overload for getBasePieceType when square context is not available or needed. */
     function getBasePieceType(uint8 pieceId) internal pure returns (uint8 baseTypeId) {
          if (pieceId == UNMOVED_KING_OR_ROOK) {
               revert("getBasePieceType requires square context for UNMOVED_KING_OR_ROOK (ID 12)");
          }
          // Use dummy square 0 for other pieces where context doesn't matter for base type
          return getBasePieceType(pieceId, 0);
     }


    /** @notice Clears any JUST_DOUBLE_MOVED_PAWN flags from the board (in memory). */
    function clearJustDoubleMovedPawn(uint8[BOARD_SIZE] memory board) internal pure {
         for(uint i = 0; i < BOARD_SIZE; ++i) {
             if (board[i] == JUST_DOUBLE_MOVED_PAWN) {
                 uint8 rank = uint8(i / 8);
                 if (rank == 3) board[i] = W_PAWN; // Was white pawn on 4th rank
                 else if (rank == 4) board[i] = B_PAWN; // Was black pawn on 5th rank
                 else revert InvalidEncoding(); // Should not happen
                 // Optimization: can break after finding one, as only one can exist per state
                 // break; // Uncomment if performance becomes critical
             }
         }
     }

    /**
     * @notice Swaps the King IDs to indicate the turn change (operates on memory board).
     * @param board The board state *after* the move has been applied.
     * @param colorThatMoved The color (WHITE/BLACK) of the player who just finished their move.
     */
    function swapKingTurn(uint8[BOARD_SIZE] memory board, uint8 colorThatMoved) internal pure {
         uint8 movingKingSq = 255;
         uint8 opponentKingSq = 255;
         uint8 movingKingCurrentId = EMPTY; // ID on the square before swap
         uint8 opponentKingCurrentId = EMPTY; // ID on the square before swap

         // Find both kings based on their *current* IDs on the board (after applyMove)
         for (uint8 i = 0; i < BOARD_SIZE; ++i) {
             uint8 pid = board[i];
             // Check for White King (ID 13 or 12 on E1 or 15 if it was white's turn)
             if (pid == W_KING || (pid == UNMOVED_KING_OR_ROOK && i == E1) || (pid == KING_TO_MOVE && colorThatMoved == WHITE)) {
                 if (colorThatMoved == WHITE) { movingKingSq = i; movingKingCurrentId = pid; }
                 else { opponentKingSq = i; opponentKingCurrentId = pid; }
             }
             // Check for Black King (ID 14 or 12 on E8 or 15 if it was black's turn)
             else if (pid == B_KING || (pid == UNMOVED_KING_OR_ROOK && i == E8) || (pid == KING_TO_MOVE && colorThatMoved == BLACK)) {
                 if (colorThatMoved == BLACK) { movingKingSq = i; movingKingCurrentId = pid; }
                 else { opponentKingSq = i; opponentKingCurrentId = pid; }
             }
         }

         // If we couldn't find one of the kings, try finding KING_TO_MOVE explicitly if it wasn't assigned yet
         if (movingKingSq == 255) {
             for (uint8 i = 0; i < BOARD_SIZE; ++i) {
                 if (board[i] == KING_TO_MOVE) {
                     movingKingSq = i; movingKingCurrentId = KING_TO_MOVE; break;
                 }
             }
         }
         if (opponentKingSq == 255) {
             for (uint8 i = 0; i < BOARD_SIZE; ++i) {
                 // Check standard IDs or unmoved IDs on starting squares
                 if ((board[i] == W_KING || (board[i] == UNMOVED_KING_OR_ROOK && i == E1)) && colorThatMoved == BLACK) {
                     opponentKingSq = i; opponentKingCurrentId = board[i]; break;
                 }
                 if ((board[i] == B_KING || (board[i] == UNMOVED_KING_OR_ROOK && i == E8)) && colorThatMoved == WHITE) {
                     opponentKingSq = i; opponentKingCurrentId = board[i]; break;
                 }
             }
         }


         if (movingKingSq == 255 || opponentKingSq == 255) {
             revert InvalidEncoding(); // Failed to locate both kings after move
         }

         // Determine the correct *standard* ID for the king that just moved
         uint8 movingKingFinalId = (colorThatMoved == WHITE) ? W_KING : B_KING;

         // Set the king that moved to its standard ID
         board[movingKingSq] = movingKingFinalId;

         // Set the opponent king's ID to KING_TO_MOVE
         board[opponentKingSq] = KING_TO_MOVE;
     }


    /** @notice Checks if a promotion piece type is valid for the color */
    function isValidPromotionPiece(uint8 color, uint8 promotionPieceType) internal pure returns (bool) {
        // Allow EMPTY only if not actually promoting (checked by caller context)
        if (promotionPieceType == EMPTY) return false; // Must choose a piece when promoting

        if (color == WHITE) {
            return promotionPieceType == W_QUEEN || promotionPieceType == W_ROOK ||
                   promotionPieceType == W_BISHOP || promotionPieceType == W_KNIGHT;
        } else { // BLACK
            return promotionPieceType == B_QUEEN || promotionPieceType == B_ROOK ||
                   promotionPieceType == B_BISHOP || promotionPieceType == B_KNIGHT;
        }
    }

     /** @notice Absolute value for int8 */
    function abs(int8 x) internal pure returns (int8) {
        // Special case for int8 minimum to avoid overflow
        if (x == -128) return 127; // Or handle as error, but returning max positive seems reasonable
        return x >= 0 ? x : -x;
    }

    // --- Checkmate/Stalemate (Requires Move Generation - Complex) ---

    /**
     * @notice Checks if the current state is checkmate for the player whose turn it is.
     * @dev Requires generating ALL legal moves for the current player. If no legal moves
     *      exist AND the king is in check, it's checkmate. HIGH GAS COST.
     * @param encodedState The current encoded game state.
     * @return bool True if checkmate.
     */
    function isCheckmate(uint256 encodedState) internal pure returns (bool) {
        DecodedState memory state = decode(encodedState);
        uint8 kingSquare = (state.turn == WHITE) ? state.whiteKingSquare : state.blackKingSquare;
        uint8 opponentColor = 1 - state.turn;

        // 1. Is the king currently in check?
        if (!isSquareAttacked(state.board, kingSquare, opponentColor)) {
            return false; // Not in check, cannot be checkmate
        }

        // 2. Can the current player make *any* legal move?
        // This is the expensive part - requires generating all possible moves.
        if (canPlayerMakeAnyLegalMove(state)) {
            return false; // Player has legal moves, not checkmate
        }

        // No legal moves and in check -> Checkmate
        return true;
    }

    /**
     * @notice Checks if the current state is stalemate for the player whose turn it is.
     * @dev Requires generating ALL legal moves. If no legal moves exist AND the king
     *      is NOT in check, it's stalemate. HIGH GAS COST.
     * @param encodedState The current encoded game state.
     * @return bool True if stalemate.
     */
    function isStalemate(uint256 encodedState) internal pure returns (bool) {
        DecodedState memory state = decode(encodedState);
        uint8 kingSquare = (state.turn == WHITE) ? state.whiteKingSquare : state.blackKingSquare;
        uint8 opponentColor = 1 - state.turn;

        // 1. Is the king currently in check?
        if (isSquareAttacked(state.board, kingSquare, opponentColor)) {
            return false; // In check, cannot be stalemate (could be checkmate)
        }

        // 2. Can the current player make *any* legal move?
        if (canPlayerMakeAnyLegalMove(state)) {
            return false; // Player has legal moves, not stalemate
        }

        // No legal moves and not in check -> Stalemate
        return true;
    }

    /**
     * @notice Generates and checks if *any* legal move exists for the current player.
     * @dev Very high gas cost. Iterates through all pieces, generates pseudo-legal moves,
     *      then checks each for self-check. Returns true on the first legal move found.
     * @param state Decoded state.
     * @return bool True if at least one legal move exists.
     */
    function canPlayerMakeAnyLegalMove(DecodedState memory state) internal pure returns (bool) {
        uint8 playerColor = state.turn;

        for (uint8 from = 0; from < BOARD_SIZE; from++) {
            uint8 pieceId = state.board[from];
            if (pieceId != EMPTY) {
                 uint8 currentPieceColor = getColor(state.board, from, playerColor); // Pass context color

                 if(currentPieceColor == playerColor) {
                    // Found a piece belonging to the current player, check its moves
                    uint8 baseType = getBasePieceType(pieceId, from); // Use context-aware version

                    // Check all possible target squares (0-63)
                    for (uint8 to = 0; to < BOARD_SIZE; to++) {
                        if (from == to) continue; // Cannot move to the same square

                        // Check for potential promotions
                        uint8[] memory possiblePromotions = new uint8[](5); // EMPTY, Q, R, B, N
                        possiblePromotions[0] = EMPTY; // Placeholder for non-promotion case
                        if (playerColor == WHITE) {
                            possiblePromotions[1] = W_QUEEN; possiblePromotions[2] = W_ROOK;
                            possiblePromotions[3] = W_BISHOP; possiblePromotions[4] = W_KNIGHT;
                        } else {
                            possiblePromotions[1] = B_QUEEN; possiblePromotions[2] = B_ROOK;
                            possiblePromotions[3] = B_BISHOP; possiblePromotions[4] = B_KNIGHT;
                        }

                        bool isPotentialPromotion = (baseType == W_PAWN) &&
                            ((playerColor == WHITE && from / 8 == 6 && to / 8 == 7) ||
                             (playerColor == BLACK && from / 8 == 1 && to / 8 == 0));

                        uint8 promotionStartIdx = isPotentialPromotion ? 1 : 0; // Start from index 1 for real promotions
                        uint8 promotionEndIdx = isPotentialPromotion ? 4 : 0; // End at index 4 for real promotions

                        for(uint promIdx = promotionStartIdx; promIdx <= promotionEndIdx; promIdx++) {
                            uint8 promotionPiece = possiblePromotions[promIdx]; // Use index 0 for non-promo, 1-4 for promo

                            // 1. Check pseudo-legal (geometry, basic rules)
                            if (isMovePseudoLegal(state, from, to, promotionPiece)) {
                                // 2. Simulate and check for self-check
                                DecodedState memory tempNextState = applyMove(state, from, to, promotionPiece);
                                uint8 kingSquareToCheck = (playerColor == WHITE) ? tempNextState.whiteKingSquare : tempNextState.blackKingSquare;

                                if (!isSquareAttacked(tempNextState.board, kingSquareToCheck, 1 - playerColor)) {
                                    // Found a legal move!
                                    return true;
                                }
                            }
                        } // end promotion loop
                    } // end target square loop
                } // end if piece belongs to player
            } // end if piece not empty
        } // end board iteration

        // If we finish the loop without finding any legal move
        return false;
    }

}
