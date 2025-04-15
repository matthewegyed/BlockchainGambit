// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChessLogic} from "./ChessLogic.sol";

contract Chess {
    using ChessLogic for uint256;

    enum GameStatus {
        NONE,
        ACTIVE,
        FINISHED_WHITE_WINS,
        FINISHED_BLACK_WINS,
        FINISHED_DRAW
    }

    error InvalidOpponent();
    error NotPlayer();
    error GameAlreadyOver();

    event GameStarted(uint256 indexed gameId, address white, address black);
    event MoveMade(
        uint256 indexed gameId,
        address player,
        uint8 from,
        uint8 to,
        uint8 promotion
    );
    event GameEnded(uint256 indexed gameId, GameStatus result, address winner);

    struct Game {
        address white;
        address black;
        GameStatus status;
        uint256 state;
    }

    mapping(uint256 => Game) public games;
    uint256 public gameCount;

    function startGame(address opponent) external returns (uint256 gameId) {
        if (opponent == address(0) || opponent == msg.sender)
            revert InvalidOpponent();
        gameId = gameCount++;
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
        if (game.status != GameStatus.ACTIVE) revert GameAlreadyOver();
        address player = msg.sender;
        ChessLogic.DecodedState memory decoded = ChessLogic.decode(game.state);
        address expectedPlayer = decoded.turn == ChessLogic.WHITE
            ? game.white
            : game.black;
        if (player != expectedPlayer) revert NotPlayer();
        uint8 playerColor = decoded.turn;
        uint256 newState = ChessLogic.processMove(
            game.state,
            from,
            to,
            promotion,
            playerColor
        );
        game.state = newState;
        emit MoveMade(gameId, player, from, to, promotion);
        // Check for game end
        if (ChessLogic.isCheckmate(newState)) {
            game.status = playerColor == ChessLogic.WHITE
                ? GameStatus.FINISHED_WHITE_WINS
                : GameStatus.FINISHED_BLACK_WINS;
            emit GameEnded(gameId, game.status, player);
        } else if (ChessLogic.isStalemate(newState)) {
            game.status = GameStatus.FINISHED_DRAW;
            emit GameEnded(gameId, game.status, address(0));
        }
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
