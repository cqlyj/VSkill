// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployVSkillUser} from "script/user/DeployVSkillUser.s.sol";
import {SubmitEvidenceVSkillUser, ChangeSubmissionFeeVSkillUser, AddMoreSkillsVSkillUser, CheckFeedbackOfEvidenceVSkillUser, EarnUserNft} from "script/user/Interactions.s.sol";
import {VSkillUser} from "src/user/VSkillUser.sol";
import {HelperConfig} from "script/user/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {StructDefinition} from "src/utils/library/StructDefinition.sol";

contract InteractionsTest is Test {
    using StructDefinition for StructDefinition.VSkillUserEvidence;

    VSkillUser vskill;
    HelperConfig helperConfig;
    uint256 submissionFeeInUsd;
    string public constant NEW_SKILL_DOMAIN = "New skill domain";
    string public constant NEW_NFT_IMAGE_URI = "newnftimageuri";
    uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD
    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string public constant SKILL_DOMAIN = "Blockchain";

    function setUp() external {
        DeployVSkillUser deployer = new DeployVSkillUser();
        (vskill, helperConfig) = deployer.run();
        (submissionFeeInUsd, ) = helperConfig.activeNetworkConfig();
    }

    function testVSkillUserInteractions() external {
        SubmitEvidenceVSkillUser submitEvidence = new SubmitEvidenceVSkillUser();
        vm.recordLogs();
        submitEvidence.submitEvidenceVSkillUser(
            address(vskill),
            submissionFeeInUsd
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2);
        console.log("Evidence submitted successfully");

        ChangeSubmissionFeeVSkillUser changeSubmissionFee = new ChangeSubmissionFeeVSkillUser();
        changeSubmissionFee.changeSubmissionFeeVSkillUser(
            address(vskill),
            NEW_SUBMISSION_FEE_IN_USD
        );

        AddMoreSkillsVSkillUser addMoreSkills = new AddMoreSkillsVSkillUser();
        addMoreSkills.addMoreSkillsVSkillUser(
            address(vskill),
            NEW_SKILL_DOMAIN,
            NEW_NFT_IMAGE_URI
        );

        assertEq(vskill.getSubmissionFeeInUsd(), NEW_SUBMISSION_FEE_IN_USD);
        console.log("Submission fee changed successfully");

        assertEq(vskill.getSkillDomains().length, 6);
        console.log("New skills added successfully");

        CheckFeedbackOfEvidenceVSkillUser checkFeedback = new CheckFeedbackOfEvidenceVSkillUser();
        checkFeedback.checkFeedbackOfEvidenceVSkillUser(address(vskill), 0);

        EarnUserNft earnNft = new EarnUserNft();
        StructDefinition.VSkillUserEvidence
            memory goodEvidence = StructDefinition.VSkillUserEvidence(
                msg.sender,
                IPFS_HASH,
                SKILL_DOMAIN,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED,
                new string[](0)
            );
        earnNft.earnUserNft(address(vskill), goodEvidence);

        assertEq(vskill.balanceOf(msg.sender), 1);
    }
}
