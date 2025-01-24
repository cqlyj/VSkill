// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {RelayerHelperConfig} from "script/helperConfig/RelayerHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

struct LogTriggerConfig {
    address contractAddress;
    uint8 filterSelector;
    bytes32 topic0;
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);
}

contract RegisterUpkeep is Script {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    LinkTokenInterface public linkToken;
    AutomationRegistrarInterface public automationRegistrar;
    RelayerHelperConfig public helperConfig;
    // Update this to your admin address
    address constant ADMIN_ADDRESS = 0xFB6a372F2F51a002b390D18693075157A459641F;
    uint96 constant AMOUNT = 5e18; // 5 LINK
    uint8 filterSelector = 0; // no filters for any of the topics
    // cast sig-event "RequestIdToRandomWordsUpdated(uint256 indexed)"
    // 0x2b005407f1018f36e2cf9fc723e08ecb38e1226febcb8426e71335c2eac203f0
    bytes32 topic0 =
        0x2b005407f1018f36e2cf9fc723e08ecb38e1226febcb8426e71335c2eac203f0; //signature of the emitted event
    bytes32 topic1 = bytes32(0); // no filters for any of the topics
    bytes32 topic2 = bytes32(0); // no filters for any of the topics
    bytes32 topic3 = bytes32(0); // no filters for any of the topics

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error RegisterUpkeep__FailedToRegisterUpkeep();

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function registerUpkeep(
        address relayerAddress,
        address distributionAddress
    ) public {
        LogTriggerConfig memory logTriggerConfig = LogTriggerConfig({
            contractAddress: distributionAddress,
            filterSelector: filterSelector,
            topic0: topic0,
            topic1: topic1,
            topic2: topic2,
            topic3: topic3
        });

        RegistrationParams memory requestParams = RegistrationParams({
            name: "Relayer",
            encryptedEmail: "",
            upkeepContract: relayerAddress,
            gasLimit: 500000,
            adminAddress: ADMIN_ADDRESS,
            triggerType: 1, // 0 is Conditional upkeep, 1 is Log trigger upkeep
            checkData: "",
            triggerConfig: abi.encode(
                logTriggerConfig.contractAddress,
                filterSelector,
                topic0,
                topic1,
                topic2,
                topic3
            ),
            offchainConfig: "",
            amount: AMOUNT
        });

        vm.startBroadcast();

        linkToken.approve(address(automationRegistrar), requestParams.amount);
        uint256 upkeepID = automationRegistrar.registerUpkeep(requestParams);

        vm.stopBroadcast();
        if (upkeepID != 0) {
            console.log("Successfully registered upkeep with ID: ", upkeepID);
            console.log(
                "Please update the upkeepId in RelayerHelperConfig first!"
            );
        } else {
            console.log("Failed to register upkeep");
            revert RegisterUpkeep__FailedToRegisterUpkeep();
        }
    }

    function run() external {
        helperConfig = new RelayerHelperConfig();

        address registrarAddress = helperConfig
            .getActiveNetworkConfig()
            .registrarAddress;

        automationRegistrar = AutomationRegistrarInterface(registrarAddress);
        linkToken = LinkTokenInterface(
            helperConfig.getActiveNetworkConfig().linkTokenAddress
        );

        address relayerAddress = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        address distributionAddress = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );

        registerUpkeep(relayerAddress, distributionAddress);
    }
}
