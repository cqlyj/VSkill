// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployVSkillUser} from "../../../script/user/DeployVSkillUser.s.sol";
import {VSkillUser} from "../../../src/user/VSkillUser.sol";
import {HelperConfig} from "../../../script/user/HelperConfig.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {StructDefinition} from "../../../src/utils/library/StructDefinition.sol";
import {PriceConverter} from "../../../src/utils/library/PriceCoverter.sol";

contract VSkillUserTest is Test {
    using StructDefinition for StructDefinition.VSkillUserEvidence;
    using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;
    using PriceConverter for uint256;

    DeployVSkillUser deployer;
    VSkillUser vskill;
    HelperConfig helperConfig;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public submissionFeeInUsd; // 5e18 -> 5 USD
    uint256 public SUBMISSION_FEE_IN_ETH;
    AggregatorV3Interface priceFeed;
    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant NEW_SKILL_DOMAIN = "NewSkillDomain";
    uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD
    string public constant NEW_NFT_IMAGE_URI = "newnftimageuri";
    string public constant FEEDBACK = "Good Job!";

    event EvidenceSubmitted(
        address indexed submitter,
        string evidenceIpfsHash,
        string skillDomain
    );
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    function setUp() external {
        deployer = new DeployVSkillUser();
        (vskill, helperConfig) = deployer.run();
        (uint256 _submissionFeeInUsd, address _priceFeed) = helperConfig
            .activeNetworkConfig();
        submissionFeeInUsd = _submissionFeeInUsd;
        priceFeed = AggregatorV3Interface(_priceFeed);
        vm.deal(USER, INITIAL_BALANCE);

        SUBMISSION_FEE_IN_ETH = submissionFeeInUsd.convertUsdToEth(priceFeed);
    }

    ///////////////////////////
    ///     constructor     ///
    ///////////////////////////

    function testVSkillSubmissionFee() external view {
        assertEq(vskill.getSubmissionFeeInUsd(), submissionFeeInUsd);
    }

    //////////////////////////////
    ///     submitEvidence     ///
    //////////////////////////////

    function testVSkillSubmitEvidenceRevertIfNotEnoughSubmissionFee() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                VSkillUser.VSkillUser__NotEnoughSubmissionFee.selector,
                submissionFeeInUsd,
                0
            )
        );
        vskill.submitEvidence(IPFS_HASH, SKILL_DOMAIN);
    }

    function testVSkillSubmitEvidenceRevertIfInvalidSkillDomain() external {
        vm.expectRevert(VSkillUser.VSkillUser__InvalidSkillDomain.selector);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            "InvalidSkillDomain"
        );
    }

    function testVSkillSubmitEvidenceUpdatesBonusMoney() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        uint256 bonusMoney = vskill.getBonusMoneyInEth();
        assertEq(bonusMoney, SUBMISSION_FEE_IN_ETH);
    }

    function testVSkillSubmitEvidenceUpdatesAddressToEvidences() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        StructDefinition.VSkillUserEvidence[] memory evidences = vskill
            .getAddressToEvidences(USER);
        assertEq(evidences.length, 1);
        assertEq(evidences[0].evidenceIpfsHash, IPFS_HASH);
        assertEq(evidences[0].skillDomain, SKILL_DOMAIN);
        assertEq(
            uint256(evidences[0].status),
            uint256(vskill.getEvidenceStatus(USER, 0))
        );
    }

    function testVSkillSubmitEvidenceUpdatesEvidences() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        StructDefinition.VSkillUserEvidence[] memory evidences = vskill
            .getEvidences();
        assertEq(evidences.length, 1);
        assertEq(evidences[0].evidenceIpfsHash, IPFS_HASH);
        assertEq(evidences[0].skillDomain, SKILL_DOMAIN);
        assertEq(
            uint256(evidences[0].status),
            uint256(vskill.getEvidenceStatus(USER, 0))
        );
    }

    function testVSkillSubmitEvidenceEmitsEvidenceSubmitted() external {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(vskill));
        emit VSkillUser.EvidenceSubmitted(USER, IPFS_HASH, SKILL_DOMAIN);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
    }

    ///////////////////////////////////////
    ///     checkFeedbackOfEvidence     ///
    ///////////////////////////////////////

    function testCheckFeedbackOfEvidenceRevertIfIndexOutOfRange() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        vm.expectRevert(
            VSkillUser.VSkillUser__EvidenceIndexOutOfRange.selector
        );
        vskill.checkFeedbackOfEvidence(1);
    }

    // since only the selected verifier can provide feedback
    // here we can't test the function in the unit test

    // function testCheckFeedbackOfEvidenceReturnsCorrectFeedback() external {}

    ///////////////////////////
    ///     earnUserNft     ///
    ///////////////////////////

    function testEarnUserNftRevertIfEvidenceNotApproved() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );

        StructDefinition.VSkillUserEvidence memory evidence = vskill
            .getAddressToEvidences(USER)[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                VSkillUser.VSkillUser__EvidenceNotApprovedYet.selector,
                vskill.getEvidenceStatus(USER, 0)
            )
        );
        vskill.earnUserNft(evidence);
        vm.stopPrank();
    }

    // since only the selected verifier can approve the evidence
    // here we can't test the function in the unit test

    // function testEarnUserNftMintUserNftIfEvidenceApproved() external {}

    ///////////////////////////////////
    ///     changeSubmissionFee     ///
    ///////////////////////////////////

    function testChangeSubmissionFeeRevertsIfNotOwner() external {
        vm.prank(USER);
        vm.expectRevert();
        vskill.changeSubmissionFee(0);
    }

    function testChangeSubmissionFeeUpdatesSubmissionFeeInUsd() external {
        uint256 newFeeInUsd = NEW_SUBMISSION_FEE_IN_USD;
        address owner = vskill.owner();
        vm.prank(owner);
        vskill.changeSubmissionFee(newFeeInUsd);
        assertEq(vskill.getSubmissionFeeInUsd(), newFeeInUsd);
    }

    function testChangeSubmissionFeeEmitsSubmissionFeeChanged() external {
        uint256 newFeeInUsd = NEW_SUBMISSION_FEE_IN_USD;
        address owner = vskill.owner();
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(vskill));
        emit VSkillUser.SubmissionFeeChanged(newFeeInUsd);
        vskill.changeSubmissionFee(newFeeInUsd);
    }

    ///////////////////////////
    ///     addMoreSkills   ///
    ///////////////////////////

    function testAddMoreSkillsRevertsIfNotOwner() external {
        vm.prank(USER);
        vm.expectRevert();
        vskill.addMoreSkills(NEW_SKILL_DOMAIN, NEW_NFT_IMAGE_URI);
    }

    function testAddMoreSkillsRevertsIfSkillDomainAlreadyExists() external {
        address owner = vskill.owner();
        vm.prank(owner);
        vm.expectRevert(
            VSkillUser.VSkillUser__SkillDomainAlreadyExists.selector
        );
        vskill.addMoreSkills(SKILL_DOMAIN, NEW_NFT_IMAGE_URI);
    }

    function testAddMoreSkillsUpdatesSkillDomains() external {
        uint256 length = vskill.getSkillDomains().length;
        address owner = vskill.owner();
        vm.prank(owner);
        vskill.addMoreSkills(NEW_SKILL_DOMAIN, NEW_NFT_IMAGE_URI);
        string[] memory skillDomains = vskill.getSkillDomains();
        uint256 newLength = skillDomains.length;
        assertEq(length + 1, newLength);
        assertEq(skillDomains[newLength - 1], NEW_SKILL_DOMAIN);
    }

    function testAddMoreSkillsEmitsSkillDomainAdded() external {
        address owner = vskill.owner();
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(vskill));
        emit VSkillUser.SkillDomainAdded(NEW_SKILL_DOMAIN);
        vskill.addMoreSkills(NEW_SKILL_DOMAIN, NEW_NFT_IMAGE_URI);
    }
}
