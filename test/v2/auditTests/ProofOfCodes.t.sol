// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MaliciousMockV3Aggregator} from "test/mock/MaliciousMockV3Aggregator.sol";
import {PriceConverter} from "src/library/PriceCoverter.sol";
import {CorrectPriceConverter, OracleLib} from "test/mock/CorrectPriceConverter.sol";
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
import {VerifierHelperConfig} from "script/helperConfig/VerifierHelperConfig.s.sol";
import {IRelayer} from "src/interfaces/IRelayer.sol";

contract ProofOfCodes is Test {
    using PriceConverter for uint256;
    using CorrectPriceConverter for uint256;

    MaliciousMockV3Aggregator public maliciousMockAggregator;

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

    address public forwarder;
    address public USER = makeAddr("user");

    function setUp() external {
        maliciousMockAggregator = new MaliciousMockV3Aggregator(8, 2000e8);

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
    }

    function testUnstablePriceFeedRevert() external {
        uint256 ethAmount = 1 ether;
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        ethAmount.correctConvertEthToUsd(maliciousMockAggregator);
        // However, the current price feed will not revert
        uint256 outdatedData = ethAmount.convertEthToUsd(
            maliciousMockAggregator
        );
        console.log("This is the outdated data: ", outdatedData);
    }

    function testVerifierLocksEth() external {
        address ethLocker = makeAddr("ethLocker");
        deal(ethLocker, 10 ether);
        vm.prank(ethLocker);
        (bool success, ) = address(verifier).call{value: 1 ether}("");
        assertEq(success, true);

        // This will fail because it will trigger the `stake()` function
        // which will revert if the user has not provided the correct amount of eth
        // Even if someone send the correct amount of eth, he will be a verifier and can withdraw the eth back
        vm.prank(ethLocker);
        (bool fallbackSuccess, ) = address(verifier).call{value: 1 ether}(
            "Give my Eth back!"
        );
        assertEq(fallbackSuccess, false);
    }

    function testUserCanSendMoreThanRequiredForSubmission() external {
        vm.prank(USER);
        vSkillUser.submitEvidence{
            value: vSkillUser.getSubmissionFeeInEth() + 1e18
        }("cid", "Blockchain"); // We know that Blockchain is a valid skill domain from the config

        uint256 evidenceLength = vSkillUser.getEvidences().length;
        assertEq(evidenceLength, 1);
    }

    function testVerifierDeletionIsNotComplete() external {
        address verifierAddress = makeAddr("verifier");
        deal(verifierAddress, 1 ether);

        vm.startPrank(verifierAddress);
        verifier.stake{value: verifier.getStakeEthAmount()}();
        verifier.addSkillDomain("Blockchain");

        uint256 verifierWithinSameDomainLength = verifier
            .getSkillDomainToVerifiersWithinSameDomainLength("Blockchain");

        verifier.withdrawStakeAndLoseVerifier();
        uint256 verifierWithinSameDomainLengthAfterDeletion = verifier
            .getSkillDomainToVerifiersWithinSameDomainLength("Blockchain");

        vm.stopPrank();

        console.log(
            "Verifier within same domain length before deletion: ",
            verifierWithinSameDomainLength
        );
        console.log(
            "Verifier within same domain length after deletion: ",
            verifierWithinSameDomainLengthAfterDeletion
        );
        console.log("You can find that the deletion is not complete!");
        console.log(
            "Thus, even if the verifier is deleted, he can still be selected!!!"
        );
    }
}
