// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployVSkillUser} from "script/user/DeployVSkillUser.s.sol";
import {SubmitEvidenceVSkill, ChangeSubmissionFeeVSkill, AddMoreSkillsVSkill} from "script/user/Interactions.s.sol";
import {VSkillUser} from "src/user/VSkillUser.sol";
import {HelperConfig} from "script/user/HelperConfig.s.sol";

contract InteractionsTest is Test {
    VSkillUser vskill;
    HelperConfig helperConfig;
    uint256 submissionFeeInUsd;
    string public constant NEW_SKILL_DOMAIN = "New skill domain";
    string public constant NEW_NFT_IMAGE_URI = "newnftimageuri";
    uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD

    function setUp() external {
        DeployVSkillUser deployer = new DeployVSkillUser();
        (vskill, helperConfig) = deployer.run();
        (submissionFeeInUsd, ) = helperConfig.activeNetworkConfig();
    }

    function testInteractions() external {
        SubmitEvidenceVSkill submitEvidence = new SubmitEvidenceVSkill();
        submitEvidence.submitEvidenceVSkill(
            address(vskill),
            submissionFeeInUsd
        );

        ChangeSubmissionFeeVSkill changeSubmissionFee = new ChangeSubmissionFeeVSkill();
        changeSubmissionFee.changeSubmissionFeeVSkill(
            address(vskill),
            NEW_SUBMISSION_FEE_IN_USD
        );

        AddMoreSkillsVSkill addMoreSkills = new AddMoreSkillsVSkill();
        addMoreSkills.addMoreSkillsVSkill(
            address(vskill),
            NEW_SKILL_DOMAIN,
            NEW_NFT_IMAGE_URI
        );

        assertEq(vskill.getSubmissionFeeInUsd(), NEW_SUBMISSION_FEE_IN_USD);
        console.log("Submission fee changed successfully");

        assertEq(vskill.getSkillDomains().length, 6);
        console.log("New skills added successfully");
    }
}
