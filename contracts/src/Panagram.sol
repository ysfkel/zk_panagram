// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import{ Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {IVerifier} from "./Verifier.sol";
 
contract Panagram is ERC1155,Ownable {
    IVerifier public verifier;

    uint256 public currentRound;

    // Keep track of the winner of the current round
    address public currentRoundWinner; // initially address(0)

    // Mapping to track number of wins for each address
    mapping(address => uint256) public winnerWins;

    // Track which round a user last guessed correctly
    mapping(address => uint256) public lastCorrectGuessRound;

    bytes32 public answer; // hash of the answer
    uint256 public MIN_DURATION = 10800; // minimum of 3 hours to prevent owner stopping the round early
    uint256 public roundStartTime;
    uint64 public answerHash;
    // Events

    event Panagram__RoundStarted();
    event Panagram__NFTMinted(address winner, uint256 tokenId);
    event Panagram__VerifierUpdated(IVerifier verifier);
    event Panagram__ProofSucceeded(bool result);

    error Panagram__ZeroAddress();
    error Panagram__IncorrectGuess();
    error Panagram__NoRoundWinner();
    error Panagram__AlreadyAnsweredCorrectly();
    error Panagram__InvalidTokenId();
    error Panagram__FirstPanagramNotSet();
    error Panagram__MinTimeNotPassed(uint256 mintTimePassed, uint256 currentTimePassed);

    constructor(address _verifier)
       Ownable(msg.sender)
        ERC1155("ipfs://bafybeicqfc4ipkle34tgqv3gh7gccwhmr22qdg7p6k6oxon255mnwb6csi/{id}.json")
    {
        verifier = IVerifier(_verifier);
    }

    function contractURI() public pure returns (string memory) {
        return "ipfs://bafybeicqfc4ipkle34tgqv3gh7gccwhmr22qdg7p6k6oxon255mnwb6csi/collection.json";
    }


    // Only the owner can start and end the round
    function newRound(bytes32 _correctAnswer) external onlyOwner {
        // check if we need to initialize the first round
        if (roundStartTime == 0) {
            // this initializes the first round!
            roundStartTime = block.timestamp;
            answer = _correctAnswer;
        } else {
            // check the min duration has passed
            if (block.timestamp < roundStartTime + MIN_DURATION) {
                revert Panagram__MinTimeNotPassed(MIN_DURATION, block.timestamp - roundStartTime);
            }
            // there has to have been a winner to start a new round.
            if (currentRoundWinner == address(0)) {
                revert Panagram__NoRoundWinner();
            }
            answer = _correctAnswer;
            currentRoundWinner = address(0);
        }
        currentRound++;
        emit Panagram__RoundStarted();
    }

    function makeGuess(bytes calldata proof) external returns (bool) {
        if (currentRound == 0) {
            revert Panagram__FirstPanagramNotSet();
        }

        if (lastCorrectGuessRound[msg.sender] == currentRound) {
            revert Panagram__AlreadyAnsweredCorrectly();
        }

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = answer;
        publicInputs[1] = bytes32(uint256(uint160(msg.sender))); // hard code to prevent front-running!
        bool proofResult = verifier.verify(proof, publicInputs);
        emit Panagram__ProofSucceeded(proofResult);
        if (!proofResult) {
            revert Panagram__IncorrectGuess();
        }
        lastCorrectGuessRound[msg.sender] = currentRound;
        // If this is the first correct guess, s_currentRoundWinner will still be address(0) so mint NFT with id 1
        if (currentRoundWinner == address(0)) {
            currentRoundWinner = msg.sender;
            winnerWins[msg.sender]++; // Increment wins for the first winner
            _mint(msg.sender, 0, 1, ""); // Mint NFT with ID 0
            emit Panagram__NFTMinted(msg.sender, 0);
        } else {
            // If someone is the second or further correct guesser, mint NFT with id 2
            _mint(msg.sender, 1, 1, ""); // Mint NFT with ID 1
            emit Panagram__NFTMinted(msg.sender, 1);
        }
        return proofResult;
    }
 

//Panagram__VerifierUpdated
}
