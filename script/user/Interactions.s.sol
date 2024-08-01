// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {VSkill} from "src/user/VSkill.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract SubmitEvidenceVSkill is Script {
    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string public constant SKILL_DOMAIN = "Blockchain";

    function submitEvidenceVSkill(
        address mostRecentlyDeployed,
        uint256 submissionFeeInUsd
    ) public {
        vm.startBroadcast();
        VSkill vskill = VSkill(payable(mostRecentlyDeployed));
        vskill.submitEvidence{value: submissionFeeInUsd}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "VSkill",
            block.chainid
        );

        HelperConfig helperConfig = new HelperConfig();
        (uint256 submissionFeeInUsd, ) = helperConfig.activeNetworkConfig();

        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        console.log(
            "Submission fee in USD: ",
            submissionFeeInUsd / 1e18,
            " USD"
        );
        submitEvidenceVSkill(mostRecentlyDeployed, submissionFeeInUsd);
    }
}

contract ChangeSubmissionFeeVSkill is Script {
    uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD

    function changeSubmissionFeeVSkill(
        address mostRecentlyDeployed,
        uint256 newSubmissionFee
    ) public {
        vm.startBroadcast();
        VSkill vskill = VSkill(payable(mostRecentlyDeployed));
        vskill.changeSubmissionFee(newSubmissionFee);
        vm.stopBroadcast();
        uint256 currentSubmissionFee = vskill.getSubmissionFeeInUsd();
        console.log(
            "New submission fee in USD: ",
            currentSubmissionFee / 1e18,
            " USD"
        );
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "VSkill",
            block.chainid
        );

        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        changeSubmissionFeeVSkill(
            mostRecentlyDeployed,
            NEW_SUBMISSION_FEE_IN_USD
        );
    }
}

contract AddMoreSkillsVSkill is Script {
    string public constant NEW_SKILL_DOMAIN = "New skill domain";

    function addMoreSkillsVSkill(
        address mostRecentlyDeployed,
        string memory newSkillDomain
    ) public {
        vm.startBroadcast();
        VSkill vskill = VSkill(payable(mostRecentlyDeployed));
        vskill.addMoreSkills(newSkillDomain);
        vm.stopBroadcast();

        string[] memory skillDomains = vskill.getSkillDomains();
        uint256 length = skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            console.log("Skill domain: ", skillDomains[i]);
        }
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "VSkill",
            block.chainid
        );

        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        addMoreSkillsVSkill(mostRecentlyDeployed, NEW_SKILL_DOMAIN);
    }
}