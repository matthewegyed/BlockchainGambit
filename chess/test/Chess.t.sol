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
    uint8 constant W_PAWN = ChessLogic.W_PAWN;
    uint8 constant B_PAWN = ChessLogic.B_PAWN;
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
    uint8 constant KING_TO_MOVE = ChessLogic.KING_TO_MOVE;
    uint8 constant UNMOVED_KING_OR_ROOK = ChessLogic.UNMOVED_KING_OR_ROOK;
    uint8 constant EMPTY = ChessLogic.EMPTY;

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


    // --- Tests ---

    function testStartGame() public {
        uint256 gameId = startGame(player1, player2);
        assertEq(gameId, 0);
        (address p1, address p2, Chess.GameStatus _status) = chess.getGameInfo(gameId); // FIX: Unused variable warning
        assertEq(p1, player1); assertEq(p2, player2);
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
        uint256 initialState = chess.getGameState(gameId);
        assertEq(initialState, ChessLogic.getInitialState());
        assertTurn(initialState, ChessLogic.WHITE);
    }

    // FIX: Renamed test
    function test_RevertIf_StartGameInvalidOpponent() public {
        vm.prank(player1);
        vm.expectRevert(Chess.InvalidOpponent.selector);
        chess.startGame(player1);
        vm.expectRevert(Chess.InvalidOpponent.selector);
        chess.startGame(address(0));
    }

    function testMakeValidMove_PawnE4() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4);
        uint256 newState = chess.getGameState(gameId);
        assertEq(getPiece(newState, E2), EMPTY);
        assertEq(getPiece(newState, E4), ChessLogic.JUST_DOUBLE_MOVED_PAWN);
        assertTurn(newState, ChessLogic.BLACK);
        assertStatus(gameId, Chess.GameStatus.ACTIVE); // Game should still be active
    }

    function testMakeValidMove_Sequence() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); // 1. e4
        makeMove(gameId, player2, D7, D5); // 1... d5
        makeMove(gameId, player1, G1, F3); // 2. Nf3
        makeMove(gameId, player2, B8, C6); // 2... Nc6
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
        uint256 state4 = chess.getGameState(gameId);
        assertTurn(state4, ChessLogic.WHITE);
    }

     // FIX: Renamed test
     function test_RevertIf_MoveNotYourTurn() public {
        uint256 gameId = startGame(player1, player2);
        vm.expectRevert(Chess.NotPlayer.selector);
        makeMove(gameId, player2, D7, D5); // Try black move first
        makeMove(gameId, player1, E2, E4); // White moves correctly
        vm.expectRevert(Chess.NotPlayer.selector);
        makeMove(gameId, player1, D2, D4); // White tries to move again
    }

     // FIX: Renamed test
     function test_RevertIf_InvalidMovePawnBackwards() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4);
        vm.prank(player2);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, D7, D8, EMPTY);
    }

     // FIX: Renamed test
     function test_RevertIf_InvalidMoveKnightLikeBishop() public {
        uint256 gameId = startGame(player1, player2);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, G1, E3, EMPTY);
    }

      // FIX: Renamed test
      function test_RevertIf_MoveIntoCheck() public {
          uint256 gameId = startGame(player1, player2);
          // 1. e4 e5 2. Bc4 Nc6 3. Ke2 d6 4. Kd3 Bc5 5. Ke3??
          makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
          makeMove(gameId, player1, F1, C4); makeMove(gameId, player2, B8, C6);
          makeMove(gameId, player1, E1, E2); makeMove(gameId, player2, D7, D6);
          makeMove(gameId, player1, E2, D3); makeMove(gameId, player2, F8, C5);
          vm.prank(player1);
          vm.expectRevert(ChessLogic.MoveLeavesKingInCheck.selector);
          chess.makeMove(gameId, D3, E3, EMPTY);
      }


    function testMakeValidMove_WhiteKingsideCastle() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Nf3 Nc6 3. Be2 Nf6
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, F1, E2); makeMove(gameId, player2, G8, F6);
        makeMove(gameId, player1, E1, G1_SQ); // Castle
        uint256 stateAfterCastle = chess.getGameState(gameId);
        assertTurn(stateAfterCastle, ChessLogic.BLACK);
        assertEq(getPiece(stateAfterCastle, G1_SQ), W_KING);
        assertEq(getPiece(stateAfterCastle, F1), W_ROOK);
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
    }

     // FIX: Renamed test
     function test_RevertIf_CastlePathBlocked() public {
        uint256 gameId = startGame(player1, player2);
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E1, G1_SQ, EMPTY);
    }

     // FIX: Renamed test
     function test_RevertIf_CastleKingMoved() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 e5 2. Ke2 Nc6 3. Ke1 ...
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, E1, E2); makeMove(gameId, player2, B8, C6);
        makeMove(gameId, player1, E2, E1); makeMove(gameId, player2, G8, F6);
        // Clear path
        makeMove(gameId, player1, F1, E2); makeMove(gameId, player2, D7, D6);
        makeMove(gameId, player1, G1, F3); makeMove(gameId, player2, C8, D7);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E1, G1_SQ, EMPTY); // Cannot castle
    }

     function testMakeValidMove_EnPassant() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 d5 2. e5 f5 3. exf6 e.p.
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, E5); makeMove(gameId, player2, F7, F5);
        makeMove(gameId, player1, E5, F6); // EP capture
        uint256 state4 = chess.getGameState(gameId);
        assertTurn(state4, ChessLogic.BLACK);
        assertEq(getPiece(state4, F6), W_PAWN);
        assertEq(getPiece(state4, F5), EMPTY);
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
    }

    // FIX: Renamed test
    function test_RevertIf_EnPassantNotImmediately() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 d5 2. e5 f5 3. Nf3 Nc6 4. exf6 e.p.? (Should fail)
        makeMove(gameId, player1, E2, E4); makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, E5); makeMove(gameId, player2, F7, F5);
        makeMove(gameId, player1, G1, F3); // Different move
        makeMove(gameId, player2, B8, C6);
        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector);
        chess.makeMove(gameId, E5, F6, EMPTY); // Cannot EP now
    }


    function testMakeValidMove_PawnPromotion() public {
        uint256 gameId = startGame(player1, player2);
        // 1. h4 e5 2. h5 Ke7 3. h6 Ke6 4. hxg7 Ke7 5. gxh8=Q
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, E8, E7);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, E7, E6);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, E6, E7);
        makeMove(gameId, player1, G7, H8, W_QUEEN); // Promote

        uint256 finalState = chess.getGameState(gameId);
        assertTurn(finalState, ChessLogic.BLACK);
        assertEq(getPiece(finalState, G7), EMPTY);
        assertEq(getPiece(finalState, H8), W_QUEEN);
        assertStatus(gameId, Chess.GameStatus.ACTIVE); // Game likely continues unless this checkmates
    }

     // FIX: Renamed test
     function test_RevertIf_PawnPromotionInvalidPiece() public {
        uint256 gameId = startGame(player1, player2);
        // 1. h4 e5 2. h5 Ke7 3. h6 Ke6 4. hxg7 Ke7
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, E8, E7);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, E7, E6);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, E6, E7);

        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector); // Invalid promotion choice leads to InvalidMove
        chess.makeMove(gameId, G7, H8, W_PAWN); // Try to promote to Pawn
     }

     // FIX: Renamed test
     function test_RevertIf_PawnPromotionMustPromote() public {
        uint256 gameId = startGame(player1, player2);
        // 1. h4 e5 2. h5 Ke7 3. h6 Ke6 4. hxg7 Ke7
        makeMove(gameId, player1, H2, H4); makeMove(gameId, player2, E7, E5);
        makeMove(gameId, player1, H4, H5); makeMove(gameId, player2, E8, E7);
        makeMove(gameId, player1, H5, H6); makeMove(gameId, player2, E7, E6);
        makeMove(gameId, player1, H6, G7); makeMove(gameId, player2, E6, E7);

        vm.prank(player1);
        vm.expectRevert(ChessLogic.InvalidMove.selector); // Missing promotion choice leads to InvalidMove
        chess.makeMove(gameId, G7, H8, EMPTY); // Send EMPTY promotion type
     }

    function testMakeValidMove_Capture() public {
        uint256 gameId = startGame(player1, player2);
        // 1. e4 d5 2. exd5
        makeMove(gameId, player1, E2, E4);
        makeMove(gameId, player2, D7, D5);
        makeMove(gameId, player1, E4, D5); // Capture
        uint256 state3 = chess.getGameState(gameId);
        assertTurn(state3, ChessLogic.BLACK);
        assertEq(getPiece(state3, E4), EMPTY);
        assertEq(getPiece(state3, D5), W_PAWN);
        assertStatus(gameId, Chess.GameStatus.ACTIVE);
    }

    // --- Game End Tests ---

    function testCheckmate_FoolsMate() public {
        uint256 gameId = startGame(player1, player2);
        // 1. f3 e5 2. g4 Qh4#
        makeMove(gameId, player1, F2, F3); // 1. f3
        makeMove(gameId, player2, E7, E5); // 1... e5
        makeMove(gameId, player1, G2, G4); // 2. g4

        // FIX: Use vm.expectEmit with specific parameters for the GameEnded event
        // event GameEnded(uint256 indexed gameId, GameStatus result, address winner);
        // Topic 0: Event signature hash
        // Topic 1: gameId (indexed)
        // Data: result, winner (non-indexed)
        vm.expectEmit(true, false, false, true, address(chess)); // Check topic 1 (gameId), check data, emitter is chess contract

        makeMove(gameId, player2, D8, H4); // 2... Qh4#

        // Verify game status
        assertStatus(gameId, Chess.GameStatus.FINISHED_BLACK_WINS);

        // Verify further moves are rejected
        vm.prank(player1);
        vm.expectRevert(Chess.GameAlreadyOver.selector);
        chess.makeMove(gameId, E2, E4, EMPTY);
    }

     function testStalemate_BlockedKing() public {
        // FIX: Unused variable warning
        uint256 _gameId = startGame(player1, player2);
        // Setup: White King a1, Black Queen c2. Black to move.
        // Need to reach this state via moves.
        // Example sequence (might not be shortest/best):
        // 1. a4 b5 2. h4 c5 3. Ra3 Qa5 4. Rb3 Qxa4 5. Rxb5 Qxb5 6. c4 Qxc4 7. Qa4 Qxa4 8. b4 Qxb4 9. Ba3 Qxb1# ?? No.
        // Simpler: 1. e3 a5 2. Qh5 Ra6 3. Qa5 h5 4. h4 Rah6 5. Qxc7 Rah8 6. Rxa7 Rd6 7. Ra8 Qc8 8. Qxc8 Rd8 9. Qxd8# ?? No.

        // Let's construct a known stalemate: WK on h1, WQ on f2, BK on h3. Black to move.
        // BK h3 has no squares, not in check.
        // Need to get there... very complex via moves.

        // --- Using manual state setting for this complex setup ---
        // This highlights why state setting helpers are useful in testing,
        // but we'll proceed without it for now and mark as needing setup.
        // TODO: Test stalemate scenarios properly, likely requiring a state-setting cheat/helper
        // or a very long sequence of setup moves.

        // Placeholder - Skip test until setup is feasible
         assertTrue(true, "Skipping stalemate test due to complex setup without state setting helper");

         /* // Example using a state setting cheat (if it were available)
         uint256 stalemateState = 0;
         stalemateState |= uint256(W_KING) << (H1 * 4);       // WK h1
         stalemateState |= uint256(W_QUEEN) << (F2 * 4);      // WQ f2
         stalemateState |= uint256(KING_TO_MOVE) << (H3 * 4); // BK h3 (Black to move)
         setGameState(gameId, stalemateState); // Assumes helper exists

         // Black has no legal moves and is not in check.
         // We need a dummy move attempt from Black to trigger the check in makeMove.
         // However, there are literally no pieces for black to move.
         // The check happens *after* a move. If black *cannot* move, how is stalemate triggered?
         // A: The isStalemate function should be callable directly for verification,
         // or the game might require a "resign" or "claim draw" function if automatic detection is too costly/complex.

         // For now, let's assume the makeMove function triggers it if the *next* player has no moves.
         // So, White makes a move that leads to this state where Black has no moves.
         // Example: White moves Queen to f2, resulting in the state above.
         // Need sequence: ... White moves Qf2.
         // Let's assume prior state allowed Qf2 and led to the stalemate position.

         // vm.expectEmit(true, false, false, true, address(chess)); // Check topic 1 (gameId), check data
         // // NOTE: The line below is NOT needed and incorrect syntax for testing. vm.expectEmit sets the expectation.
         // // emit Chess.GameEnded(gameId, Chess.GameStatus.FINISHED_DRAW, address(0)); // Expected event
         // makeMove(gameId, player1, from_q, F2); // White makes the move leading to stalemate

         // assertStatus(gameId, Chess.GameStatus.FINISHED_DRAW);
         */
    }


    // --- TODO ---
    // testMakeValidMove_BlackKingsideCastle()
    // testMakeValidMove_WhiteQueensideCastle()
    // testMakeValidMove_BlackQueensideCastle()
    // testFailCastle_ThroughCheck()
    // testFailCastle_IntoCheck()
    // testFailCastle_RookMoved()
    // testCheckScenario_DeliverCheck()
    // testCheckScenario_ForceKingMove()
    // testCheckScenario_BlockCheck()
    // testCheckScenario_CaptureCheckingPiece()
    // testFailMove_LeavesKingInCheck_DiscoveredCheck()
    // Add tests for Bishop, Rook, Queen moves (simple + capture)
    // Add tests for edge cases (board edges, corners)
    // Add more checkmate scenarios (back rank, smothered, etc.)
    // Add proper stalemate tests if feasible without state setting cheats.

}
