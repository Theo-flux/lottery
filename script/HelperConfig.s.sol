// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CommonBase} from "forge-std/Base.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // VRF Mock values
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_FEE = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    // Errors
    error HelperConfig__InvalidChainID();

    // Type declarations
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    // State variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor(){
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    // Functions
    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if(chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        }else {
            revert HelperConfig__InvalidChainID();
        }
    }

    function getSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 1e16,
            interval: 30, // 30 secs
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 20234868474368247569650686085149038017637592532061446017781408578151331199834,
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xEdD41e6675C4312121F11ED4450bA944734CbCC2
        });
    }

    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordintorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_FEE, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 1e16,
            interval: 30, // 30 secs
            vrfCoordinator: address(vrfCoordintorMock),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000, // 500,000 gas
            link: address(linkToken),
            account: CommonBase.DEFAULT_SENDER
        });
        return localNetworkConfig;
    }

    function getConfig() public returns(NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}