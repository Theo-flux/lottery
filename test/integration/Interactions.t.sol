// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateVRFSubscription, FundVRFSubscription} from "script/Interactions.s.sol";

contract InteractionsTest is Test {
    uint256 STARTING_BALANCE = 10 ether;
    address USER = makeAddr("user");
    Raffle raffle;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    address public vrfCoordinator;
    uint256 public subId;

    function setUp() external {
        DeployRaffle deployedRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployedRaffle.run();

        config = helperConfig.getConfig();
    }

    modifier createSub {
        CreateVRFSubscription createVrfSubscription = new CreateVRFSubscription();
        (subId, vrfCoordinator) = createVrfSubscription.createSubscription(config.vrfCoordinator, config.account);
        _;
    }

    function testCreateVrfSubscription() public createSub {
        assert(config.vrfCoordinator == vrfCoordinator);
        assert(subId != 0);
    }

    function testFundVrfSubscription() public createSub {        
        FundVRFSubscription fundVrfSubscription = new FundVRFSubscription();
        fundVrfSubscription.fundSubscription(subId, config.vrfCoordinator, config.link, config.account);

        uint96 balance;
        address subOwner;
        (balance, , ,subOwner, ) = VRFCoordinatorV2_5Mock(config.vrfCoordinator).getSubscription(subId);

        assert(config.account == subOwner);
        assert(balance == fundVrfSubscription.getSubscriptionAmount());
    }
}
