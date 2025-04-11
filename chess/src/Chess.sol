// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChessLogic} from "./ChessLogic.sol";

/**
 * @title On-Chain Chess Contract
 * @notice Allows two players to play a game of chess, enforcing rules via ChessLogic library.
 * @dev Stores game state compactly using a 256-bit integer. Includes checkmate/stalemate detection.
 */
contract Chess {
    using ChessLogic for uint256; // Attach library functions to uint256 state
    using ChessLogic for ChessLogic.DecodedState; // Attach library functions to DecodedState

    // --- Structs ---

    enum GameStatus { NOT_STARTED, ACTIVE, FINISHED_WHITE_WINS, FINISHED_BLACK_WINS, FINISHED_DRAW }

    struct Game {
        address player1; // White
        address player2; // Black
        uint256 encodedState; // Compact 256-bit game state
        GameStatus status;
    }

    // --- State Variables ---

    mapping(uint256 => Game) public games;
    uint256 public nextGameId;

    // --- Events ---

    event GameStarted(uint256 indexed gameId, address indexed player1, address indexed player2);
    event MoveMade(uint256 indexed gameId, address indexed player, uint8 fromSquare, uint8 toSquare, uint8 promotionPieceType, uint256 newState);
    event GameEnded(uint256 indexed gameId, GameStatus result, address winner); // Winner is address(0) for draw

    // --- Errors ---
    error GameNotFound();
    error NotPlayer();
    error GameNotActive();
    error InvalidOpponent();
    error AlreadyInGame(); // Optional: prevent player from being in multiple active games
    error GameAlreadyOver(); // Added for clarity

    // --- Functions ---

    /**
     * @notice Starts a new chess game with the caller as player1 (White) and the specified opponent as player2 (Black).
     * @param _opponent The address of the player to invite (player2, Black).
     * @return gameId The ID of the newly created game.
     */
    function startGame(address _opponent) external returns (uint256 gameId) {
        if (_opponent == address(0) || _opponent == msg.sender) {
            revert InvalidOpponent();
        }
        // Optional: Check if players are already in an active game

        gameId = nextGameId++;
        Game storage newGame = games[gameId];

        newGame.player1 = msg.sender;
        newGame.player2 = _opponent;
        newGame.encodedState = ChessLogic.getInitialState();
        newGame.status = GameStatus.ACTIVE;

        emit GameStarted(gameId, msg.sender, _opponent);
        return gameId;
    }

    /**
     * @notice Makes a move in an active game. Checks for checkmate/stalemate after the move.
     * @param _gameId The ID of the game.
     * @param _fromSquare The starting square index (0-63, a1=0, h1=7, a8=56, h8=63).
     * @param _toSquare The ending square index (0-63).
     * @param _promotionPieceType The piece type to promote a pawn to (e.g., ChessLogic.W_QUEEN). Use ChessLogic.EMPTY (0) if not a promotion.
     */
    function makeMove(
        uint256 _gameId,
        uint8 _fromSquare,
        uint8 _toSquare,
        uint8 _promotionPieceType
    ) external {
        Game storage game = games[_gameId];

        // 1. Check Game Status and Existence
        if (game.player1 == address(0)) { // Simple check for existence
            revert GameNotFound();
        }
        // Prevent moves if game is already finished
        if (game.status != GameStatus.ACTIVE) {
            revert GameAlreadyOver();
        }

        // 2. Determine Player Color and Validate Sender
        uint256 currentState = game.encodedState;
        ChessLogic.DecodedState memory tempState = ChessLogic.decode(currentState); // Decode once for turn check
        uint8 playerColor;

        if (tempState.turn == ChessLogic.WHITE) {
            if (msg.sender != game.player1) revert NotPlayer();
            playerColor = ChessLogic.WHITE;
        } else { // Black's turn
            if (msg.sender != game.player2) revert NotPlayer();
            playerColor = ChessLogic.BLACK;
        }

        // 3. Process Move using Logic Library (includes validation)
        // This call will revert with specific errors (InvalidMove, NotYourTurn, etc.) if validation fails.
        uint256 nextStateEncoded = ChessLogic.processMove(
            currentState,
            _fromSquare,
            _toSquare,
            _promotionPieceType,
            playerColor
        );

        // --- Post-Move Processing ---

        // 4. Update Game State
        game.encodedState = nextStateEncoded;

        // 5. Emit Move Event
        emit MoveMade(_gameId, msg.sender, _fromSquare, _toSquare, _promotionPieceType, nextStateEncoded);

        // 6. Check for Game End (Checkmate/Stalemate) for the *next* player to move
        // This logic is now active. BEWARE OF GAS COSTS.
        bool checkmate = ChessLogic.isCheckmate(nextStateEncoded);
        if (checkmate) {
             ChessLogic.DecodedState memory finalState = ChessLogic.decode(nextStateEncoded); // Decode again to get the turn *after* the move
             // If white is to move next and is checkmated, black wins.
             // If black is to move next and is checkmated, white wins.
             game.status = (finalState.turn == ChessLogic.WHITE) ? GameStatus.FINISHED_BLACK_WINS : GameStatus.FINISHED_WHITE_WINS;
             address winner = (game.status == GameStatus.FINISHED_WHITE_WINS) ? game.player1 : game.player2;
             emit GameEnded(_gameId, game.status, winner);
        } else {
            // Only check for stalemate if it's not checkmate
            bool stalemate = ChessLogic.isStalemate(nextStateEncoded);
             if (stalemate) {
                 game.status = GameStatus.FINISHED_DRAW;
                 emit GameEnded(_gameId, game.status, address(0));
             }
             // If neither checkmate nor stalemate, the game continues (status remains ACTIVE).
         }
    }

    /**
     * @notice Gets the current encoded state of a game.
     * @param _gameId The ID of the game.
     * @return The uint256 encoded game state.
     */
    function getGameState(uint256 _gameId) external view returns (uint256) {
        if (games[_gameId].player1 == address(0)) {
            revert GameNotFound();
        }
        return games[_gameId].encodedState;
    }

     /**
      * @notice Helper view function to decode a state for off-chain use or debugging.
      * @param _encodedState The state to decode.
      * @return Decoded state struct.
      */
    function decodeState(uint256 _encodedState) external pure returns (ChessLogic.DecodedState memory) {
        return ChessLogic.decode(_encodedState);
    }

     /**
      * @notice Helper view function to get game details.
      * @param _gameId The ID of the game.
      * @return player1 The address of player 1 (White).
      * @return player2 The address of player 2 (Black).
      * @return status The current status of the game.
      */
     function getGameInfo(uint256 _gameId) external view returns (address player1, address player2, GameStatus status) {
         Game storage game = games[_gameId];
         if (game.player1 == address(0)) {
             revert GameNotFound();
         }
         return (game.player1, game.player2, game.status);
     }
}
