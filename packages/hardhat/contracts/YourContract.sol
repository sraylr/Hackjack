pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  // event SetPurpose(address sender, string purpose);

  uint public salt = 2171828;
  uint public blockNumber = 0;

  constructor() {
    // what should we do on deploy?
  }

  function getRandomNumber() public {
      blockNumber = block.number;
      salt++;
      console.log("Block number is",blockNumber);
      console.log(uint(keccak256(abi.encode(blockNumber * salt))));

      // emit SetPurpose(msg.sender, purpose);
  }
}
