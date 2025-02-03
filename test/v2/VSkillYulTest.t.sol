// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Base_VSkillTest, IRelayer, Initialize, DeployVerifier, DeployVSkillUser, DeployVSkillUserNft, VerifierHelperConfig, RelayerHelperConfig, Distribution} from "test/v2/Base_VSkillTest.t.sol";
import {RelayerYul} from "src/optimizedGas/RelayerYul.sol";
import {DeployRelayerYul} from "script/deploy/DeployRelayerYul.s.sol";

contract VSkillYulTest is Base_VSkillTest {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    DeployRelayerYul deployRelayerYul;

    /*//////////////////////////////////////////////////////////////
                                 SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() external override {
        deployRelayerYul = new DeployRelayerYul();

        deployVerifier = new DeployVerifier();
        deployVSkillUser = new DeployVSkillUser();
        deployVSkillUserNft = new DeployVSkillUserNft();

        (vSkillUser, ) = deployVSkillUser.run();
        (vSkillUserNft, ) = deployVSkillUserNft.run();

        verifierHelperConfig = new VerifierHelperConfig();
        address priceFeed = verifierHelperConfig
            .getActiveNetworkConfig()
            .priceFeed;
        string[] memory skillDomains = verifierHelperConfig
            .getActiveNetworkConfig()
            .skillDomains;
        verifier = deployVerifier.deployVerifier(
            priceFeed,
            skillDomains,
            address(vSkillUser)
        );

        relayerHelperConfig = new RelayerHelperConfig();
        address registry = relayerHelperConfig
            .getActiveNetworkConfig()
            .registryAddress;
        uint256 upkeepId = relayerHelperConfig
            .getActiveNetworkConfig()
            .upkeepId;
        distribution = Distribution(
            vSkillUser.getDistributionContractAddress()
        );
        address relayerYulAddress = deployRelayerYul.deployRelayerYul(
            address(vSkillUser),
            address(distribution),
            address(verifier),
            address(vSkillUserNft)
        );
        relayer = IRelayer(address(RelayerYul(relayerYulAddress)));

        // Initialize those contracts
        Initialize initialize = new Initialize();
        initialize._initializeToVSkillUser(
            address(distribution),
            address(vSkillUser)
        );
        initialize._initializeToRelayer(
            vSkillUser,
            vSkillUserNft,
            verifier,
            address(relayer)
        );
        forwarder = initialize._initializeToForwarder(
            registry,
            upkeepId,
            address(relayer)
        );

        vm.deal(USER, 1000 ether);
    }
}
