// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract VotingSystem {
    address private owner; // Store the address of the owner of this contarct
    uint256 private totalVoters = 0;
    uint32 private totalCandidate = 0;
    uint32 private voteId;
    uint32 private winnerId;
    uint256 private previousVotes = 0;

    enum VoteStatus{
        STARTED,
        STOPED
    }

    VoteStatus voteStatus = VoteStatus.STOPED;

    struct candidates {
        string name;
        address addr;
        mapping(uint32 => uint256[]) votes;
        mapping(uint32 => uint256) totalVotes;
    }

    struct voters {
        string name;
        bytes32 proof; 
        address addr;
        mapping(uint32 => address) voteIds;
    }

    event registerVoter(address indexed voterAddress, uint256 indexed voterId, string name);
    event newCandidate(address indexed candidateAddress, uint32 indexed candidateId, string name);

    mapping(uint256 => voters) private votersInfo; // map voterId to info
    mapping(address => uint256) private voterToVoterId; // map voter address with vote id
    mapping(uint32 => candidates) private candidateInfo; // map candidateId to info
    mapping(address => uint32) private candidateId; // map address with candidateId
    mapping(uint32 => uint256) private countVotes;
    mapping(uint32 => uint32) private winnerByVoteId;
    


    modifier onlyOwner() {
        require(msg.sender == owner, "Sorry, can be only called by owner");
        _;
    }

    modifier onlyVoter() {
        require(voterToVoterId[msg.sender] > 0, "Please register first");
        _;
    }

    modifier onlyWhenVoteStarted() {
        require(voteStatus == VoteStatus.STARTED, "Voting is not started yet, Please wait!");
        _;
    }

    modifier onlyWhenVoteStop() {
        require(voteStatus == VoteStatus.STOPED, "Voting is running");
        _;
    }

    // Constructor to set the owner of the contract
    constructor() {
        owner = msg.sender;
    }

    // function to register for vote
    // Payable to prevent false registration
    function register(
        string memory _name,
        string memory _proof
    ) external payable onlyWhenVoteStop returns(uint256, string memory){
        address addr = msg.sender;
        require(voterToVoterId[addr] == 0, "You are already registered");
        require(msg.value >= 1000000000000000, "Not enough to participate");
        require(bytes(_proof).length > 3 && bytes(_proof).length < 9, "Proof should be between 4 - 8 letters long");

        voterToVoterId[addr] = ++totalVoters;
        votersInfo[voterToVoterId[addr]].name = _name;
        votersInfo[voterToVoterId[addr]].addr = addr;

        bytes32 proof = keccak256(abi.encodePacked(_proof, voterToVoterId[addr]));
        votersInfo[voterToVoterId[addr]].proof = proof;

        emit registerVoter(addr, voterToVoterId[addr], _name);

        return (voterToVoterId[addr], "Please note your voterId");
    }

    //function to add candidate, Only owner can call it
    function addCandidates(address _addr, string memory _name) external onlyOwner onlyWhenVoteStop returns(uint32){
        require(candidateId[_addr] == 0, "Already added");
        
        candidateId[_addr] = ++totalCandidate;

        candidateInfo[candidateId[_addr]].name = _name;
        candidateInfo[candidateId[_addr]].addr = _addr;
        countVotes[candidateId[_addr]] = 0;

        emit newCandidate(_addr, candidateId[_addr], _name);
        return candidateId[_addr];
    }

    function vote(uint32 _candidateId, string memory _proof) external onlyVoter onlyWhenVoteStarted{
        require(_candidateId <= totalCandidate, "Candidate doesnt found");
        
        uint256 voterId = voterToVoterId[msg.sender];
        require(votersInfo[voterId].voteIds[voteId] == address(0), "You have already voted");

        bytes32 proofCheck = keccak256(abi.encodePacked(_proof, voterId));
        require(proofCheck == votersInfo[voterId].proof, "Proof doesn't matched");

        votersInfo[voterId].voteIds[voteId] = candidateInfo[_candidateId].addr;
        candidateInfo[_candidateId].votes[voteId].push(voterId);
        countVotes[_candidateId]++;
        uint256 currentVotes = countVotes[_candidateId];

        if(currentVotes > previousVotes) {
            previousVotes = currentVotes;
            winnerId = _candidateId;
        } 
    }

    function startVote() external onlyOwner {
        require(voteStatus == VoteStatus.STOPED, "Vote is already started");

        voteStatus = VoteStatus.STARTED;
    }


    function stopVote() external onlyOwner returns(uint32) {
        require(voteStatus == VoteStatus.STARTED, "Vote is already stoped");

        voteStatus = VoteStatus.STOPED;

        for(uint32 i=1; i<= totalCandidate; i++) {
            candidateInfo[i].totalVotes[voteId] = countVotes[i];
            countVotes[i] = 0;
        }

        winnerByVoteId[voteId] = winnerId;
        winnerId = 0;
        uint32 vi = voteId;
        voteId++;

        return (winnerByVoteId[vi]);        
    }


    function getWinner(uint32 _voteId) public view returns (uint32) {
        return (winnerByVoteId[_voteId]);    
    }

    // function to get the owner of contract
    function getOwner() public view returns(address) {
        return owner;
    }

    function getContractState() public view returns(VoteStatus) {
        return voteStatus;
    }

    function getVoterInfo(uint256 _voterId) public view returns (string memory, address) {
        return (votersInfo[_voterId].name, votersInfo[_voterId].addr);
    }

    function getVoterId(address _addr) public view returns (uint256) {
        return voterToVoterId[_addr];
    }

    function getCandidateInfo(uint32 _candidateId) public view returns(string memory, address) {
        return (candidateInfo[_candidateId].name, candidateInfo[_candidateId].addr );
    }

    function getCandidateId(address _addr) public view returns(uint32) {
        return candidateId[_addr];
    }

    function getVotesForCandidate(uint32 _candidateId, uint32 _voteId) public view returns (uint256[] memory) {
        return candidateInfo[_candidateId].votes[_voteId];
    }

    function getCurrentVoteId() public view returns(uint32) {
        return voteId;
    }

    function getTotalCandidate() public view returns(uint32) {
        return totalCandidate;
    }

    function getTotalVoters() public view returns(uint256) {
        return totalVoters;
    }
}