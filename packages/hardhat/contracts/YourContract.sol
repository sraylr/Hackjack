pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  event SetPurpose(address sender, string purpose, uint blockNumber);

  string public purpose = "Building Unstoppable Apps!!!";

  constructor() payable {
    // what should we do on deploy?
  }

  function setPurpose(string memory newPurpose) public {
      purpose = newPurpose;
      // console.log(msg.sender,"set purpose to",purpose);
      // console.log()
      emit SetPurpose(msg.sender, purpose, block.number);
  }

  // to support receiving ETH by default
  receive() external payable {}
  fallback() external payable {}
}
