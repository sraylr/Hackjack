// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract YourContract is ERC721URIStorage, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 2;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 trophyVersion;
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 0.001 ether;
    uint8 public test = 2;
    uint256 newItemId;

    uint256 public counterIDs = 0; // assign each game an index

    uint256 public salt = 314159265;
    uint256 nProposals;
    uint256 public session;

    mapping(address=>bool) public voter;
    mapping(uint =>Proposal) public proposals;


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
    event Voted(address sender, uint transactionId);
    event Submission(uint transactionId);

    struct Hand {
        uint8[] playerCards;
        uint8[] dealerCards;
        uint256 bet;
        bool winner;
        bool busted;
    }

    struct Proposal{
      address payable recipient;
      uint value;
      uint nVotes;
      uint sessionId;
      bool executed;
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

    constructor(uint64 subscriptionId)
        VRFConsumerBaseV2(vrfCoordinator)
        ERC721("Hackjack ", "HJACK")
    {
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
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }
receive() payable external{}

    function newGame() public payable {
        require(
            msg.value >= minBet && msg.value <= maxBet,
            "Invalid bet amount"
        );

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
            dealerCard
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

    function dealChainlinkCard() public returns (uint8 card) {
        requestRandomWords();
        card = 4;
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

        if (playerHandTotal > dealerHandTotal || dealerHandTotal > 21) {
            hands[_gameId].winner = true;

            payable(msg.sender).transfer(hands[_gameId].bet * 2);
            emit Winner(_gameId, msg.sender, hands[_gameId].bet * 2);
            getReward();

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

    }

    function getRandomNumber() internal returns (uint256) {
        // chainlink could do some magic
        uint256 blockNumber = block.number;
        salt++;
        return uint256(keccak256(abi.encodePacked(blockNumber + salt)));
    }

    function getReward() internal returns (uint256) {
        _tokenIds.increment();
        string
            memory tokenURI = "https://bafkreid5stht4gxpr45vt7cybz2hyrkomyj7tbgwaayuodfm2ohw5ltdwy.ipfs.nftstorage.link";
        string
            memory tokenURI2 = "https://bafkreie2twejhm23ned7gefcz3gyfayjma6gfksu755nnuvbtzygkqfkhi.ipfs.nftstorage.link";
        string
            memory tokenURI3 = "https://bafkreih7imbnovzy5epplwy6u3mfl4cpka6it36qg2rch2gb7lgacpgkou.ipfs.nftstorage.link";
        string
            memory tokenURI4 = "https://bafkreihlu3twljp4y7muavry6vcphbfc6k35c4iebiyk2i4kwyypmjqopq.ipfs.nftstorage.link";

        newItemId = _tokenIds.current();
        trophyVersion = 4;

        if (trophyVersion == 4) {
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI4);
            trophyVersion -= 1;
            return newItemId;
        }

        if (trophyVersion == 3) {
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI3);
            trophyVersion -= 1;
            return newItemId;
        }

        if (trophyVersion == 2) {
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI2);
            trophyVersion -= 1;
            return newItemId;
        } else {
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI);
            trophyVersion = 4;
            return newItemId;
        }
    }
    function requestRandomWords() internal {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }

    modifier onlyOwnerChain() {
        require(msg.sender == s_owner);
        _;
    }


    function becomeVoter() public{
      require(balanceOf(msg.sender)>9,"You need more rewards");
      uint a=10;
      for(uint i=1; i<=newItemId; i++){
      if(ownerOf(i)==msg.sender && a>0){
        _burn(i);
        a-=1;
        }
      }
      voter[msg.sender]=true;

    }
    function executeProposal(uint proposalId) private{
      (bool success, )=proposals[proposalId].recipient.call{value: proposals[proposalId].value}("");
      require(success, "Failed to execute proposal");
      proposals[proposalId].executed=true;
      session+=1;
    }

    function submitProposal(address payable _recipient, uint _value) public{
      require(voter[msg.sender]==true, "You are not a voter");
      require(_value<=address(this).balance, "Insufficient funds in the DAO");

      proposals[nProposals]=Proposal(_recipient, _value,0,session, false);

      emit Submission(nProposals);
      nProposals+=1;


    }
    function vote(uint proposalId) public{
      require(voter[msg.sender]==true, "You are not a voter");
      require(proposalId<=nProposals,"Incorrect ProposalId");
      require(proposals[proposalId].sessionId==session,"This Proposal has expired");

      proposals[proposalId].nVotes+=1;
      voter[msg.sender]=false;
      emit Voted(msg.sender, proposalId);

      if(proposals[proposalId].nVotes>9){
        executeProposal(proposalId);
      }

    }
    function voteCount(uint proposalId) public view returns (uint256){
      return proposals[proposalId].nVotes;
    }

}
