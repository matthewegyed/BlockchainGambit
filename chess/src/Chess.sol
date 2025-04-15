// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChessLogic} from "./ChessLogic.sol";

contract Chess {
    enum GameStatus {
        NONE,
        ACTIVE,
        ENDED
    }
    error InvalidOpponent();
    error NotPlayer();

    event GameStarted(uint256 indexed gameId, address white, address black);
    event MoveMade(
        uint256 indexed gameId,
        address player,
        uint8 from,
        uint8 to,
        uint8 promotion
    );

    struct Game {
        address white;
        address black;
        GameStatus status;
        uint256 state;
    }

    mapping(uint256 => Game) public games;
    uint256 public nextGameId;

    function startGame(address opponent) external returns (uint256 gameId) {
        if (opponent == address(0) || opponent == msg.sender)
            revert InvalidOpponent();
        gameId = nextGameId++;
        games[gameId] = Game({
            white: msg.sender,
            black: opponent,
            status: GameStatus.ACTIVE,
            state: ChessLogic.getInitialState()
        });
        emit GameStarted(gameId, msg.sender, opponent);
    }

    function makeMove(
        uint256 gameId,
        uint8 from,
        uint8 to,
        uint8 promotion
    ) external {
        Game storage game = games[gameId];
        if (game.status != GameStatus.ACTIVE) revert();
        ChessLogic.DecodedState memory decoded = ChessLogic.decode(game.state);
        address player = (decoded.turn == ChessLogic.WHITE)
            ? game.white
            : game.black;
        if (msg.sender != player) revert NotPlayer();

        uint8 movingPiece = decoded.board[from];
        uint8 targetPiece = decoded.board[to];
        // Only allow pawn and knight moves for now
        bool isWhite = (decoded.turn == ChessLogic.WHITE);
        if (isWhite && movingPiece == ChessLogic.W_PAWN) {
            // e2 to e4 (from 12 to 28) or e2 to e3 (from 12 to 20)
            if (
                (int8(to) - int8(from) == 8 &&
                    targetPiece == ChessLogic.EMPTY) ||
                (from / 8 == 1 &&
                    int8(to) - int8(from) == 16 &&
                    targetPiece == ChessLogic.EMPTY)
            ) {
                // Move pawn
                decoded.board[to] = (int8(to) - int8(from) == 16)
                    ? ChessLogic.JUST_DOUBLE_MOVED_PAWN
                    : ChessLogic.W_PAWN;
                decoded.board[from] = ChessLogic.EMPTY;
                decoded.turn = ChessLogic.BLACK;
            } else {
                revert ChessLogic.InvalidMove();
            }
        } else if (!isWhite && movingPiece == ChessLogic.B_PAWN) {
            // d7 to d5 (from 51 to 35) or d7 to d6 (from 51 to 43)
            if (
                (int8(from) - int8(to) == 8 &&
                    targetPiece == ChessLogic.EMPTY) ||
                (from / 8 == 6 &&
                    int8(from) - int8(to) == 16 &&
                    targetPiece == ChessLogic.EMPTY)
            ) {
                // Move pawn
                decoded.board[to] = (int8(from) - int8(to) == 16)
                    ? ChessLogic.JUST_DOUBLE_MOVED_PAWN
                    : ChessLogic.B_PAWN;
                decoded.board[from] = ChessLogic.EMPTY;
                decoded.turn = ChessLogic.WHITE;
            } else {
                revert ChessLogic.InvalidMove();
            }
        } else if (
            (isWhite && movingPiece == ChessLogic.W_KNIGHT) ||
            (!isWhite && movingPiece == ChessLogic.B_KNIGHT)
        ) {
            // Knight move: must be L-shape and target is empty or opponent
            int8 dx = int8(int8(to % 8) - int8(from % 8));
            int8 dy = int8(int8(to / 8) - int8(from / 8));
            int8 adx = dx >= 0 ? dx : -dx;
            int8 ady = dy >= 0 ? dy : -dy;
            if (
                ((adx == 2 && ady == 1) || (adx == 1 && ady == 2)) &&
                (targetPiece == ChessLogic.EMPTY ||
                    (isWhite &&
                        targetPiece % 2 == 0 &&
                        targetPiece != ChessLogic.EMPTY) ||
                    (!isWhite && targetPiece % 2 == 1))
            ) {
                decoded.board[to] = movingPiece;
                decoded.board[from] = ChessLogic.EMPTY;
                decoded.turn = isWhite ? ChessLogic.BLACK : ChessLogic.WHITE;
            } else {
                revert ChessLogic.InvalidMove();
            }
        } else {
            revert ChessLogic.InvalidMove();
        }

        // Encode new state
        uint256 newState = 0;
        for (uint8 i = 0; i < 64; i++) {
            newState |= uint256(decoded.board[i]) << (i * 4);
        }
        // Store turn in highest bit (bit 255) instead of 256
        if (decoded.turn == ChessLogic.BLACK) {
            newState |= (1 << 255);
        }
        game.state = newState;
        emit MoveMade(gameId, msg.sender, from, to, promotion);
    }

    function getGameInfo(
        uint256 gameId
    ) external view returns (address, address, GameStatus) {
        Game storage game = games[gameId];
        return (game.white, game.black, game.status);
    }

    function getGameState(uint256 gameId) external view returns (uint256) {
        return games[gameId].state;
    }
}
