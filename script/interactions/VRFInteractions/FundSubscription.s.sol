// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DistributionHelperConfig} from "../../helperConfig/DistributionHelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3e18; // 3 LINK should be enough
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subId,
        address _linkTokenAddress
    ) public {
        console.log("Funding subscription with subscription ID: ", _subId);
        console.log("At chain ID: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();

            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subId,
                FUND_AMOUNT
            );

            vm.stopBroadcast();
        } else {
            // just transfer the link token
            vm.startBroadcast();

            MockLinkToken(_linkTokenAddress).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subId)
            );

            vm.stopBroadcast();
        }

        console.log("Funded subscription with: ", FUND_AMOUNT);
        console.log("Funding transaction complete!");
    }

    function run() external {
        DistributionHelperConfig helperConfig = new DistributionHelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;
        uint256 subId = helperConfig.getActiveNetworkConfig().subscriptionId;
        address linkTokenAddress = helperConfig
            .getActiveNetworkConfig()
            .linkTokenAddress;

        fundSubscription(vrfCoordinator, subId, linkTokenAddress);
    }
}
