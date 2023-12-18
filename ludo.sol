// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract LudoGame {
    address public admin;
    address[] public players;
    address public currentPlayer;

    enum PieceStatus { Home, Start, Playing, Finished }

    struct Piece {
        PieceStatus status;
        uint8 position;
    }

    mapping(address => Piece[4]) public playerPieces;
    mapping(address => bool) public hasJoined;
    mapping(address => uint256) public playerInvestments;

    uint256 public constant MINIMUM_ENTRY_FEE = 0.00000001 ether;
    uint256 public constant ADMIN_FEE_PERCENTAGE = 20;
    uint256 public constant BOARD_SIZE = 56;

    event PlayerMoved(address player, uint8 pieceIndex, uint8 newPosition);
    event PlayerJoined(address player);
    event GameWinner(address winner, uint256 totalPrize);

    constructor() {
        admin = msg.sender;
    }

    function joinGame() external payable {
        require(msg.value >= MINIMUM_ENTRY_FEE, "Insufficient entry fee");
        require(!hasJoined[msg.sender], "Already joined");

        if (hasJoined[msg.sender]) {
            require(playerInvestments[msg.sender] != 0, "Invalid operation");
        }

        hasJoined[msg.sender] = true;
        playerInvestments[msg.sender] = msg.value;

        if (!isPlayerInGame(msg.sender)) {
            players.push(msg.sender);
            emit PlayerJoined(msg.sender);
        }
    }

    function increaseEntryFee() external payable {
        require(msg.value >= MINIMUM_ENTRY_FEE, "Insufficient increase");
        require(hasJoined[msg.sender], "Not joined the game");

        playerInvestments[msg.sender] += msg.value;
    }

    function decreaseEntryFee(uint256 amount) external {
        require(amount >= MINIMUM_ENTRY_FEE, "Amount below minimum");
        require(hasJoined[msg.sender], "Not joined the game");

        playerInvestments[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function isPlayerInGame(address player) internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return true;
            }
        }
        return false;
    }

    function rollDice() external returns (uint8) {
        require(players.length == 4, "Not enough players yet");
        require(msg.sender == currentPlayer, "It's not your turn!");

        uint8 diceResult = uint8(block.timestamp % 6) + 1; // Very basic randomization (not secure)
        movePiece(diceResult);

        return diceResult;
    }

    function movePiece(uint8 steps) internal {
        Piece[4] storage pieces = playerPieces[currentPlayer];

        uint8 indexToMove;
        for (uint8 i = 0; i < 4; i++) {
            if (pieces[i].status == PieceStatus.Start) {
                indexToMove = i;
                break;
            }
        }

        if (pieces[indexToMove].status == PieceStatus.Start) {
            pieces[indexToMove].status = PieceStatus.Playing;
            pieces[indexToMove].position = 0;
            emit PlayerMoved(currentPlayer, indexToMove, 0);
        } else if (pieces[indexToMove].status == PieceStatus.Playing) {
            uint8 currentPosition = pieces[indexToMove].position;
            uint8 newPosition = uint8((currentPosition + steps) % BOARD_SIZE);

            pieces[indexToMove].position = newPosition;
            emit PlayerMoved(currentPlayer, indexToMove, newPosition);
        }

        if (pieces[indexToMove].position == BOARD_SIZE - 1) {
            endGame(currentPlayer);
        }

        nextPlayer();
    }

    function endGame(address winner) internal {
        uint256 adminFee = (address(this).balance * ADMIN_FEE_PERCENTAGE) / 100;
        uint256 prizeAmount = address(this).balance - adminFee;

        (bool successAdmin, ) = admin.call{value: adminFee}("");
        require(successAdmin, "Admin fee transfer failed");

        (bool successWinner, ) = winner.call{value: prizeAmount}("");
        require(successWinner, "Winner's transfer failed");

        emit GameWinner(winner, prizeAmount);

        resetGame();
    }

    function resetGame() internal {
        for (uint8 i = 0; i < players.length; i++) {
            delete playerPieces[players[i]];
            hasJoined[players[i]] = false;
            playerInvestments[players[i]] = 0;
        }
        delete players;
        currentPlayer = address(0);
    }

    function nextPlayer() internal {
        uint8 index;
        for (uint8 i = 0; i < players.length; i++) {
            if (players[i] == currentPlayer) {
                index = i;
                break;
            }
        }

        if (index + 1 == players.length) {
            currentPlayer = players[0];
        } else {
            currentPlayer = players[index + 1];
        }
    }
}