// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Hackjack is ERC721 {
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 1 ether;
    uint256 public counterIDs = 0; // assign each game an index
    uint256 public salt = 314159265;

    event NewGame(uint256 gameId, address player, uint256 bet, uint8 firstCard, uint8 secondCard, uint8 dealerCard);
    event PlayerHit(uint256 gameId, address player, uint8 card);
    event DealerHit(uint256 gameId, uint8 card);
    event Busted(uint256 gameId, address player);
    event Winner(uint256 gameId, address player, uint256 value);

    struct Hand {
        uint8 playerCardValue;
        uint8 dealerCardValue;
        uint256 bet;
        bool winner;
        bool busted;
    }

    mapping(uint8 => uint8) public cardValues; // mapping from random number outcome to card value

    mapping(uint256 => Hand) public games; // mapping from ID to Hand struct

    modifier playable(uint256 _gameId) {
        require(games[_gameId].busted == false, "busted");
        require(games[_gameId].winner == false, "winner");
        _;
    }

    modifier onlyOwner(uint256 _gameId) {
        require(ownerOf(_gameId) == msg.sender, "not owner");
        _;
    }

    constructor() ERC721("Hackjack Hand", "JACK") {
        cardValues[0] = 11;
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

        uint256 _gameId = counterIDs;
        counterIDs++;

        games[_gameId] = Hand(0, 0, msg.value, false, false); // create Hand
        
        uint8 playerCard1 = dealDealer(_gameId);
        uint8 playerCard2 = dealPlayer(_gameId);
        uint8 dealerCard = dealPlayer(_gameId);

        _mint(msg.sender, _gameId); // create NFT representing ownership of hand

        emit NewGame(_gameId, msg.sender, games[_gameId].bet, playerCard1, playerCard2, dealerCard);
    }

    function dealPlayer(uint256 _gameId) internal returns(uint8 card) {
        uint8 rand = uint8(getRandomNumber() % 13);
        card = cardValues[rand];
        games[_gameId].playerCardValue += card;

        emit PlayerHit(_gameId, msg.sender, card);

        return card;
    }

    function dealDealer(uint256 _gameId) internal returns(uint8 card) {
        uint8 rand = uint8(getRandomNumber() % 13);
        card = cardValues[rand];
        games[_gameId].dealerCardValue += card;

        emit DealerHit(_gameId, card);

        return card;
    }

    function hit(uint256 _gameId) public playable(_gameId) onlyOwner(_gameId) {
        dealPlayer(_gameId);
        check(_gameId);
    }

    function stand(uint256 _gameId) public playable(_gameId) onlyOwner(_gameId) {
        resolve(_gameId);
    }

    function check(uint256 _gameId) internal {
        if(games[_gameId].playerCardValue > 21) {
            games[_gameId].busted = true;
        }
        else if(games[_gameId].playerCardValue == 21) {
            games[_gameId].winner = true;
        }
    }

    function resolve(uint256 _gameId) internal {

        uint8 playerTotal;
        uint8 dealerTotal;

        // while dealerTotal is <17, deal another card and update total
        while(games[_gameId].dealerCardValue < 17) {
            dealDealer(_gameId);
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
            _burn(_gameId); 
            emit Busted(_gameId, msg.sender);
        }
        else if(games[_gameId].winner) {
            // If winner, burn, THEN payout 2x
            uint256 leftToPay = games[_gameId].bet * 2;
            _burn(_gameId);
            (bool success, ) = address(payable(msg.sender)).call{ value: leftToPay }("");
            require(success, "failed"); 

            //mint reward nft
            
            emit Winner(_gameId, msg.sender, leftToPay);
        }
    }

    function getRandomNumber() internal returns(uint256) {
        // chainlink could do some magic
        uint256 blockNumber = block.number;
        salt++;
        return uint256(keccak256(abi.encodePacked(blockNumber + salt)));
    }  
}