  uint256 nProposals;
  uint256 public session;

  mapping(address=>bool) public voter;
  mapping(uint =>Proposal) public proposals;

  event Voted(address sender, uint transactionId);
  event Submission(uint transactionId);
  event Execution(uint transactionId);
  event Deposit(address sender, uint value);
  event newVoter(address voter);

  struct Proposal{
    address payable recipient;
    uint value;
    uint nVotes;
    uint sessionId;
    bool executed;
  }

  constructor(){}

  receive() payable external{
    emit Deposit(msg.sender, msg.value);
  }

  function becomeVoter() public{
    require(balanceOf(msg.sender)>9,"You need more rewards");
    uint a=10;
    for(uint i=0; i<newItemId; i++){
    if(ownerOf(i)==msg.sender && a>0){
      _burn(i);
      a-=1;
      }
    }
    voter[msg.sender]=true;
    emit newVoter(msg.sender);
  }



  function executeProposal(uint proposalId) private{
    (bool success, )=proposals[proposalId].recipient.call{value: proposals[proposalId].value}("");
    require(success, "Failed to execute proposal");
    proposals[proposalId].executed=true;
    session+=1;
    emit Execution(proposalId);
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
