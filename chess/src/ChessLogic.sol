// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    uint8 public constant WHITE = 0;
    uint8 public constant BLACK = 1;

    // --- Errors ---
    error InvalidMove();
    error MoveLeavesKingInCheck();

    // --- Decoded State Struct ---
    struct DecodedState {
        uint8[64] board;
        uint8 turn;
        // ...other fields as needed...
    }

    // --- Piece Type Helper ---
    function getBasePieceType(uint8 pieceId) internal pure returns (uint8) {
        if (
            pieceId == W_PAWN ||
            pieceId == B_PAWN ||
            pieceId == JUST_DOUBLE_MOVED_PAWN
        ) return 1; // Pawn
        if (pieceId == W_KNIGHT || pieceId == B_KNIGHT) return 2; // Knight
        if (pieceId == W_BISHOP || pieceId == B_BISHOP) return 3; // Bishop
        if (pieceId == W_ROOK || pieceId == B_ROOK) return 4; // Rook
        if (pieceId == W_QUEEN || pieceId == B_QUEEN) return 5; // Queen
        if (pieceId == W_KING || pieceId == B_KING) return 6; // King
        if (pieceId == EMPTY) return 0;
        revert("getBasePieceType requires square context for ID 12");
    }

    // --- Initial State ---
    function getInitialState() internal pure returns (uint256 state) {
        /*
        Board layout (0 = a1, 63 = h8):
        56 57 58 59 60 61 62 63
        48 49 50 51 52 53 54 55
        40 41 42 43 44 45 46 47
        32 33 34 35 36 37 38 39
        24 25 26 27 28 29 30 31
        16 17 18 19 20 21 22 23
         8  9 10 11 12 13 14 15
         0  1  2  3  4  5  6  7
        */
        uint8[64] memory board = [
            W_ROOK,
            W_KNIGHT,
            W_BISHOP,
            W_QUEEN,
            W_KING,
            W_BISHOP,
            W_KNIGHT,
            W_ROOK, // 0-7
            W_PAWN,
            W_PAWN,
            W_PAWN,
            W_PAWN,
            W_PAWN,
            W_PAWN,
            W_PAWN,
            W_PAWN, // 8-15
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY, // 16-23
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY, // 24-31
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY, // 32-39
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY,
            EMPTY, // 40-47
            B_PAWN,
            B_PAWN,
            B_PAWN,
            B_PAWN,
            B_PAWN,
            B_PAWN,
            B_PAWN,
            B_PAWN, // 48-55
            B_ROOK,
            B_KNIGHT,
            B_BISHOP,
            B_QUEEN,
            B_KING,
            B_BISHOP,
            B_KNIGHT,
            B_ROOK // 56-63
        ];
        for (uint8 i = 0; i < 64; i++) {
            state |= uint256(board[i]) << (i * 4);
        }
        return state;
    }

    // --- Decoding Helper ---
    function decode(
        uint256 state
    ) internal pure returns (DecodedState memory decoded) {
        for (uint8 i = 0; i < 64; i++) {
            decoded.board[i] = uint8((state >> (i * 4)) & SQUARE_MASK);
        }
        // Extract turn from bit 255 (if set, it's black's turn)
        decoded.turn = (state >> 255) & 1 == 1 ? BLACK : WHITE;
    }

    // ...existing code...
}
