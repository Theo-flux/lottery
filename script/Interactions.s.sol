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
        address account = helperConfig.getConfig().account;

        return createSubscription(vrfCoordinator, account);
    }

    function createSubscription(address _vrfCoordinator, address _account) public returns(uint256, address) {
        vm.startBroadcast(_account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        return (subId, _vrfCoordinator);
    }

    function run() external returns(uint256, address) {
        return getOrCreateSubscriptionFromConfig();
    }
}

contract FundVRFSubscription is Script, CodeConstants {
    uint256 private constant SUBSCRIPTION_AMOUNT = 3 ether; // 3 ether or 3 link

    function fundSubscriptionFromConfig() internal {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        fundSubscription(subscriptionId, vrfCoordinator, linkToken, account);
    }

    function fundSubscription(uint256 _subId, address _vrfCoordinator, address _linkToken, address _account) public {
        if(block.chainid == CodeConstants.LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subId, SUBSCRIPTION_AMOUNT * 100);
            vm.stopBroadcast();
        }else {
            vm.startBroadcast(_account);
            LinkToken(_linkToken).transferAndCall(_vrfCoordinator, SUBSCRIPTION_AMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionFromConfig();
    }

    // Getters
    function getSubscriptionAmount() external view returns(uint256) {
        if(block.chainid == CodeConstants.LOCAL_CHAIN_ID) {
            return SUBSCRIPTION_AMOUNT * 100;
        }
        return SUBSCRIPTION_AMOUNT;
    }
}

contract AddVRFConsumer is Script {
    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(subscriptionId, vrfCoordinator, account, _mostRecentlyDeployed);
    }

    function addConsumer(uint256 _subId, address _vrfCoordinator, address _account, address _consumer) public {
        console.log("Adding consumer contract:", _consumer);
        console.log("to vrfCoordinator:", _vrfCoordinator);
        console.log("on chainid:", block.chainid);
        console.log("current account:", _account);

        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _consumer);
        vm.stopBroadcast();

    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}