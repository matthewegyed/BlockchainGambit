// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Chess} from "../src/Chess.sol";
import {ChessLogic} from "../src/ChessLogic.sol";

contract ChessTest is Test {
    Chess public chess;
    address player1 = vm.addr(1); // White
    address player2 = vm.addr(2); // Black

    // --- Piece Constants ---
    uint8 constant EMPTY = ChessLogic.EMPTY;
    uint8 constant W_PAWN = ChessLogic.W_PAWN;
    uint8 constant B_PAWN = ChessLogic.B_PAWN;
    uint8 constant JUST_DOUBLE_MOVED_PAWN = ChessLogic.JUST_DOUBLE_MOVED_PAWN;
    uint8 constant W_KNIGHT = ChessLogic.W_KNIGHT;
    uint8 constant B_KNIGHT = ChessLogic.B_KNIGHT;
    uint8 constant W_BISHOP = ChessLogic.W_BISHOP;
    uint8 constant B_BISHOP = ChessLogic.B_BISHOP;
    uint8 constant W_ROOK = ChessLogic.W_ROOK;
    uint8 constant B_ROOK = ChessLogic.B_ROOK;
    uint8 constant W_QUEEN = ChessLogic.W_QUEEN;
    uint8 constant B_QUEEN = ChessLogic.B_QUEEN;
    uint8 constant W_KING = ChessLogic.W_KING;
    uint8 constant B_KING = ChessLogic.B_KING;

    // --- Square Constants (0-63, a1=0, h8=63) ---
    // Ranks
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

    // Specific squares renamed for clarity (castle targets)
    uint8 constant G1_SQ = G1; // Kingside castle target for white king (alias)
    uint8 constant C1_SQ = C1; // Queenside castle target for white king (alias)
    uint8 constant G8_SQ = G8; // Kingside castle target for black king (alias)
    uint8 constant C8_SQ = C8; // Queenside castle target for black king (alias)
    uint8 constant F8_SQ = F8; // Alias for clarity if needed
    uint8 constant D8_SQ = D8; // Alias for clarity if needed

    function setUp() public {
        chess = new Chess();
    }

    // --- Test Helpers ---

    /** @notice Starts a game between p1 (White) and p2 (Black) */
    function startGame(address p1, address p2) internal returns (uint256 gameId) {
        vm.prank(p1);
        gameId = chess.startGame(p2);
    }

    /** @notice Makes a move with an optional promotion piece */
    function makeMove(uint256 gameId, address player, uint8 from, uint8 to, uint8 promotion) internal {
        vm.prank(player);
        chess.makeMove(gameId, from, to, promotion);
    }

    /** @notice Makes a standard move (no promotion) */
    function makeMove(uint256 gameId, address player, uint8 from, uint8 to) internal {
        makeMove(gameId, player, from, to, EMPTY);
    }

    /** @notice Gets the piece ID from the encoded state at a specific square */
    function getPiece(uint256 state, uint8 square) internal pure returns (uint8) {
        return uint8((state >> (square * 4)) & ChessLogic.SQUARE_MASK);
    }

    /** @notice Asserts the piece ID at a specific square */
    function assertPiece(uint256 state, uint8 square, uint8 expectedPiece, string memory message) internal pure {
        uint8 actualPiece = getPiece(state, square);
        assertEq(actualPiece, expectedPiece, message);
    }

    /** @notice Asserts the piece ID at a specific square (overload without message) */
    function assertPiece(uint256 state, uint8 square, uint8 expectedPiece) internal pure {
        uint8 actualPiece = getPiece(state, square);
        assertEq(actualPiece, expectedPiece);
    }

    /** @notice Asserts that the current turn in the decoded state matches the expected turn */
    function assertTurn(uint256 state, uint8 expectedTurn) internal pure {
         ChessLogic.DecodedState memory decoded = ChessLogic.decode(state);
         assertEq(decoded.turn, expectedTurn, "Incorrect player's turn");
    }

    /** @notice Asserts the game status */
    function assertStatus(uint256 gameId, Chess.GameStatus expectedStatus) internal view {
        (,, Chess.GameStatus status) = chess.getGameInfo(gameId);
        assertEq(uint(status), uint(expectedStatus), "Incorrect game status");
    }

    /** @notice Decodes state and asserts en passant target square */
    function assertEnPassantTarget(uint256 state, int16 expectedTarget) internal pure {
        ChessLogic.DecodedState memory decoded = ChessLogic.decode(state);
        assertEq(decoded.enPassantTargetSquare, expectedTarget, "Incorrect EP target");
    }

    /** @notice Decodes state and asserts castling rights */
    function assertCastlingRights(uint256 state, bool wk, bool wq, bool bk, bool bq) internal pure {
        ChessLogic.DecodedState memory decoded = ChessLogic.decode(state);
        assertEq(decoded.whiteKingsideCastle, wk, "Incorrect WK castle right");
        assertEq(decoded.whiteQueensideCastle, wq, "Incorrect WQ castle right");
        assertEq(decoded.blackKingsideCastle, bk, "Incorrect BK castle right");
        assertEq(decoded.blackQueensideCastle, bq, "Incorrect BQ castle right");
    }

    // --- Tests ---

    // --- Game Setup and Basic Validation ---
    function testStartGame() public {
        uint256 gameId = startGame(player1, player2);
        assertEq(gameId, 0);
        (address p1, address p2,) = chess.getGameInfo(gameId);
        assertEq(p1, player1); assertEq(p2, player2);
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
        uint256 initialState = chess.getGameState(gameId);
        assertEq(initialState, ChessLogic.getInitialState(), "Initial state mismatch");
        assertTurn(initialState, ChessLogic.WHITE);
        assertCastlingRights(initialState, true, true, true, true); // Check initial rights
        assertEnPassantTarget(initialState, -1);
    }

    function test_RevertIf_StartGameInvalidOpponent() public {
        vm.prank(player1);
        vm.expectRevert(Chess.InvalidOpponent.selector);
        chess.startGame(player1); // Cannot play against self
        vm.expectRevert(Chess.InvalidOpponent.selector);
        chess.startGame(address(0)); // Cannot play against zero address
    }

    function test_RevertIf_MoveOnNonExistentGame() public {
        vm.prank(player1);
        vm.expectRevert(Chess.GameNotFound.selector);
        chess.makeMove(999, E2, E4, EMPTY); // Game ID 999 doesn't exist
    }

    function test_RevertIf_MoveNotYourTurn() public {
        uint256 gameId = startGame(player1, player2);
        // Black tries to move first
        vm.prank(player2);
        vm.expectRevert(Chess.NotPlayer.selector); // Should fail because it's White's turn
        chess.makeMove(gameId, D7, D5, EMPTY);

        // White makes a valid move
        makeMove(gameId, player1, E2, E4);

        // White tries to move again
        vm.prank(player1);
        vm.expectRevert(Chess.NotPlayer.selector); // Should fail because it's Black's turn now
        chess.makeMove(gameId, D2, D4, EMPTY);
    }

    function test_RevertIf_MoveFromEmptySquare() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E3, E4, EMPTY); // Try moving from empty e3
    }

    function test_RevertIf_MoveOpponentPiece() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E7, E6, EMPTY); // White tries moving black pawn
    }

    function test_RevertIf_MoveToSameSquare() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidSquare.selector);
        chess.makeMove(gameId, E2, E2, EMPTY);
    }

    function test_RevertIf_MoveOutOfBounds() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidSquare.selector);
        chess.makeMove(gameId, E2, 64, EMPTY); // Square 64 is out of bounds
        // Test the second case (moving *from* out of bounds)
        // Since the first move reverted, the turn didn't change.
        vm.expectRevert(ChessLogic.InvalidSquare.selector);
        chess.makeMove(gameId, 64, E4, EMPTY);
    }

    // --- Basic Piece Moves ---

    function testPawn_SingleStep() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E3);
        uint256 s1 = chess.getGameState(gameId);
        assertPiece(s1, E2, EMPTY, "Pawn E2->E3: E2 not empty");
        assertPiece(s1, E3, W_PAWN, "Pawn E2->E3: E3 not W_PAWN");
        assertTurn(s1, ChessLogic.BLACK);
        makeMove(gameId, player2, D7, D6);
        uint256 s2 = chess.getGameState(gameId);
        assertPiece(s2, D7, EMPTY, "Pawn D7->D6: D7 not empty");
        assertPiece(s2, D6, B_PAWN, "Pawn D7->D6: D6 not B_PAWN");
        assertTurn(s2, ChessLogic.WHITE);
    }

    function testPawn_DoubleStep() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // White double step
        uint256 s1 = chess.getGameState(gameId);
        assertPiece(s1, E2, EMPTY, "Pawn E2->E4: E2 not empty");
        assertPiece(s1, E4, JUST_DOUBLE_MOVED_PAWN, "Pawn E2->E4: E4 not JUMP_PAWN");
        assertTurn(s1, ChessLogic.BLACK);
        assertEnPassantTarget(s1, int16(uint16(E3))); // EP target should be E3

        makeMove(gameId, player2, D7, D5); // Black double step
        uint256 s2 = chess.getGameState(gameId);
        assertPiece(s2, D7, EMPTY, "Pawn D7->D5: D7 not empty");
        assertPiece(s2, D5, JUST_DOUBLE_MOVED_PAWN, "Pawn D7->D5: D5 not JUMP_PAWN");
        assertPiece(s2, E4, W_PAWN, "Pawn D7->D5: E4 not W_PAWN (JUMP flag cleared)"); // Previous JUMP flag should clear
        assertTurn(s2, ChessLogic.WHITE);
        assertEnPassantTarget(s2, int16(uint16(D6))); // EP target should be D6
    }

    function testKnight_ValidMove() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, G1, F3); // Nf3
        uint256 s1 = chess.getGameState(gameId);
        assertPiece(s1, G1, EMPTY, "Knight G1->F3: G1 not empty");
        assertPiece(s1, F3, W_KNIGHT, "Knight G1->F3: F3 not W_KNIGHT");
        assertTurn(s1, ChessLogic.BLACK);
    }

    function testBishop_ValidMove() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // Need to open path
        makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, F1, C4); // Bc4
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, F1, EMPTY, "Bishop F1->C4: F1 not empty");
        assertPiece(s3, C4, W_BISHOP, "Bishop F1->C4: C4 not W_BISHOP");
        assertTurn(s3, ChessLogic.BLACK);
    }

    function testRook_ValidMove() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, A2, A4); // Open path
        makeMove(gameId, player2, B7, B6);
        makeMove(gameId, player1, A1, A3); // Ra3
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, A1, EMPTY, "Rook A1->A3: A1 not empty");
        assertPiece(s3, A3, W_ROOK & ~ChessLogic.UNMOVED_KING_OR_ROOK, "Rook A1->A3: A3 not W_ROOK (unmoved flag not cleared)");
        assertTurn(s3, ChessLogic.BLACK);
        assertCastlingRights(s3, true, false, true, true); // Lost WQ rights
    }

    function testQueen_ValidMoveDiagonal() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, D2, D4); // Open path
        makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, D1, H5); // Qh5
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, D1, EMPTY, "Queen D1->H5: D1 not empty");
        assertPiece(s3, H5, W_QUEEN, "Queen D1->H5: H5 not W_QUEEN");
        assertTurn(s3, ChessLogic.BLACK);
    }

     function testQueen_ValidMoveOrthogonal() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, D2, D4); // Open path
        makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, D1, D3); // Qd3
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, D1, EMPTY, "Queen D1->D3: D1 not empty");
        assertPiece(s3, D3, W_QUEEN, "Queen D1->D3: D3 not W_QUEEN");
        assertTurn(s3, ChessLogic.BLACK);
    }

    function testKing_ValidMove() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // Open path
        makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E1, E2); // Ke2
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, E1, EMPTY, "King E1->E2: E1 not empty");
        assertPiece(s3, E2, W_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "King E1->E2: E2 not W_KING (flags not cleared)");
        assertTurn(s3, ChessLogic.BLACK);
        assertCastlingRights(s3, false, false, true, true); // Lost both white rights
    }

    // --- Captures ---
    function testCapture_PawnTakesPawn() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4);
        makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, D5); // exd5
        uint256 s3 = chess.getGameState(gameId);
        assertPiece(s3, E4, EMPTY, "Capture exd5: E4 not empty");
        assertPiece(s3, D5, W_PAWN, "Capture exd5: D5 not W_PAWN");
        assertTurn(s3, ChessLogic.BLACK);
    }

    function testCapture_KnightTakesPawn() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4);
        makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, G1, F3);
        makeMove(gameId, player2, D5, E4); // Pawn takes pawn (setup)
        makeMove(gameId, player1, F3, E5); // Knight takes pawn
        uint256 s5 = chess.getGameState(gameId);
        assertPiece(s5, F3, EMPTY, "Capture Nxe5: F3 not empty");
        assertPiece(s5, E5, W_KNIGHT, "Capture Nxe5: E5 not W_KNIGHT");
        assertPiece(s5, E4, EMPTY, "Capture Nxe5: E4 (captured pawn) not empty");
        assertTurn(s5, ChessLogic.BLACK);
    }

    function test_RevertIf_CaptureOwnPiece() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E2, D2, EMPTY); // White pawn tries to capture white pawn
    }

    // --- En Passant ---
    function testEnPassant_Availability() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // White double step
        uint256 s1 = chess.getGameState(gameId);
        assertEnPassantTarget(s1, int16(uint16(E3))); // EP target should be E3

        makeMove(gameId, player2, A7, A6); // Black single step (EP target should clear)
        uint256 s2 = chess.getGameState(gameId);
        assertEnPassantTarget(s2, -1); // EP target should be cleared

        makeMove(gameId, player1, D2, D4); // White double step again
        uint256 s3 = chess.getGameState(gameId);
        assertEnPassantTarget(s3, int16(uint16(D3))); // EP target should be D3

        makeMove(gameId, player2, H7, H5); // Black double step
        uint256 s4 = chess.getGameState(gameId);
        assertEnPassantTarget(s4, int16(uint16(H6))); // EP target should be H6 (previous cleared)
    }

    function testEnPassant_Capture() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 d5 2. e5 f5 3. exf6 e.p.
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, E5); makeMove(gameId, player2, F7, F5); // Black double step, EP possible on f6
        uint256 s4 = chess.getGameState(gameId);
        assertEnPassantTarget(s4, int16(uint16(F6)));
        assertPiece(s4, F5, JUST_DOUBLE_MOVED_PAWN, "EP Setup: F5 not JUMP_PAWN");

        makeMove(gameId, player1, E5, F6); // White captures EP
        uint256 s5 = chess.getGameState(gameId);
        assertTurn(s5, ChessLogic.BLACK);
        assertPiece(s5, E5, EMPTY, "EP Capture: E5 not empty");
        assertPiece(s5, F6, W_PAWN, "EP Capture: F6 not W_PAWN");
        assertPiece(s5, F5, EMPTY, "EP Capture: F5 (captured pawn) not empty");
        assertEnPassantTarget(s5, -1); // EP target should be cleared after capture
    }

    function test_RevertIf_EnPassantNotImmediately() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 d5 2. e5 f5 3. Nf3 Nc6 4. exf6 e.p.? (Should fail)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, E5); makeMove(gameId, player2, F7, F5); // Black double step
        uint256 s4 = chess.getGameState(gameId);
        assertEnPassantTarget(s4, int16(uint16(F6))); // EP available

        makeMove(gameId, player1, G1, F3); // White makes a different move
        uint256 s5 = chess.getGameState(gameId);
        assertEnPassantTarget(s5, -1); // EP should be cleared

        makeMove(gameId, player2, B8, C6); // Black moves

        // White tries to capture EP now (should fail)
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E5, F6, EMPTY);
    }

    // --- Castling ---
    function testCastle_WhiteKingside_Success() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: 1. e4 e5 2. Nf3 Nc6 3. Be2 Nf6
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, F1, E2); makeMove(gameId, player2, G8, F6);
        uint256 s6 = chess.getGameState(gameId);
        assertCastlingRights(s6, true, true, true, true); // All rights intact

        makeMove(gameId, player1, E1, G1_SQ); // Castle Kingside O-O
        uint256 s7 = chess.getGameState(gameId);
        assertTurn(s7, ChessLogic.BLACK);
        assertPiece(s7, E1, EMPTY, "Castle WK: E1 not empty");
        assertPiece(s7, H1, EMPTY, "Castle WK: H1 not empty");
        assertPiece(s7, G1_SQ, W_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "Castle WK: G1 not W_KING (flags not cleared)");
        assertPiece(s7, F1, W_ROOK & ~ChessLogic.UNMOVED_KING_OR_ROOK, "Castle WK: F1 not W_ROOK (flags not cleared)");
        assertCastlingRights(s7, false, false, true, true); // White lost both rights
    }

     function testCastle_WhiteQueenside_Success() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: 1. d4 d5 2. Nc3 Nc6 3. Bf4 Bf5 4. Qd2 Qd7
        makeMove(gameId, player1, D2, D4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, B1, C3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, C1, F4); makeMove(gameId, player2, C8, F5);
        makeMove(gameId, player1, D1, D2); makeMove(gameId, player2, D8, D7);
        uint256 s8 = chess.getGameState(gameId);
        assertCastlingRights(s8, true, true, true, true); // All rights intact

        makeMove(gameId, player1, E1, C1_SQ); // Castle Queenside O-O-O
        uint256 s9 = chess.getGameState(gameId);
        assertTurn(s9, ChessLogic.BLACK);
        assertPiece(s9, E1, EMPTY, "Castle WQ: E1 not empty");
        assertPiece(s9, A1, EMPTY, "Castle WQ: A1 not empty");
        assertPiece(s9, C1_SQ, W_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "Castle WQ: C1 not W_KING (flags not cleared)");
        assertPiece(s9, D1, W_ROOK & ~ChessLogic.UNMOVED_KING_OR_ROOK, "Castle WQ: D1 not W_ROOK (flags not cleared)");
        assertCastlingRights(s9, false, false, true, true); // White lost both rights
    }

    function testCastle_BlackKingside_Success() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: 1. e4 e5 2. Nf3 Nf6 3. Bc4 Be7 4. Nc3 O-O
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, G8, F6);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, F8, E7); // Clear path for BK castle
        makeMove(gameId, player1, B1, C3); // White move
        uint256 s7 = chess.getGameState(gameId);
        assertCastlingRights(s7, true, true, true, true); // All rights intact

        makeMove(gameId, player2, E8, G8_SQ); // Black Castle Kingside O-O
        uint256 s8 = chess.getGameState(gameId);
        assertTurn(s8, ChessLogic.WHITE);
        assertPiece(s8, E8, EMPTY, "Castle BK: E8 not empty");
        assertPiece(s8, H8, EMPTY, "Castle BK: H8 not empty");
        assertPiece(s8, G8_SQ, B_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "Castle BK: G8 not B_KING (flags not cleared)");
        assertPiece(s8, F8_SQ, B_ROOK & ~ChessLogic.UNMOVED_KING_OR_ROOK, "Castle BK: F8 not B_ROOK (flags not cleared)");
        assertCastlingRights(s8, true, true, false, false); // Black lost both rights
    }

    function testCastle_BlackQueenside_Success() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: 1. d4 d5 2. Nc3 Nc6 3. Bf4 Bf5 4. Qd2 Qd7 5. e3 O-O-O
        makeMove(gameId, player1, D2, D4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, B1, C3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, C1, F4); makeMove(gameId, player2, C8, F5);
        makeMove(gameId, player1, D1, D2); makeMove(gameId, player2, D8, D7); // Clear path for BQ castle
        makeMove(gameId, player1, E2, E3); // White move
        uint256 s9 = chess.getGameState(gameId);
        assertCastlingRights(s9, true, true, true, true); // All rights intact

        makeMove(gameId, player2, E8, C8_SQ); // Black Castle Queenside O-O-O
        uint256 s10 = chess.getGameState(gameId);
        assertTurn(s10, ChessLogic.WHITE);
        assertPiece(s10, E8, EMPTY, "Castle BQ: E8 not empty");
        assertPiece(s10, A8, EMPTY, "Castle BQ: A8 not empty");
        assertPiece(s10, C8_SQ, B_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "Castle BQ: C8 not B_KING (flags not cleared)");
        assertPiece(s10, D8_SQ, B_ROOK & ~ChessLogic.UNMOVED_KING_OR_ROOK, "Castle BQ: D8 not B_ROOK (flags not cleared)");
        assertCastlingRights(s10, true, true, false, false); // Black lost both rights
    }

    function test_RevertIf_CastleWhileInCheck() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Nf3 Nc6 3. Bc4 Be7 4. Ng5 Bxg5?? 5. Qh5+ (Black King in check)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, F8, E7);
        makeMove(gameId, player1, F3, G5); makeMove(gameId, player2, E7, G5); // Black blunders bishop
        makeMove(gameId, player1, D1, H5); // Qh5+, Black king is now in check

        // Black tries to castle kingside while in check
        vm.prank(player2);
        vm.expectRevert(ChessLogic.InvalidMove.selector); // Cannot castle while in check
        chess.makeMove(gameId, E8, G8_SQ, EMPTY);
    }

    function test_RevertIf_CastleThroughCheck() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: White Queen on d3 attacks f1, preventing WK castle
        // 1. e4 e5 2. Nf3 Nc6 3. Be2 Bc5 4. O-O?? (Illegal)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, F1, E2); // Clear path for WK castle
        makeMove(gameId, player2, F8, C5); // Black bishop develops
        makeMove(gameId, player1, D2, D3); // White move
        makeMove(gameId, player2, D8, F6); // Black Queen attacks f1

        // White tries to castle kingside, passing through attacked f1
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector); // Cannot castle through check
        chess.makeMove(gameId, E1, G1_SQ, EMPTY);
    }

     function test_RevertIf_CastleIntoCheck() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: Black Queen on h4 attacks g1, preventing WK castle
        // 1. e4 h5 2. Nf3 Rh6 3. Be2 Qh4 4. O-O?? (Illegal)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, H8, H6);
        makeMove(gameId, player1, F1, E2); // Clear path for WK castle
        makeMove(gameId, player2, D8, H4); // Black Queen attacks g1

        // White tries to castle kingside, landing on attacked g1
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector); // Cannot castle into check
        chess.makeMove(gameId, E1, G1_SQ, EMPTY);
    }

    // --- Promotion ---
    function testPromotion_ToQueen() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: White pawn on g7, Black king on e7, White king on e1. White to move.
        // 1. g4 h5 2. g5 h4 3. g6 hxg6 4. h4 a5 5. h5 a4 6. h6 a3 7. hxg7 Ra4
        makeMove(gameId, player1, G2, G4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G4, G5); makeMove(gameId, player2, H5, H4);
        makeMove(gameId, player1, G5, G6); makeMove(gameId, player2, H4, G3); // Capture to clear path
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, A7, A5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, A5, A4);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, A4, A3);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, A8, A4); // Move rook out of way

        makeMove(gameId, player1, G7, H8, W_QUEEN); // Promote to Queen
        uint256 s15 = chess.getGameState(gameId);
        assertPiece(s15, G7, EMPTY, "Promo Q: G7 not empty");
        assertPiece(s15, H8, W_QUEEN, "Promo Q: H8 not W_QUEEN");
        assertTurn(s15, ChessLogic.BLACK);
    }

    function testPromotion_ToRook() public {
        uint256 gameId = startGame(player1, player2);
        // Setup similar to Queen promotion
        makeMove(gameId, player1, G2, G4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G4, G5); makeMove(gameId, player2, H5, H4);
        makeMove(gameId, player1, G5, G6); makeMove(gameId, player2, H4, G3);
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, A7, A5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, A5, A4);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, A4, A3);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, A8, A4);

        makeMove(gameId, player1, G7, H8, W_ROOK); // Promote to Rook
        uint256 s15 = chess.getGameState(gameId);
        assertPiece(s15, G7, EMPTY, "Promo R: G7 not empty");
        assertPiece(s15, H8, W_ROOK, "Promo R: H8 not W_ROOK");
        assertTurn(s15, ChessLogic.BLACK);
    }

     function testPromotion_ToBishop() public {
        uint256 gameId = startGame(player1, player2);
        // Setup similar to Queen promotion
        makeMove(gameId, player1, G2, G4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G4, G5); makeMove(gameId, player2, H5, H4);
        makeMove(gameId, player1, G5, G6); makeMove(gameId, player2, H4, G3);
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, A7, A5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, A5, A4);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, A4, A3);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, A8, A4);

        makeMove(gameId, player1, G7, H8, W_BISHOP); // Promote to Bishop
        uint256 s15 = chess.getGameState(gameId);
        assertPiece(s15, G7, EMPTY, "Promo B: G7 not empty");
        assertPiece(s15, H8, W_BISHOP, "Promo B: H8 not W_BISHOP");
        assertTurn(s15, ChessLogic.BLACK);
    }

     function testPromotion_ToKnight() public {
        uint256 gameId = startGame(player1, player2);
        // Setup similar to Queen promotion
        makeMove(gameId, player1, G2, G4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G4, G5); makeMove(gameId, player2, H5, H4);
        makeMove(gameId, player1, G5, G6); makeMove(gameId, player2, H4, G3);
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, A7, A5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, A5, A4);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, A4, A3);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, A8, A4);

        makeMove(gameId, player1, G7, H8, W_KNIGHT); // Promote to Knight
        uint256 s15 = chess.getGameState(gameId);
        assertPiece(s15, G7, EMPTY, "Promo N: G7 not empty");
        assertPiece(s15, H8, W_KNIGHT, "Promo N: H8 not W_KNIGHT");
        assertTurn(s15, ChessLogic.BLACK);
    }

    function testPromotion_WithCapture() public {
        uint256 gameId = startGame(player1, player2);
        // Setup: White pawn on g7, Black rook on h8. White to move.
        // 1. g4 h5 2. g5 h4 3. g6 hxg6 4. h4 a5 5. h5 a4 6. h6 a3 7. hxg7 Rh8
        makeMove(gameId, player1, G2, G4); makeMove(gameId, player2, H7, H5);
        makeMove(gameId, player1, G4, G5); makeMove(gameId, player2, H5, H4);
        makeMove(gameId, player1, G5, G6); makeMove(gameId, player2, H4, G3);
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, A7, A5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, A5, A4);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, A4, A3);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, A8, H8); // Place rook on h8

        makeMove(gameId, player1, G7, H8, W_QUEEN); // Promote to Queen by capturing rook
        uint256 s15 = chess.getGameState(gameId);
        assertPiece(s15, G7, EMPTY, "Promo Cap Q: G7 not empty");
        assertPiece(s15, H8, W_QUEEN, "Promo Cap Q: H8 not W_QUEEN");
        assertTurn(s15, ChessLogic.BLACK);
    }

    // --- Check and Checkmate ---
    function testCheck_DeliverCheck() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5 (checks black king)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, D1, H5); // Qh5+
        uint256 s5 = chess.getGameState(gameId);
        assertTurn(s5, ChessLogic.BLACK);
        // Verify black king is attacked
        ChessLogic.DecodedState memory decoded = ChessLogic.decode(s5);
        assertTrue(ChessLogic.isSquareAttacked(decoded.board, decoded.blackKingSquare, ChessLogic.WHITE), "Black king not in check");
    }

    function test_RevertIf_MoveLeavesKingInCheck() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6?? (Illegal - blocks check but leaves king attacked)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, D1, H5); // Qh5+
        vm.prank(player2);
        vm.expectRevert(ChessLogic.MoveLeavesKingInCheck.selector);
        chess.makeMove(gameId, G8, F6, EMPTY); // Nf6 is illegal
    }

    function testCheck_BlockCheck() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5+ (check) g6 (block)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, D1, H5); // Qh5+
        uint256 s5 = chess.getGameState(gameId);
        ChessLogic.DecodedState memory decoded5 = ChessLogic.decode(s5);
        assertTrue(ChessLogic.isSquareAttacked(decoded5.board, decoded5.blackKingSquare, ChessLogic.WHITE), "Check Block: Black king not initially in check");

        makeMove(gameId, player2, G7, G6); // Block with pawn
        uint256 s6 = chess.getGameState(gameId);
        assertTurn(s6, ChessLogic.WHITE);
        ChessLogic.DecodedState memory decoded6 = ChessLogic.decode(s6);
        assertFalse(ChessLogic.isSquareAttacked(decoded6.board, decoded6.blackKingSquare, ChessLogic.WHITE), "Check Block: Black king still in check after block");
    }

    function testCheck_CaptureCheckingPiece() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5+ (check) Nxh5 (capture)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, D1, H5); // Qh5+
        uint256 s5 = chess.getGameState(gameId);
        ChessLogic.DecodedState memory decoded5 = ChessLogic.decode(s5);
        assertTrue(ChessLogic.isSquareAttacked(decoded5.board, decoded5.blackKingSquare, ChessLogic.WHITE), "Check Capture: Black king not initially in check");

        makeMove(gameId, player2, G8, H6); // Prepare knight
        makeMove(gameId, player1, H5, F7); // Check again (sac queen for test)
        uint256 s7 = chess.getGameState(gameId);
        ChessLogic.DecodedState memory decoded7 = ChessLogic.decode(s7);
        assertTrue(ChessLogic.isSquareAttacked(decoded7.board, decoded7.blackKingSquare, ChessLogic.WHITE), "Check Capture: Black king not in check before capture");

        makeMove(gameId, player2, H6, F7); // Knight captures checking Queen
        uint256 s8 = chess.getGameState(gameId);
        assertTurn(s8, ChessLogic.WHITE);
        assertPiece(s8, F7, B_KNIGHT, "Check Capture: F7 not B_KNIGHT");
        ChessLogic.DecodedState memory decoded8 = ChessLogic.decode(s8);
        assertFalse(ChessLogic.isSquareAttacked(decoded8.board, decoded8.blackKingSquare, ChessLogic.WHITE), "Check Capture: Black king still in check after capture");
    }

     function testCheck_MoveKingOutOfCheck() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5+ (check) Ke7 (move king)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, D1, H5); // Qh5+
        uint256 s5 = chess.getGameState(gameId);
        ChessLogic.DecodedState memory decoded5 = ChessLogic.decode(s5);
        assertTrue(ChessLogic.isSquareAttacked(decoded5.board, decoded5.blackKingSquare, ChessLogic.WHITE), "Check Move King: Black king not initially in check");

        makeMove(gameId, player2, E8, E7); // Move King out of check
        uint256 s6 = chess.getGameState(gameId);
        assertTurn(s6, ChessLogic.WHITE);
        assertPiece(s6, E8, EMPTY, "Check Move King: E8 not empty");
        assertPiece(s6, E7, B_KING & ~ChessLogic.UNMOVED_KING_OR_ROOK & ~ChessLogic.KING_TO_MOVE, "Check Move King: E7 not B_KING");
        ChessLogic.DecodedState memory decoded6 = ChessLogic.decode(s6);
        assertFalse(ChessLogic.isSquareAttacked(decoded6.board, decoded6.blackKingSquare, ChessLogic.WHITE), "Check Move King: Black king still in check after move");
        assertCastlingRights(s6, true, true, false, false); // Black lost castling rights
    }

    // --- Regression / Edge Cases ---
    function testRegression_PawnDoublePushClearEP() public {
        // Ensure a double push correctly clears the opponent's prior EP flag.
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // White double push, EP target E3
        uint256 s1 = chess.getGameState(gameId);
        assertEnPassantTarget(s1, int16(uint16(E3)));

        makeMove(gameId, player2, D7, D5); // Black double push, EP target D6
        uint256 s2 = chess.getGameState(gameId);
        assertEnPassantTarget(s2, int16(uint16(D6))); // White's EP target should be gone
        assertPiece(s2, E4, W_PAWN, "White pawn E4 lost JUMP flag"); // Ensure white pawn ID reset
    }

    function testRegression_CaptureClearsEP() public {
        // Ensure a capture correctly clears the opponent's prior EP flag.
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // White double push, EP target E3
        uint256 s1 = chess.getGameState(gameId);
        assertEnPassantTarget(s1, int16(uint16(E3)));

        makeMove(gameId, player2, B8, C6); // Black makes non-pawn move
        uint256 s2 = chess.getGameState(gameId);
        assertEnPassantTarget(s2, -1); // EP target should be cleared
    }

    function testRegression_KingMoveClearsEP() public {
        // Ensure a king move correctly clears the opponent's prior EP flag.
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // White double push, EP target E3
        uint256 s1 = chess.getGameState(gameId);
        assertEnPassantTarget(s1, int16(uint16(E3)));

        makeMove(gameId, player2, E8, E7); // Black moves king
        uint256 s2 = chess.getGameState(gameId);
        assertEnPassantTarget(s2, -1); // EP target should be cleared
    }
}
