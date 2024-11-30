// SPDX-License-Identifier: MIT

// @audit-info floating pragma
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../../src/utils/library/PriceCoverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Staking} from "../staking/Staking.sol";
import {VSkillUserNft} from "../nft/VSkillUserNft.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

/**
 * @title VSkillUser contract for user interaction
 * @author Luo Yingjie
 * @notice This is the contract for submitting evidence and earning NFTs with skill domains
 * @dev The user can submit evidence and earn NFTs with skill domains, also they can check the feedback of the evidence
 */
contract VSkillUser is Ownable, Staking, VSkillUserNft {
    // @audit-gas the submittedFeeInUsd is set by the user, no need to show it as a parameter
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

    /**
     * @dev PriceConverter library is used to convert the price from ETH to USD and vice versa.
     * @dev StructDefinition library is used to define the struct of VSkillUserEvidence and VSkillUserSubmissionStatus.
     */
    using PriceConverter for uint256;
    using StructDefinition for StructDefinition.VSkillUserEvidence;
    using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;

    // @audit-info why declare this again here? => Because private variables are not inherited
    // already declared in VSkillUserNft.sol
    string[] private s_skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];

    /**
     * @dev submissionFeeInUsd is the fee that users need to pay to submit their evidence. Here is 5 USD.
     */
    uint256 private s_submissionFeeInUsd;
    mapping(address => StructDefinition.VSkillUserEvidence[])
        public s_addressToEvidences;
    StructDefinition.VSkillUserEvidence[] public s_evidences;

    event EvidenceSubmitted(
        address indexed submitter,
        string evidenceIpfsHash,
        string skillDomain
    );
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    constructor(
        uint256 _submissionFeeInUsd,
        address _priceFeed,
        string[] memory _userNftImageUris
    ) Ownable(msg.sender) Staking(_priceFeed) VSkillUserNft(_userNftImageUris) {
        s_submissionFeeInUsd = _submissionFeeInUsd;
        s_priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     *
     * @param evidenceIpfsHash The IPFS hash of the evidence user wants to submit.
     * @param skillDomain The corresponding skill domain of the evidence.
     * @dev This function is used to submit the evidence of the user.
     * @dev The user needs to pay the submission fee to submit the evidence.
     * @dev The evidence will be stored in the mapping addressToEvidences and evidences.
     * @dev The status of the evidence will be set to SUBMITTED.
     * @dev The event EvidenceSubmitted will be emitted.
     * @dev The user can submit the evidence only if the skill domain is valid.
     * @dev The user can submit the evidence only if the submission fee is enough.
     * @dev The submissionFee will be stored in the `bonusMoneyInUsd`.
     */
    function submitEvidence(
        string memory evidenceIpfsHash,
        string memory skillDomain
    ) public payable virtual {
        if (msg.value.convertEthToUsd(s_priceFeed) < s_submissionFeeInUsd) {
            revert VSkillUser__NotEnoughSubmissionFee(
                s_submissionFeeInUsd,
                msg.value.convertEthToUsd(s_priceFeed)
            );
        }

        if (!_isSkillDomainValid(skillDomain)) {
            revert VSkillUser__InvalidSkillDomain();
        }

        // Even though contract VSkillUser inherits from contract Staking, both contracts share the same deployed address for contract VSkillUser.
        // When you deploy contract VSkillUser, you're not deploying contract Staking separately
        // Instead, all of contract Staking's functionality is incorporated into contract VSkillUser's code.
        // So whenever a function is executed, this always refers to the current instance, which is contract VSkillUser.

        // Contract Staking’s balance will not hold Ether unless you directly send Ether to contract Staking's address.
        // Contract VSkillUser will hold all the Ether if you interact with contract VSkillUser or if contract VSkillUser calls contract Staking’s payable function.
        // Both functions in contract Staking’s and VSkillUser will store Ether in contract VSkillUser's balance when you interact with contract VSkillUser.

        // When you deploy contract B, both contract A and contract B share the same address because contract B inherits from contract A.
        // Any Ether sent to either contract A's or contract B's payable function is stored in the same contract address (which is contract B’s address in this case).
        // The total balance of the contract is available at that address, no matter which function (from contract A or contract B) received the Ether.

        super._addBonusMoney(msg.value);

        // We need the mapping to store the evidence of the user, and the array to store all the evidence.
        s_addressToEvidences[msg.sender].push(
            StructDefinition.VSkillUserEvidence({
                submitter: msg.sender,
                evidenceIpfsHash: evidenceIpfsHash,
                skillDomain: skillDomain,
                status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                feedbackIpfsHash: new string[](0)
            })
        );

        s_evidences.push(
            StructDefinition.VSkillUserEvidence({
                submitter: msg.sender,
                evidenceIpfsHash: evidenceIpfsHash,
                skillDomain: skillDomain,
                status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                feedbackIpfsHash: new string[](0)
            })
        );

        emit EvidenceSubmitted(msg.sender, evidenceIpfsHash, skillDomain);
    }

    /**
     *
     * @param indexOfUserEvidence The index of the evidence that the user have submitted.
     * @return The feedback of the evidence.
     * @dev This function is used to check the feedback of the evidence.
     * @dev The user can check the feedback of the evidence only if the index of the evidence is valid.
     */
    function checkFeedbackOfEvidence(
        uint256 indexOfUserEvidence
    ) public view virtual returns (string[] memory) {
        // written @audit-low the indexOfUserEvidence should check with the length of the user's evidence array, s_addressToEvidences[msg.sender].length
        // user will revert due to the return statement if the index of user evidence is out of range, not the custom error
        if (indexOfUserEvidence >= s_evidences.length) {
            revert VSkillUser__EvidenceIndexOutOfRange();
        }

        return
            s_addressToEvidences[msg.sender][indexOfUserEvidence]
                .feedbackIpfsHash;
    }

    /**
     *
     * @param _evidence The evidence that the user wants to earn the NFT.
     * @dev This function is used to earn the NFT for the user.
     * @dev The user can earn the NFT only if the status of the evidence is APPROVED.
     */
    function earnUserNft(
        StructDefinition.VSkillUserEvidence memory _evidence
    ) public virtual {
        if (
            _evidence.status !=
            StructDefinition.VSkillUserSubmissionStatus.APPROVED
        ) {
            revert VSkillUser__EvidenceNotApprovedYet(_evidence.status);
        }

        // written @audit-high Anyone can provide an approved evidence and get the NFT.
        super.mintUserNft(_evidence.skillDomain);
    }

    ///////////////////////////////
    //////  Owner Functions  //////
    ///////////////////////////////

    /**
     *
     * @param newFeeInUsd The new submission fee that the owner wants to set.
     * @dev This function is used to change the submission fee.
     * @dev Only the owner can change the submission fee.
     * @dev The event SubmissionFeeChanged will be emitted.
     */

    // @audit-info centralization of the submission fee, is it a good idea?
    function changeSubmissionFee(uint256 newFeeInUsd) public virtual onlyOwner {
        s_submissionFeeInUsd = newFeeInUsd;
        emit SubmissionFeeChanged(newFeeInUsd);
    }

    /**
     *
     * @param skillDomain The new skill domain that the owner wants to add.
     * @param newNftImageUri The new NFT image URI that the owner wants to add.
     * @dev This function is used to add more skill domains.
     * @dev Only the owner can add more skill domains.
     * @dev The event SkillDomainAdded will be emitted.
     */
    function addMoreSkills(
        string memory skillDomain,
        string memory newNftImageUri
    ) public virtual onlyOwner {
        if (_skillDomainAlreadyExists(skillDomain)) {
            revert VSkillUser__SkillDomainAlreadyExists();
        }

        // what if the newNftImageUri is blank? Is there any way to fix this?
        // this is the owner's responsibility to provide the correct image URI, so no need to check
        s_skillDomains.push(skillDomain);
        super._addMoreSkillsForNft(skillDomain, newNftImageUri);
        emit SkillDomainAdded(skillDomain);
    }

    ///////////////////////////////
    /////  Internal Functions  ////
    ///////////////////////////////

    /**
     *
     * @param skillDomain The skill domain to be checked.
     * @return True if the skill domain is valid, otherwise false.
     * @dev This function is used to check if the skill domain is valid.
     */
    function _isSkillDomainValid(
        string memory skillDomain
    ) internal view returns (bool) {
        // the skill domains length will within some range, so no DoS attack
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

    /**
     *
     * @param skillDomain The skill domain to be checked.
     * @return True if the skill domain already exists, otherwise false.
     * @dev This function is used to check if the skill domain already exists.
     * @dev This function is used in the addMoreSkills function.
     */
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

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

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
