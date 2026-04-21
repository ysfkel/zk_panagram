pragma solidity 0.8.34;
import {Test, console} from "forge-std/Test.sol";
import {Panagram} from "../src/Panagram.sol";
import {IVerifier, HonkVerifier} from "../src/Verifier.sol";

contract PanagramTest is Test {
        address user = makeAddr("user");
    HonkVerifier public verifier;
    Panagram public panagram;
    uint256 constant NOIR_FIELD_MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617; // obtained from the Verifier contract, it is same as field elements in the circuit, and is the prime modulus of the BN254 scalar field used by Noir/Honk.  

    // we modulo the answer hash to fit it into a NOIR field
    // this is because the verifier expects the public inputs to be field elements,
    // i.e the maximum value of NOIR's field value is smaller than 2^256 which is soliditys uint256 and the size outputted by keccak, so we need to ensure our answer hash is also smaller than that,
    // In practice, this means we need to ensure the answer hash is less than the field modulus.
    // so by doing the modulo operation, we can ensure that the answer hash fits within the constraints
    // of the NOIR field and can be used as a public input for the verifier without causing any issues related to size or overflow.
    
    // this just means that the keccak hash is bigger than the field size expected by the verifier, so we need to take the modulo to ensure it fits within the field.

    // Noir circuit:
    //
    // fn main(guess_hash: Field, answer_hash: pub Field) {
    //     assert(guess_hash == answer_hash);
    // }
    //
    // Although the circuit uses u64, all public inputs are ultimately encoded as field elements (Fr)
    // for the Honk verifier.
    //
    // The verifier operates over a finite field (BN254 scalar field), so every public input must be
    // representable as a valid field element.
    //
    // This conversion ensures Solidity-calculated values are safely interpreted by the verifier
    // without encoding mismatch or invalid field representation.

    // keccak("triangles") produces a 256-bit hash (uint256 range: 0 → 2^256 - 1).
    // FIELD_MODULUS is the prime that defines the BN254 scalar field used by Noir/Honk.
    //
    // Since all circuit inputs must be valid field elements (0 ≤ x < FIELD_MODULUS),
    // we reduce the hash modulo FIELD_MODULUS to safely map it into the field.
    //
    // Result:
    // - A deterministic field element representing the hash
    // - Guaranteed to be valid for Noir public input encoding 
 
    bytes32 ANSWER = bytes32(uint256(keccak256("triangles")) % NOIR_FIELD_MODULUS);
   // bytes32 constant ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("triangles")) % NOIR_FIELD_MODULUS)))) % NOIR_FIELD_MODULUS);

    function setUp() public {
        // Deploy a mock verifier
        verifier = new HonkVerifier();
        // Deploy the Panagram contract with the mock verifier
        panagram = new Panagram(address(verifier));

        panagram.newRound(ANSWER);
    }

    function testCorrectGuessPasses() public {
        vm.prank(user);
        bytes32 guess = ANSWER; // The guess is correct
        bytes memory proof = _getProof(guess, ANSWER, user);
        panagram.makeGuess(proof);
        vm.assertEq(panagram.balanceOf(user,0), 1);
        vm.assertEq(panagram.balanceOf(user,1), 0);

        vm.prank(user);
        vm.expectRevert();
        panagram.makeGuess(proof); 
    }

    function testSecondGuessPasses() public {
        vm.prank(user);
        bytes32 guess = ANSWER; // The guess is correct
        bytes memory proof = _getProof(guess, ANSWER, user);
        panagram.makeGuess(proof);
        // only the first correct guesser gets the NFT with ID 0
        vm.assertEq(panagram.balanceOf(user,0), 1); 
        // subsequent correct guessers get the NFT with ID 1, so the first correct guesser should have 0 balance of NFT with ID 1
        vm.assertEq(panagram.balanceOf(user,1), 0); 


        // user 2
        address user2 = makeAddr("user2");
        bytes memory proof2 = _getProof(guess, ANSWER, user2);
        vm.prank(user2);
        panagram.makeGuess(proof2); 
        //only the first correct guesser gets the NFT with ID 0
        vm.assertEq(panagram.balanceOf(user2,0), 0); 
        // subsequent correct guessers get the NFT with ID 1
        vm.assertEq(panagram.balanceOf(user2,1), 1); 
    }


    function testSubmitWrongProofExpectFail() public {
        vm.prank(user);
        bytes32 guess = ANSWER; // The guess is correct
        bytes memory proof = _getProof(guess, ANSWER, user);
        panagram.makeGuess(proof);
        // only the first correct guesser gets the NFT with ID 0
        vm.assertEq(panagram.balanceOf(user,0), 1); 
        // subsequent correct guessers get the NFT with ID 1, so the first correct guesser should have 0 balance of NFT with ID 1
        vm.assertEq(panagram.balanceOf(user,1), 0); 


        // user 2
        address user2 = makeAddr("user2"); 
        vm.prank(user2);
        vm.expectRevert();
        // user2 submits  proof generated by user1
        panagram.makeGuess(proof);  
    }

    function testStartNewRound() public {
        vm.prank(user);
        bytes32 guess = ANSWER; // The guess is correct
        bytes memory proof = _getProof(guess, ANSWER, user);
        panagram.makeGuess(proof); 
        vm.assertEq(panagram.balanceOf(user,0), 1);  
        vm.assertEq(panagram.balanceOf(user,1), 0); 
        
        // new round
        vm.warp(panagram.MIN_DURATION() + 1);
        bytes32 newAnswer = bytes32(uint256(keccak256("circles")) % NOIR_FIELD_MODULUS);
        panagram.newRound(newAnswer);
        vm.assertEq(panagram.currentRound(), 2);
        vm.assertEq(panagram.currentRoundWinner(), address(0));
        vm.assertEq(panagram.answer(), newAnswer);
    }

    function incorrectGuessFails() public {
        vm.prank(user);
        bytes32 guess = bytes32(uint256(keccak256("wrong guess")) % NOIR_FIELD_MODULUS); // The guess is incorrect
        bytes memory proof = _getProof(guess, ANSWER, user);
        vm.expectRevert();
        panagram.makeGuess(proof);
    }
 

 

    function _getProof(bytes32  guess , bytes32 answer, address user) internal returns (bytes memory _proof) { 

        uint256 NUM_ARGS = 6; // guess_hash and answer_hash
        string[] memory args = new string[](NUM_ARGS);
        // npx tsx src/generate_proof.ts
        args[0] = "npx";
        args[1] = "tsx";
        args[2] = "js-scripts/generate_proof.ts";
        args[3] = vm.toString(guess);
        args[4] = vm.toString(answer);
        args[5] = vm.toString(user);
 
        bytes memory encodedProof = vm.ffi(args);
        _proof = abi.decode(encodedProof, (bytes));
       console.log(_proof.length);


    }
}
