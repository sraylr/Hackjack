// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Hackjack is ERC721 {
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 1 ether;

    uint256 public counterIDs = 0; // assign each game an index

    event NewGame(uint256 gameId, address player, uint256 bet, uint8 firstCard, uint8 secondCard, uint8 dealerCard);
    event PlayerHit(uint256 gameId, address player, uint8 card);
    event DealerHit(uint256 gameId, uint8 card);
    event Busted(uint256 gameId, address player);
    event Winner(uint256 gameId, address player, uint256 value);

    struct Hand {
        uint8[] playerCards;
        uint8[] dealerCards;
        uint256 bet;
        bool winner;
        bool busted;
    }

    mapping(uint8 => uint8) public cardValues; // mapping from random number outcome to card value

    mapping(uint256 => Hand) public games; // mapping from ID to Hand struct

    modifier playable(_gameId) {
        require(games[_gameId].busted == false, "busted");
        require(games[_gameId].winner == false, "winner");
    }

    modifier onlyOwner(_gameId) {
        require(ownerOf(_gameId) == msg.sender, "not owner");
    }

    constructor(string memory _uri) ERC721(_uri) {
        cardValues[0] = 1; // or 11?? not sure how to do this
        cardValues[1] = 2;
        cardValues[2] = 3;
        cardValues[3] = 4;
        cardValues[4] = 5;
        cardValues[5] = 6;
        cardValues[6] = 7;
        cardValues[7] = 8;
        cardValues[8] = 9;
        cardValues[9] = 10;
        cardValues[10] = 10;
        cardValues[11] = 10;
        cardValues[12] = 10;
    }

    function newGame() public payable {
        require(msg.value >= minBet && msg.value <= maxBet, "Invalid bet amount"); // Enforce bet limits
        require(address(this).balance >= msg.value * 2); // Ensure contract has enough funds to pay // This could permanently kill the contract if balance ever drops below minBet * 2
        // TODO: need to mark bet winning value as unavailable in the contract to ensure funds are available for withdrawl in the case of a winning hand
        _gameId = counterIDs;
        counterIDs++;
        games[_gameId] = Hand([], [], msg.value, false, false); // create Hand
        _mint(msg.sender, _gameId); // create NFT representing ownership of hand
        
        dealDealer(_gameId);
        dealPlayer(_gameId);
        dealPlayer(_gameId);

        emit NewGame(_gameId, msg.sender, games[_gameId].bet, games[_gameId].playerCards[0], games[_gameId].playerCards[1], games[_gameId].dealerCards[0]);
    }

    function dealPlayer(uint256 _gameId) internal {
        rand = getRandomNumber() % 13;
        card = cardValues[rand];
        games[_gameId].playerCards.push(card);
        check(_gameId);

        emit PlayerHit(_gameId, msg.sender, card);
    }

    function dealDealer(uint256 _gameId) internal {
        rand = getRandomNumber() % 13;
        card = cardValues[rand];
        games[_gameId].dealerCards.push(card);

        emit DealerHit(_gameId, card);
    }

    function hit(_gameId) public playable onlyOwner {
        dealPlayer(_gameId);
        check(_gameId);
    }

    function stand(_gameId) public playable onlyOwner {
        resolve(_gameId);
    }

    function check(_gameId) internal view {
        cardTotal = getPlayerTotal(_gameId);

        if(cardTotal > 21) {
            games[_gameId].busted = true;
        }
        else if(cardTotal == 21) {
            games[_gameId].winner = true;
        }
    }

    function resolve(_gameId) internal {

        uint8 playerTotal;
        uint8 dealerTotal;

        // while dealerTotal is less than 17, deal another card and update total
        while(dealerTotal <= 16) {
            dealDealer(_gameId);
            dealerTotal = getDealerTotal(_gameId);
        }

        // check to see who won
        if(playerTotal > dealerTotal) {
            games[_gameId].winner = true;
        }
        else if(playerTotal == dealerTotal) {
            // somehow handle this, probably pay back initial bet exactly and make a tie/push event to go along with it
        }
        else if(playerTotal < dealerTotal) {
            // somehow handle this, but probably not like this
            games[_gameId].busted = true;
        }

        // end game
        if(games[_gameId].busted) {
            // If busted, burn
            _burn(msg.sender, _gameId); 
            emit Busted(_gameId, msg.sender);
        }
        else if(games[_gameId].winner) {
            // If winner, burn, THEN payout 2x
            leftToPay = games[_gameId].bet * 2;
            _burn(msg.sender, _gameId);
            (bool success, ) = address(payable(msg.sender)).call{ value: leftToPay }("");
            require(success, "failed"); 

            //mint reward nft
            emit Winner(_gameId, msg.sender, leftToPay);
        }
    }

    function getRandomNumber() internal {
        // chainlink does some magic
        return randomNumber;
    }  

    function getDealerTotal(uint256 _gameId) public view {
        uint256 total = 0;
        for(uint256 i = 0; i < games[_gameId].dealerCards.length; i++) {
            total = total + games[_gameId].dealerCards[i];
        }
        return total;
    }

    function getPlayerTotal(uint256 _gameId) public view {
        uint256 total = 0;
        for(uint256 i = 0; i < games[_gameId].playerCards.length; i++) {
            total = total + games[_gameId].playerCards[i];
        }
        return total;
    }
}