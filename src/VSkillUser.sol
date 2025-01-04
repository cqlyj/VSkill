// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "src/library/PriceCoverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";

contract VSkillUser is Ownable {
    using PriceConverter for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error VSkillUser__NotEnoughSubmissionFee(
        uint256 requiredFeeInUsd,
        uint256 submittedFeeInUsd
    );
    error VSkillUser__InvalidSkillDomain();
    error VSkillUser__SkillDomainAlreadyExists();
    error VSkillUser__EvidenceNotApprovedYet(
        StructDefinition.VSkillUserSubmissionStatus status
    );
    error VSkillUser__EvidenceIndexOutOfRange();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // @why declare this again here? => Because private variables are not inherited
    // already declared in VSkillUserNft.sol
    string[] private s_skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];

    uint256 private s_submissionFeeInUsd;
    mapping(address => StructDefinition.VSkillUserEvidence[])
        public s_addressToEvidences;
    StructDefinition.VSkillUserEvidence[] public s_evidences;
    AggregatorV3Interface private i_priceFeed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event EvidenceSubmitted(
        address indexed submitter,
        string evidenceIpfsHash,
        string skillDomain
    );
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _submissionFeeInUsd,
        address _priceFeed
    ) Ownable(msg.sender) {
        s_submissionFeeInUsd = _submissionFeeInUsd;
        i_priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function submitEvidence() public {}

    function checkFeedback() public {}

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @written audit-info centralization of the submission fee, is it a good idea?
    function changeSubmissionFee(uint256 newFeeInUsd) public virtual onlyOwner {
        s_submissionFeeInUsd = newFeeInUsd;
        emit SubmissionFeeChanged(newFeeInUsd);
    }

    function addMoreSkills(
        string memory skillDomain,
        string memory newNftImageUri
    ) public virtual onlyOwner {
        // if (_skillDomainAlreadyExists(skillDomain)) {
        //     revert VSkillUser__SkillDomainAlreadyExists();
        // }
        // // what if the newNftImageUri is blank? Is there any way to fix this?
        // // this is the owner's responsibility to provide the correct image URI, so no need to check
        // s_skillDomains.push(skillDomain);
        // super._addMoreSkillsForNft(skillDomain, newNftImageUri);
        // emit SkillDomainAdded(skillDomain);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isSkillDomainValid(
        string memory skillDomain
    ) internal view returns (bool) {
        uint256 length = s_skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(s_skillDomains[i])) ==
                keccak256(abi.encodePacked(skillDomain))
            ) {
                return true;
            }
        }
        return false;
    }

    function _skillDomainAlreadyExists(
        string memory skillDomain
    ) internal view returns (bool) {
        uint256 length = s_skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(s_skillDomains[i])) ==
                keccak256(abi.encodePacked(skillDomain))
            ) {
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getSubmissionFeeInUsd() external view returns (uint256) {
        return s_submissionFeeInUsd;
    }

    function getAddressToEvidences(
        address _address
    ) external view returns (StructDefinition.VSkillUserEvidence[] memory) {
        return s_addressToEvidences[_address];
    }

    function getEvidenceStatus(
        address _address,
        uint256 index
    ) external view returns (StructDefinition.VSkillUserSubmissionStatus) {
        return s_addressToEvidences[_address][index].status;
    }

    function getEvidences()
        external
        view
        returns (StructDefinition.VSkillUserEvidence[] memory)
    {
        return s_evidences;
    }

    function getEvidenceFeedbackIpfsHash(
        address _address,
        uint256 index
    ) external view returns (string[] memory) {
        return s_addressToEvidences[_address][index].feedbackIpfsHash;
    }
}

// function submitEvidence(
//     string memory evidenceIpfsHash,
//     string memory skillDomain
// ) public payable virtual {
//     if (msg.value.convertEthToUsd(i_priceFeed) < s_submissionFeeInUsd) {
//         revert VSkillUser__NotEnoughSubmissionFee(
//             s_submissionFeeInUsd,
//             msg.value.convertEthToUsd(i_priceFeed)
//         );
//     }

//     if (!_isSkillDomainValid(skillDomain)) {
//         revert VSkillUser__InvalidSkillDomain();
//     }

//     // Even though contract VSkillUser inherits from contract Staking, both contracts share the same deployed address for contract VSkillUser.
//     // When you deploy contract VSkillUser, you're not deploying contract Staking separately
//     // Instead, all of contract Staking's functionality is incorporated into contract VSkillUser's code.
//     // So whenever a function is executed, this always refers to the current instance, which is contract VSkillUser.

//     // Contract Staking’s balance will not hold Ether unless you directly send Ether to contract Staking's address.
//     // Contract VSkillUser will hold all the Ether if you interact with contract VSkillUser or if contract VSkillUser calls contract Staking’s payable function.
//     // Both functions in contract Staking’s and VSkillUser will store Ether in contract VSkillUser's balance when you interact with contract VSkillUser.

//     // When you deploy contract B, both contract A and contract B share the same address because contract B inherits from contract A.
//     // Any Ether sent to either contract A's or contract B's payable function is stored in the same contract address (which is contract B’s address in this case).
//     // The total balance of the contract is available at that address, no matter which function (from contract A or contract B) received the Ether.

//     super._addBonusMoney(msg.value);

//     // We need the mapping to store the evidence of the user, and the array to store all the evidence.
//     s_addressToEvidences[msg.sender].push(
//         StructDefinition.VSkillUserEvidence({
//             submitter: msg.sender,
//             evidenceIpfsHash: evidenceIpfsHash,
//             skillDomain: skillDomain,
//             status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
//             feedbackIpfsHash: new string[](0)
//         })
//     );

//     s_evidences.push(
//         StructDefinition.VSkillUserEvidence({
//             submitter: msg.sender,
//             evidenceIpfsHash: evidenceIpfsHash,
//             skillDomain: skillDomain,
//             status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
//             feedbackIpfsHash: new string[](0)
//         })
//     );

//     emit EvidenceSubmitted(msg.sender, evidenceIpfsHash, skillDomain);
// }

// function checkFeedbackOfEvidence(
//     uint256 indexOfUserEvidence
// ) public view virtual returns (string[] memory) {
//     // written @audit-low the indexOfUserEvidence should check with the length of the user's evidence array, s_addressToEvidences[msg.sender].length
//     // user will revert due to the return statement if the index of user evidence is out of range, not the custom error
//     if (indexOfUserEvidence >= s_evidences.length) {
//         revert VSkillUser__EvidenceIndexOutOfRange();
//     }

//     return
//         s_addressToEvidences[msg.sender][indexOfUserEvidence]
//             .feedbackIpfsHash;
// }

// The Nft will be minted by the `Relayer` contract
// function earnUserNft(
//     StructDefinition.VSkillUserEvidence memory _evidence
// ) public virtual {
//     if (
//         _evidence.status !=
//         StructDefinition.VSkillUserSubmissionStatus.APPROVED
//     ) {
//         revert VSkillUser__EvidenceNotApprovedYet(_evidence.status);
//     }

//     // written @audit-high Anyone can provide an approved evidence and get the NFT.
//     super.mintUserNft(_evidence.skillDomain);
// }
