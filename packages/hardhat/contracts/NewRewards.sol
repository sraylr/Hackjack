// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NewRewards is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 trophyVersion;

    constructor() ERC721("HackJack Rewards", "HJACK") {}

    //Needs to be deleted
    mapping(address=>bool) internal winner;

    //Needs to be deleted
    function setWinner(address player) external{
      winner[player]=true;
    }


    function getReward() public returns (uint256){
      //Needs to be deleted
      require(winner[msg.sender]==true,"You are not a winner!");
      winner[msg.sender]=false;
      _tokenIds.increment();
      string memory tokenURI="https://bafkreid5stht4gxpr45vt7cybz2hyrkomyj7tbgwaayuodfm2ohw5ltdwy.ipfs.nftstorage.link";
      string memory tokenURI2="https://bafkreie2twejhm23ned7gefcz3gyfayjma6gfksu755nnuvbtzygkqfkhi.ipfs.nftstorage.link";
      string memory tokenURI3="https://bafkreih7imbnovzy5epplwy6u3mfl4cpka6it36qg2rch2gb7lgacpgkou.ipfs.nftstorage.link";
      string memory tokenURI4="https://bafkreihlu3twljp4y7muavry6vcphbfc6k35c4iebiyk2i4kwyypmjqopq.ipfs.nftstorage.link";

      uint256 newItemId = _tokenIds.current();
      trophyVersion=4;

      if(trophyVersion==4){
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI4);
        trophyVersion-=1;
        return newItemId;
        }

      if(trophyVersion==3){
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI3);
        trophyVersion-=1;
        return newItemId;
          }

      if(trophyVersion==2){
          _mint(msg.sender, newItemId);
          _setTokenURI(newItemId, tokenURI2);
          trophyVersion-=1;
          return newItemId;
              }

      else{
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI);
            trophyVersion=4;
            return newItemId;
                  }



    }


}
