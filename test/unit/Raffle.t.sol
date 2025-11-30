// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle, RaffleEvents} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleUnitTest is RaffleEvents, Test {
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
}
