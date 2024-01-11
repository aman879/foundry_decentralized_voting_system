// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { VotingSystem } from "../src/VotingSystem.sol";

contract VotingSystemTest is Test{
    VotingSystem public vts;
    address public owner = vm.addr(1);
    address public firstCandidate = vm.addr(2);
    address public secondCandiate = vm.addr(3);
    address public thirdCandiate = vm.addr(4);
    uint256 public amount = 0.001 ether;

    enum VoteStatus{
        STARTED,
        STOPED
    }

    event registerVoter(address indexed voterAddress, uint256 indexed voterId, string name);
    event newCandidate(address indexed candidateAddress, uint32 indexed candidateId, string name);

    function setUp() public {
        vm.prank(owner);
        vts = new VotingSystem();
    }

    function testOwner() public {
        assertEq(vts.getOwner(), owner);
    }

    function testContractState() public {
        assertEq(uint8(vts.getContractState()), uint8(VoteStatus.STOPED));

        vm.startPrank(owner);

        vts.startVote();
        assertEq(uint8(vts.getContractState()), uint8(VoteStatus.STARTED));

        vts.stopVote();
        assertEq(uint8(vts.getContractState()), uint8(VoteStatus.STOPED));

        vm.stopPrank();
    }

    function testRegister() public {
        string memory proof = "abcd";

        vm.deal(vm.addr(5), 1 ether);
        vm.startPrank(vm.addr(5));

        // should fail register because of proof legth error
        vm.expectRevert("Proof should be between 4 - 8 letters long");
        vts.register{value: amount}("A", "abc");
        vm.expectRevert("Proof should be between 4 - 8 letters long");
        vts.register{value: amount}("A", "abcdabcde");

        // should fail to register if pay less
        vm.expectRevert("Not enough to participate");
        vts.register{value: 0.0001 ether}("A", proof);

        // should emit registerVoter event after registring succesfully
        vm.expectEmit(true, true, false, true);
        emit registerVoter(vm.addr(5), 1, "A");

        // should be succesfully registered
        vts.register{value: amount}("A", proof);
        assertEq(vts.getVoterId(vm.addr(5)), 1);

        // should fail if register again
        vm.expectRevert("You are already registered");
        vts.register{value: amount}("A", proof);

        vm.stopPrank();

        // should sucesfully update totalVoters
        vts.register{value: amount}("B", proof);
        assertEq(vts.getTotalVoters(), 2);

        vm.prank(owner);
        vts.startVote();

        vm.deal(vm.addr(6), 1 ether);
        vm.prank(vm.addr(6));

        // should fail if try to register after vote sarted
        vm.expectRevert("Voting is running");
        vts.register{value: amount}("B", proof);

    }


    function testAddCandidate() public {
        
        // should revert if not owner
        vm.expectRevert("Sorry, can be only called by owner");
        vts.addCandidates(firstCandidate, "C1");

        vm.startPrank(owner);

        // should revert if try to add candidate after voting start
        vts.startVote();
        vm.expectRevert("Voting is running");
        vts.addCandidates(firstCandidate, "C1");
        vts.stopVote();

        // should emit newCandidate after adding succesfully
        vm.expectEmit(true, true, false, true);
        emit newCandidate(firstCandidate, 1, "C1");

        // should succesfully add new candidate
        vts.addCandidates(firstCandidate, "C1");
        assertEq(vts.getCandidateId(firstCandidate), 1);

        // should revert if add same candidate again
        vm.expectRevert("Already added");
        vts.addCandidates(firstCandidate, "C2");

        vm.stopPrank();

        // should succesfully update totalCandidate
        assertEq(vts.getTotalCandidate(), 1);
    }

    function testVote() public {

        string memory _proof = "abcd";

        vm.startPrank(owner);
        vts.addCandidates(firstCandidate, "C1");
        vts.addCandidates(secondCandiate, "C2");
        vts.addCandidates(thirdCandiate, "C3");
        vm.stopPrank();

        address[] memory voters = new address[](8);

        for(uint256 i = 0; i < 8; i++) {
            voters[i] = vm.addr(5 + i);
            vm.deal(voters[i], 1 ether);

            vm.prank(voters[i]);
            vts.register{value: amount}("A", _proof); 
        }

        // should fail if voting not started
        vm.prank(voters[0]);
        vm.expectRevert("Voting is not started yet, Please wait!");
        vts.vote(1, _proof);

        vm.prank(owner);
        vts.startVote();

        vm.startPrank(voters[0]);
        // should fail if wrong proof
        vm.expectRevert("Proof doesn't matched");
        vts.vote(1, "abcdef");

        // should fail if wrong candidate
        vm.expectRevert("Candidate doesnt found");
        vts.vote(4, _proof);

        vm.stopPrank();

        for(uint256 i = 0; i < 8; i++) {
            if(i >= 0 && i <= 2) {
                vm.prank(voters[i]);
                vts.vote(1, _proof);
            } else if(i > 2 && i <= 3) {
                vm.prank(voters[i]);
                vts.vote(2, _proof);
            } else {
                vm.prank(voters[i]);
                vts.vote(3, _proof);
            }
        }

        vm.prank(voters[0]);
        // should revert if vote again
        vm.expectRevert("You have already voted");
        vts.vote(3, _proof);

        vm.prank(owner);
        vts.stopVote();

        // candidate 3 should be winner
        assertEq(vts.getWinner(0), 3);

        // voterId for candidate should be correct
        uint256[] memory cd = vts.getVotesForCandidate(3, 0);
        for (uint256 i = 0; i < cd.length; i++) {
            assertEq(cd[i], i + 5);
        }
    }
    
}