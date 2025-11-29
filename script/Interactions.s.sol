// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "@devops/DevOpsTools.sol";

import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateVRFSubscription is Script {

    function getOrCreateSubscriptionFromConfig() internal returns(uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address _vrfCoordinator) public returns(uint256, address) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        return (subId, _vrfCoordinator);
    }

    function run() external {
        getOrCreateSubscriptionFromConfig();
    }
}

contract FundVRFSubscription is Script, CodeConstants {
    uint256 private constant SUBSCRIPTION_AMOUNT = 3 ether; // 3 ether or 3 link

    function fundSubscriptionFromConfig() internal {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address linkToken = helperConfig.getConfig().link;

        fundSubscription(subscriptionId, vrfCoordinator, linkToken);
    }

    function fundSubscription(uint256 _subId, address _vrfCoordinator, address _linkToken) public {
        if(block.chainid == CodeConstants.LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subId, SUBSCRIPTION_AMOUNT);
            vm.stopBroadcast();
        }else {
            vm.startBroadcast();
            LinkToken(_linkToken).transferAndCall(_vrfCoordinator, SUBSCRIPTION_AMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionFromConfig();
    }
}

contract AddVRFConsumer is Script {
    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(subscriptionId, vrfCoordinator, _mostRecentlyDeployed);
    }

    function addConsumer(uint256 _subId, address _vrfCoordinator, address _consumer) public {
        console.log("Adding consumer contract:", _consumer);
        console.log("to vrfCoordinator:", _vrfCoordinator);
        console.log("on chainid:", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _consumer);
        vm.stopBroadcast();

    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}