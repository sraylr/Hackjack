// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract YourContract is ERC721 {
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 0.001 ether;
    uint8 public test = 2;

    uint256 public counterIDs = 0; // assign each game an index

    uint256 public salt = 314159265;

    event NewGame(
        uint256 gameId,
        address player,
        uint256 bet,
        uint8 firstCard,
        uint8 secondCard,
        uint8 dealerCard
    );
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

    mapping(uint256 => address) public handOwner; // Temp hand owner

    Hand[] public hands;

    modifier playable(uint256 _gameId) {
        require(hands[_gameId].busted == false, "busted");
        require(hands[_gameId].winner == false, "winner");
        _;
    }

    modifier onlyOwner(uint256 _gameId) {
        require(handOwner[_gameId] == msg.sender, "not owner");
        _;
    }

    constructor() ERC721("Hackjack Hand", "JACK") {
        cardValues[0] = 11; // A
        cardValues[1] = 2; // 2
        cardValues[2] = 3;
        cardValues[3] = 4;
        cardValues[4] = 5;
        cardValues[5] = 6;
        cardValues[6] = 7;
        cardValues[7] = 8;
        cardValues[8] = 9;
        cardValues[9] = 10; // 10
        cardValues[10] = 10;
        cardValues[11] = 10;
        cardValues[12] = 10; // K
    }

    function newGame() public payable {
        require(
            msg.value >= minBet && msg.value <= maxBet,
            "Invalid bet amount"
        );
        // Enforce bet limits
        // require(address(this).balance >= msg.value * 2); // Ensure contract has enough funds to pay // This could permanently kill the contract if balance ever drops below minBet * 2

        // TODO: need to mark bet winning value as unavailable in the contract to ensure funds are available for withdrawl in the case of a winning hand

        uint256 _gameId = counterIDs;
        console.log("New Game", _gameId);
        handOwner[_gameId] = msg.sender;
        Hand memory hand = Hand(
            new uint8[](0),
            new uint8[](0),
            msg.value,
            false,
            false
        );

        hands.push(hand);
        counterIDs++;

        uint8 playerCard1 = dealPlayer(_gameId);
        uint8 playerCard2 = dealPlayer(_gameId);
        uint8 dealerCard = dealDealer(_gameId);

        // _mint(msg.sender, _gameId); // create NFT representing ownership of hand

        emit NewGame(
            _gameId,
            msg.sender,
            msg.value,
            playerCard1,
            playerCard2,
            4
        );
    }

    function check_hand(uint256 _gameId) public view returns (Hand memory) {
        return hands[_gameId];
    }

    function dealPlayer(uint256 _gameId) public returns (uint8 card) {
        // Get Card
        card = dealCard();
        console.log("Deal Player Card Value", cardValues[card]);
        hands[_gameId].playerCards.push(card);
        emit PlayerHit(_gameId, msg.sender, card);
        return card;
    }

    function dealDealer(uint256 _gameId) internal returns (uint8 card) {
        // Get Card
        card = dealCard();
        console.log("Deal Dealer Card Value", cardValues[card]);
        hands[_gameId].dealerCards.push(card);
        emit DealerHit(_gameId, card);
        return card;
    }

    function calculateHandTotal(uint8[] memory hand)
        public
        view
        returns (uint8 handValue)
    {
        handValue = 0;
        for (uint i = 0; i < hand.length; i++) {
            handValue += cardValues[hand[i]];
        }
        console.log("Hand total", handValue);
    }

    function dealCard() internal returns (uint8 card) {
        card = uint8(getRandomNumber() % 13);
        console.log("Card dealt", card);
    }

    function hit(uint256 _gameId) public playable(_gameId) onlyOwner(_gameId) {
        console.log("Player hits", _gameId);
        dealPlayer(_gameId);
        checkPlayerBust(_gameId);
    }

    function stand(uint256 _gameId)
        public
        playable(_gameId)
        onlyOwner(_gameId)
    {
        console.log("Player stands", _gameId);
        resolve(_gameId);
    }

    function checkPlayerBust(uint256 _gameId) internal {
        uint8 playerHandTotal = calculateHandTotal(hands[_gameId].playerCards);
        if (playerHandTotal > 21) {
            hands[_gameId].busted = true;
            // TODO: Resolve Game correctly if player bust
        }
    }

    function resolve(uint256 _gameId) private {
        uint8 playerHandTotal = calculateHandTotal(hands[_gameId].playerCards);

        uint8 dealerHandTotal = calculateHandTotal(hands[_gameId].dealerCards);

        // While dealerTotal is <17, deal another card and update total
        while (dealerHandTotal < 17) {
            dealDealer(_gameId);
            dealerHandTotal = calculateHandTotal(hands[_gameId].dealerCards);
        }

        // Check to see who won

        // Player wins
        if (playerHandTotal > dealerHandTotal || dealerHandTotal > 21) {
            hands[_gameId].winner = true;
            // Send 2x bet back
            // TODO: Upgrade transfer to best practice
            // (bool success, ) = address(payable(msg.sender)).call{
            //     value: leftToPay
            // }("");
            // require(success, "failed");
            payable(msg.sender).transfer(hands[_gameId].bet * 2);
            emit Winner(_gameId, msg.sender, hands[_gameId].bet * 2);

            // TODO: Mint reward NFT
            // _mintReward(_gameId)

            // Tied
        } else if (playerHandTotal == dealerHandTotal) {
            hands[_gameId].winner = true;
            hands[_gameId].busted = true;
            // Send original bet back
            payable(msg.sender).transfer(hands[_gameId].bet);
            emit Busted(_gameId, msg.sender);

            // Player Loses
        } else if (playerHandTotal < dealerHandTotal) {
            hands[_gameId].busted = true;
            emit Busted(_gameId, msg.sender);
        }

        // TODO: Burn Game NFT
        // _burnGameNFT(_gameId);
    }

    function getRandomNumber() internal returns (uint256) {
        // chainlink could do some magic
        uint256 blockNumber = block.number;
        salt++;
        return uint256(keccak256(abi.encodePacked(blockNumber + salt)));
    }
}
