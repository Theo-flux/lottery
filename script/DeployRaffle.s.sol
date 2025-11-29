// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateVRFSubscription, FundVRFSubscription, AddVRFConsumer} from "script/Interactions.s.sol";
import {Raffle} from "src/Raffle.sol";

contract DeployRaffle is Script {
    function deployContract() public returns(Raffle, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (block.chainid != 31337) {
            vm.startBroadcast();
        }
        if(config.subscriptionId == 0) {
            CreateVRFSubscription createVrfSubscription = new CreateVRFSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createVrfSubscription.createSubscription(config.vrfCoordinator);

            FundVRFSubscription fundVrfSubscription = new FundVRFSubscription();
            fundVrfSubscription.fundSubscription(config.subscriptionId, config.vrfCoordinator, config.link);
        }
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        if (block.chainid != 31337) {
            vm.stopBroadcast();
        }
        AddVRFConsumer addVrfConsumer = new AddVRFConsumer();
        addVrfConsumer.addConsumer(config.subscriptionId, config.vrfCoordinator, address(raffle));

        return (raffle, helperConfig);
    }

    function run() public {
        deployContract();
    }
}
