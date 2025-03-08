// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {VerifierHelperConfig} from "script/helperConfig/VerifierHelperConfig.s.sol";
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
import {IRelayer} from "src/interfaces/IRelayer.sol";
import {Handler} from "test/v2/auditTests/fuzz/Handler.t.sol";

// Property:
// 1. withdrawStakeAndLoseVerifier should not fail unless conditions explicitly prevent them.
contract Invariant is StdInvariant, Test {
    DeployRelayer deployRelayer;
    DeployVerifier deployVerifier;
    DeployVSkillUser deployVSkillUser;
    DeployVSkillUserNft deployVSkillUserNft;

    IRelayer relayer;
    Verifier verifier;
    VSkillUser vSkillUser;
    VSkillUserNft vSkillUserNft;
    Distribution distribution;

    RelayerHelperConfig relayerHelperConfig;
    VerifierHelperConfig verifierHelperConfig;

    Handler handler;

    address public USER = makeAddr("user");
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant CID = "cid";
    uint256 public constant SUBMISSION_FEE = 0.0025e18;
    address public forwarder;

    function setUp() external {
        deployRelayer = new DeployRelayer();
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

        handler = new Handler(
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

    // function statefulFuzz_testVerifierShouldWithdrawSuccessfully() external {
    //     // We have found one issue => the verifier deletion process is not complete!
    //     // Thus, we use a mock version of verifier contract which handles the deletion process correctly to test the invariant.
    //     // Check that in the InvariantWithMockVerifier contract.
    // }
}
