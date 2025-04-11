// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Chess} from "../src/Chess.sol";

contract ChessScript is Script {
    Chess public chessContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        chessContract = new Chess();
        console.log("Chess contract deployed at:", address(chessContract));

        vm.stopBroadcast();
    }
}
