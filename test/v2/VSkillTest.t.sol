// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployRelayer} from "script/deploy/DeployRelayer.s.sol";
import {DeployVerifier} from "script/deploy/DeployVerifier.s.sol";
import {DeployVSkillUser} from "script/deploy/DeployVSkillUser.s.sol";
import {DeployVSkillUserNft} from "script/deploy/DeployVSkillUserNft.s.sol";
import {Relayer} from "src/Relayer.sol";
import {Verifier} from "src/Verifier.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Initialize} from "script/interactions/Initialize.s.sol";
import {RelayerHelperConfig} from "script/helperConfig/RelayerHelperConfig.s.sol";

// We have already tested most of the functions in v1, here we will focus on testing the possible situations that can occur in the v2 version of the contract.
contract VSkillTest is Test {
    DeployRelayer deployRelayer;
    DeployVerifier deployVerifier;
    DeployVSkillUser deployVSkillUser;
    DeployVSkillUserNft deployVSkillUserNft;

    Relayer relayer;
    Verifier verifier;
    VSkillUser vSkillUser;
    VSkillUserNft vSkillUserNft;

    RelayerHelperConfig relayerHelperConfig;

    address public USER = makeAddr("user");

    function setUp() external {
        deployRelayer = new DeployRelayer();
        deployVerifier = new DeployVerifier();
        deployVSkillUser = new DeployVSkillUser();
        deployVSkillUserNft = new DeployVSkillUserNft();

        relayer = deployRelayer.run();
        (verifier, ) = deployVerifier.run();
        (vSkillUser, ) = deployVSkillUser.run();
        (vSkillUserNft, ) = deployVSkillUserNft.run();

        relayerHelperConfig = new RelayerHelperConfig();
        address registry = relayerHelperConfig
            .getActiveNetworkConfig()
            .registryAddress;
        uint256 upkeepId = relayerHelperConfig
            .getActiveNetworkConfig()
            .upkeepId;

        // Initialize those contracts
        Initialize initialize = new Initialize();
        initialize._initializeToRelayer(
            vSkillUser,
            vSkillUserNft,
            verifier,
            address(relayer)
        );
        initialize._initializeToForwarder(registry, upkeepId, relayer);
    }

    function testContractsHaveBeenInitializedProperly() external {
        vm.startPrank(vSkillUser.owner());
        vm.expectRevert(VSkillUser.VSkillUser__AlreadyInitialized.selector);
        vSkillUser.initializeRelayer(address(relayer));

        vm.expectRevert(
            VSkillUserNft.VSkillUserNft__AlreadyInitialized.selector
        );
        vSkillUserNft.initializeRelayer(address(relayer));

        vm.expectRevert(Verifier.Verifier__AlreadyInitialized.selector);
        verifier.initializeRelayer(address(relayer));

        vm.stopPrank();

        assert(relayer.getForwarder() != address(0));
    }
}
