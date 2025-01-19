// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Script, console} from "forge-std/Script.sol";
// import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
// import {VSkillUser} from "src/user/VSkillUser.sol";
// import {HelperConfig} from "./HelperConfig.s.sol";
// import {StructDefinition} from "src/utils/library/StructDefinition.sol";

// contract SubmitEvidenceVSkillUser is Script {
//     string public constant IPFS_HASH =
//         "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
//     string public constant SKILL_DOMAIN = "Blockchain";

//     function submitEvidenceVSkillUser(
//         address mostRecentlyDeployed,
//         uint256 submissionFeeInUsd
//     ) public {
//         vm.startBroadcast();
//         VSkillUser vskill = VSkillUser(payable(mostRecentlyDeployed));
//         vskill.submitEvidence{value: submissionFeeInUsd}(
//             IPFS_HASH,
//             SKILL_DOMAIN
//         );
//         vm.stopBroadcast();
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUser",
//             block.chainid
//         );

//         HelperConfig helperConfig = new HelperConfig();
//         (uint256 submissionFeeInUsd, ) = helperConfig.activeNetworkConfig();

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);
//         console.log(
//             "Submission fee in USD: ",
//             submissionFeeInUsd / 1e18,
//             " USD"
//         );
//         submitEvidenceVSkillUser(mostRecentlyDeployed, submissionFeeInUsd);
//     }
// }

// contract ChangeSubmissionFeeVSkillUser is Script {
//     uint256 public constant NEW_SUBMISSION_FEE_IN_USD = 10e18; // 10 USD

//     function changeSubmissionFeeVSkillUser(
//         address mostRecentlyDeployed,
//         uint256 newSubmissionFee
//     ) public {
//         vm.startBroadcast();
//         VSkillUser vskill = VSkillUser(payable(mostRecentlyDeployed));
//         vskill.changeSubmissionFee(newSubmissionFee);
//         vm.stopBroadcast();
//         uint256 currentSubmissionFee = vskill.getSubmissionFeeInUsd();
//         console.log(
//             "New submission fee in USD: ",
//             currentSubmissionFee / 1e18,
//             " USD"
//         );
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUser",
//             block.chainid
//         );

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);

//         changeSubmissionFeeVSkillUser(
//             mostRecentlyDeployed,
//             NEW_SUBMISSION_FEE_IN_USD
//         );
//     }
// }

// contract AddMoreSkillsVSkillUser is Script {
//     string public constant NEW_SKILL_DOMAIN = "New skill domain";
//     string public constant NEW_NFT_IMAGE_URI = "newnftimageuri";

//     function addMoreSkillsVSkillUser(
//         address mostRecentlyDeployed,
//         string memory newSkillDomain,
//         string memory newNftImageUri
//     ) public {
//         vm.startBroadcast();
//         VSkillUser vskill = VSkillUser(payable(mostRecentlyDeployed));
//         vskill.addMoreSkills(newSkillDomain, newNftImageUri);
//         vm.stopBroadcast();

//         string[] memory skillDomains = vskill.getSkillDomains();
//         uint256 length = skillDomains.length;
//         for (uint256 i = 0; i < length; i++) {
//             console.log("Skill domain: ", skillDomains[i]);
//         }
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUser",
//             block.chainid
//         );

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);

//         addMoreSkillsVSkillUser(
//             mostRecentlyDeployed,
//             NEW_SKILL_DOMAIN,
//             NEW_NFT_IMAGE_URI
//         );
//     }
// }

// contract CheckFeedbackOfEvidenceVSkillUser is Script {
//     function checkFeedbackOfEvidenceVSkillUser(
//         address mostRecentlyDeployed,
//         uint256 indexOfUserEvidence
//     ) public {
//         vm.startBroadcast();
//         VSkillUser vskill = VSkillUser(payable(mostRecentlyDeployed));
//         vskill.checkFeedbackOfEvidence(indexOfUserEvidence);
//         vm.stopBroadcast();

//         StructDefinition.VSkillUserEvidence[] memory evidence = vskill
//             .getEvidences();

//         string[] memory feedback = evidence[indexOfUserEvidence]
//             .feedbackIpfsHash;
//         if (feedback.length == 0) {
//             console.log("No feedback provided yet");
//         } else {
//             uint256 length = feedback.length;
//             for (uint256 i = 0; i < length; i++) {
//                 console.log("Feedback IPFS hash: ", feedback[i]);
//             }
//         }
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUser",
//             block.chainid
//         );

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);

//         checkFeedbackOfEvidenceVSkillUser(mostRecentlyDeployed, 0);
//     }
// }

// contract EarnUserNft is Script {
//     using StructDefinition for StructDefinition.VSkillUserEvidence;

//     StructDefinition.VSkillUserEvidence public evidence;
//     string public constant IPFS_HASH =
//         "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
//     string public constant SKILL_DOMAIN = "Blockchain";

//     function earnUserNft(
//         address mostRecentlyDeployed,
//         StructDefinition.VSkillUserEvidence memory ev
//     ) public {
//         vm.startBroadcast();
//         VSkillUser vskill = VSkillUser(payable(mostRecentlyDeployed));
//         vskill.earnUserNft(ev);
//         vm.stopBroadcast();

//         console.log("User NFT minted successfully");
//         uint256 tokenCounter = vskill.getTokenCounter();

//         console.log("Token ID: ", tokenCounter - 1);
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUser",
//             block.chainid
//         );

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);

//         // In case to see the minted NFT, here we just provide the evidence which is already approved
//         // ISSUE: Is that mean anyone can mint NFT by providing the approved evidence?
//         StructDefinition.VSkillUserEvidence memory ev = StructDefinition
//             .VSkillUserEvidence(
//                 msg.sender,
//                 IPFS_HASH,
//                 SKILL_DOMAIN,
//                 StructDefinition.VSkillUserSubmissionStatus.APPROVED,
//                 new string[](0)
//             );

//         earnUserNft(mostRecentlyDeployed, ev);
//     }
// }
