// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

abstract contract RaffleEvents {
    // events
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner);
}

/**
 * @title A simple Raffle lottery contract
 * @author Theophilus Ekunnusi
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle is RaffleEvents, VRFConsumerBaseV2Plus {
    // Errors
    error Raffle__InsufficientEntranceFee();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    // Type declarations
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    // state variables
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable I_ENTERANCE_FEE;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    uint256 private immutable I_INTERVAL; // duration of lottery in seconds
    
    address payable[] private sPlayers;
    uint256 private sLastTimestamp;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        I_ENTERANCE_FEE = _entranceFee;
        I_INTERVAL = _interval;
        I_KEY_HASH = _keyHash;
        I_SUBSCRIPTION_ID = _subscriptionId;
        I_CALLBACK_GAS_LIMIT = _callbackGasLimit;

        sLastTimestamp = block.timestamp;
        sRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < I_ENTERANCE_FEE) {
            revert Raffle__InsufficientEntranceFee();
        }
        sPlayers.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev Chainlink calls this function at interval to know if thr raffle is ready to pick its winner
     * The requirement for upKeepNeeded to true are:
     * 1. The contract has enough eth.
     * 2. The raffle interval has passed between raffle runs.
     * 3. The lottery is open.
     * 4. Implicitly, your chainlink subscription has LINK.
     * @param - ignored 
     * @return upKeepNeeded - true | false.
     * @return 
     */
    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upKeepNeeded,  bytes memory /* performData */)  {
        bool timeHasPassed = block.timestamp - sLastTimestamp >= I_INTERVAL;
        bool isOpen = sRaffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = sPlayers.length > 0;

        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upKeepNeeded, "");
    }

    function pickWinner() internal {
        sRaffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory randomWordsReqs = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        s_vrfCoordinator.requestRandomWords(randomWordsReqs);
    }

    function performUpkeep() external  {
        (bool upKeepNeeded, ) = checkUpkeep(""); 
        if(!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, sPlayers.length, uint256(sRaffleState));
        }
        pickWinner();
    }

    function _resetRaffle() internal {
        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimestamp = block.timestamp;
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];
        sRecentWinner = recentWinner;

        _resetRaffle();
        emit RaffleWinnerPicked(sRecentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
    }

    // Getter functions
    function getEntranceFee() external view returns (uint256) {
        return I_ENTERANCE_FEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return sRaffleState;
    }

    function getRafflePlayers() external view returns(address payable[] memory) {
        return sPlayers;
    }
}
