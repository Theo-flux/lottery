// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
  
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle, RaffleEvents} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleUnitTest is CodeConstants, RaffleEvents, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public immutable PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    modifier raffleEntered {
        hoax(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;   
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWithInsufficientFeeError() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        hoax(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getRafflePlayers().length == 1);
        assert(raffle.getRafflePlayers()[0] == PLAYER);
    }

    function testRaffleEmitsRaffleEnteredEvent() public {
        hoax(PLAYER, STARTING_BALANCE);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testPauseRaffleWhenRaffleStateIsCalculating() public raffleEntered {
        raffle.performUpkeep();
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepWhenRaffleHasNoBallance() public {
        hoax(PLAYER, STARTING_BALANCE);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseWhenRaffleStateIsNotOpen() public raffleEntered {
        raffle.performUpkeep();

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function testPerformUpKeepRevertsWhenNoUpKeepNeeded() public {
        hoax(PLAYER, STARTING_BALANCE);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, address(raffle).balance, raffle.getRafflePlayers().length, uint256(raffle.getRaffleState())));
        raffle.performUpkeep();
    }

    function testPerformUpKeepNeededWithRaffleRequesuIdWinnerEvent() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
        assert(uint256(uint256(raffle.getRaffleState())) == 1);
    }

    function testFulfillRandomWordsCalledOnlyAfterPerformUpKeep(uint256 _randomId) public skipFork raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(_randomId, address(raffle));
    }

    function testFulfillRandomWordsCalledSuccessfullyResetsRaffle() public skipFork raffleEntered {
        uint160 additionalPlayers = 4; // Total of 5 players
        uint160 startingIndex = 1;

        for (uint160 i = startingIndex; i < startingIndex + additionalPlayers; i++) {
            address newPlayer = address(i);
            hoax(newPlayer, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startimestamp = raffle.getLastTimestamp();
        uint256 raffleStartPlayersLength = raffle.getRafflePlayers().length;

        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        uint256 raffleState = uint256(raffle.getRaffleState());
        uint256 endTimestamp = raffle.getLastTimestamp();
        uint256 raffleEndPlayersLength = raffle.getRafflePlayers().length;

        assert(raffleState == 0);
        assert(endTimestamp > startimestamp);
        assert(raffleStartPlayersLength == additionalPlayers + startingIndex);
        assert(raffleEndPlayersLength == 0);
    }
}
