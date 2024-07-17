// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployVSkill} from "../../../script/user/DeployVSkill.s.sol";
import {VSkill} from "../../../src/user/VSkill.sol";
import {HelperConfig} from "../../../script/user/HelperConfig.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VSkillTest is Test {
    DeployVSkill deployer;
    VSkill vskill;
    HelperConfig helperConfig;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public submissionFeeInUsd; // 5e18 -> 5 USD
    uint256 public constant SUBMISSION_FEE_IN_ETH = 0.0025 ether; // 0.0025 * 2000 = 5 USD
    AggregatorV3Interface priceFeed;
    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant NEW_SKILL_DOMAIN = "NewSkillDomain";
    uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD

    // enum SubmissionStatus {
    //     Submmited,
    //     InReview,
    //     Approved,
    //     Rejected
    // }

    event EvidenceSubmitted(
        address indexed submitter,
        string evidenceIpfsHash,
        string skillDomain
    );
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    function setUp() external {
        deployer = new DeployVSkill();
        (vskill, helperConfig) = deployer.run();
        (uint256 _submissionFeeInUsd, address _priceFeed) = helperConfig
            .activeNetworkConfig();
        submissionFeeInUsd = _submissionFeeInUsd;
        priceFeed = AggregatorV3Interface(_priceFeed);
        vm.deal(USER, INITIAL_BALANCE);
    }

    function testVSkillSubmissionFee() external view {
        assertEq(vskill.getSubmissionFeeInUsd(), submissionFeeInUsd);
    }

    // submitEvidence

    function testVSkillSubmitEvidenceRevertIfNotEnoughSubmissionFee() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                VSkill.VSkill__NotEnoughSubmissionFee.selector,
                submissionFeeInUsd,
                0
            )
        );
        vskill.submitEvidence(IPFS_HASH, SKILL_DOMAIN);
    }

    function testVSkillSubmitEvidenceRevertIfInvalidSkillDomain() external {
        vm.expectRevert(VSkill.VSkill__InvalidSkillDomain.selector);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            "InvalidSkillDomain"
        );
    }

    function testVSkillSubmitEvidenceUpdatesAddressToEvidences() external {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        VSkill.evidence[] memory evidences = vskill.getAddressToEvidences(USER);
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
        emit VSkill.EvidenceSubmitted(USER, IPFS_HASH, SKILL_DOMAIN);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
    }

    // changeSubmissionFee

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
        emit VSkill.SubmissionFeeChanged(newFeeInUsd);
        vskill.changeSubmissionFee(newFeeInUsd);
    }

    // addMoreSkills

    function testAddMoreSkillsRevertsIfNotOwner() external {
        vm.prank(USER);
        vm.expectRevert();
        vskill.addMoreSkills(NEW_SKILL_DOMAIN);
    }

    function testAddMoreSkillsRevertsIfSkillDomainAlreadyExists() external {
        address owner = vskill.owner();
        vm.prank(owner);
        vm.expectRevert(VSkill.VSkill__SkillDomainAlreadyExists.selector);
        vskill.addMoreSkills(SKILL_DOMAIN);
    }

    function testAddMoreSkillsUpdatesSkillDomains() external {
        uint256 length = vskill.getSkillDomains().length;
        address owner = vskill.owner();
        vm.prank(owner);
        vskill.addMoreSkills(NEW_SKILL_DOMAIN);
        string[] memory skillDomains = vskill.getSkillDomains();
        uint256 newLength = skillDomains.length;
        assertEq(length + 1, newLength);
        assertEq(skillDomains[newLength - 1], NEW_SKILL_DOMAIN);
    }

    function testAddMoreSkillsEmitsSkillDomainAdded() external {
        address owner = vskill.owner();
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(vskill));
        emit VSkill.SkillDomainAdded(NEW_SKILL_DOMAIN);
        vskill.addMoreSkills(NEW_SKILL_DOMAIN);
    }
}
