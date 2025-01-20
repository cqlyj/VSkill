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
import {Distribution} from "src/Distribution.sol";
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
    Distribution distribution;

    RelayerHelperConfig relayerHelperConfig;

    address public USER = makeAddr("user");
    string public constant skillDomain = "Blockchain";
    string public constant CID = "cid";
    uint256 public constant SUBMISSION_FEE = 0.0025e18;

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
        distribution = Distribution(
            vSkillUser.getDistributionContractAddress()
        );

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
        initialize._initializeToForwarder(registry, upkeepId, relayer);

        vm.deal(USER, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               VSKILLUSER
    //////////////////////////////////////////////////////////////*/

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
        assert(distribution.getVSkillUser() == address(vSkillUser));
    }

    function testUserCanSubmitEvidence() external {
        vm.prank(USER);
        vSkillUser.submitEvidence{value: SUBMISSION_FEE}(CID, skillDomain);

        assertEq(
            vSkillUser.getBonus(),
            ((SUBMISSION_FEE * vSkillUser.getBonusWeight()) /
                vSkillUser.getTotalWeight())
        );
    }

    function testUserCanOnlySubmitEvidenceWithValidSkillDomain() external {
        vm.prank(USER);
        vm.expectRevert(VSkillUser.VSkillUser__InvalidSkillDomain.selector);
        vSkillUser.submitEvidence{value: SUBMISSION_FEE}(
            CID,
            "Invalid Skill Domain"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                VERIFIER
    //////////////////////////////////////////////////////////////*/
}
