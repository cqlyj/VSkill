// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {VerifierHelperConfig} from "script/helperConfig/VerifierHelperConfig.s.sol";
import {DeployRelayer} from "script/deploy/DeployRelayer.s.sol";
import {DeployVSkillUser} from "script/deploy/DeployVSkillUser.s.sol";
import {DeployVSkillUserNft} from "script/deploy/DeployVSkillUserNft.s.sol";
import {Relayer} from "src/Relayer.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Distribution} from "src/Distribution.sol";
import {Initialize} from "script/interactions/Initialize.s.sol";
import {RelayerHelperConfig} from "script/helperConfig/RelayerHelperConfig.s.sol";
import {IRelayer} from "src/interfaces/IRelayer.sol";
import {MockVerifier} from "test/mock/MockVerifier.sol";
import {HandlerWithMockVerifier} from "test/v2/auditTests/fuzz/HandlerWithMockVerifier.t.sol";

// Property:
// 1. withdrawStakeAndLoseVerifier should not fail unless conditions explicitly prevent them.
contract InvariantWithMockVerifier is StdInvariant, Test {
    DeployRelayer deployRelayer;
    DeployVSkillUser deployVSkillUser;
    DeployVSkillUserNft deployVSkillUserNft;

    IRelayer relayer;
    MockVerifier verifier;
    VSkillUser vSkillUser;
    VSkillUserNft vSkillUserNft;
    Distribution distribution;

    RelayerHelperConfig relayerHelperConfig;
    VerifierHelperConfig verifierHelperConfig;

    HandlerWithMockVerifier handler;

    address public USER = makeAddr("user");
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant CID = "cid";
    uint256 public constant SUBMISSION_FEE = 0.0025e18;
    address public forwarder;

    function setUp() external {
        deployRelayer = new DeployRelayer();
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

        vm.prank(vSkillUser.owner());
        verifier = new MockVerifier(
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
        address relayerAddress = deployRelayer.deployRelayer(
            address(vSkillUser),
            address(distribution),
            address(verifier),
            address(vSkillUserNft)
        );
        relayer = IRelayer(address(Relayer(relayerAddress)));

        // Initialize those contracts
        Initialize initialize = new Initialize();
        initialize._initializeToVSkillUser(
            address(distribution),
            address(vSkillUser)
        );

        vm.startPrank(relayer.owner());
        vSkillUser.initializeRelayer(relayerAddress);
        vSkillUserNft.initializeRelayer(relayerAddress);
        verifier.initializeRelayer(relayerAddress);
        vm.stopPrank();

        forwarder = initialize._initializeToForwarder(
            registry,
            upkeepId,
            address(relayer)
        );

        vm.deal(USER, 1000 ether);

        handler = new HandlerWithMockVerifier(
            relayer,
            verifier,
            vSkillUser,
            distribution,
            USER,
            forwarder
        );

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.withdraw.selector;
        selectors[1] = handler.userSubmittedEvidenceUnhandled.selector;
        selectors[2] = handler.userSubmittedEvidenceHandled.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
        targetContract(address(handler));
    }

    function statefulFuzz_testVerifierShouldWithdrawSuccessfullyWithMockVerifier()
        external
    {
        // We don't need to do anything here
        // As long as those operation in the handler contract doesn't fail
        // The invariant should pass
        // And they indeed pass!
    }
}
