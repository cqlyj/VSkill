// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../../src/utils/PriceCoverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VSkillUser is Ownable {
    using PriceConverter for uint256;

    error VSkill__NotEnoughSubmissionFee(
        uint256 requiredFeeInUsd,
        uint256 submittedFeeInUsd
    );
    error VSkill__InvalidSkillDomain();
    error VSkill__SkillDomainAlreadyExists();

    struct evidence {
        string evidenceIpfsHash;
        string skillDomain;
        SubmissionStatus status;
    }

    enum SubmissionStatus {
        Submmited,
        InReview,
        Approved,
        Rejected
    }

    string[] private skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];
    AggregatorV3Interface internal priceFeed;
    uint256 private submissionFeeInUsd; // 5e18 -> 5 USD for each submission
    mapping(address => evidence[]) private addressToEvidences;

    event EvidenceSubmitted(
        address indexed submitter,
        string evidenceIpfsHash,
        string skillDomain
    );
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    constructor(
        uint256 _submissionFeeInUsd,
        address _priceFeed
    ) Ownable(msg.sender) {
        submissionFeeInUsd = _submissionFeeInUsd;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function submitEvidence(
        string memory evidenceIpfsHash,
        string memory skillDomain
    ) external payable {
        if (msg.value.convertEthToUsd(priceFeed) < submissionFeeInUsd) {
            revert VSkill__NotEnoughSubmissionFee(
                submissionFeeInUsd,
                msg.value.convertEthToUsd(priceFeed)
            );
        }

        if (!_isSkillDomainValid(skillDomain)) {
            revert VSkill__InvalidSkillDomain();
        }

        addressToEvidences[msg.sender].push(
            evidence({
                evidenceIpfsHash: evidenceIpfsHash,
                skillDomain: skillDomain,
                status: SubmissionStatus.Submmited
            })
        );

        emit EvidenceSubmitted(msg.sender, evidenceIpfsHash, skillDomain);
    }

    function changeSubmissionFee(uint256 newFeeInUsd) external onlyOwner {
        submissionFeeInUsd = newFeeInUsd;
        emit SubmissionFeeChanged(newFeeInUsd);
    }

    function addMoreSkills(string memory skillDomain) external onlyOwner {
        if (_skillDomainAlreadyExists(skillDomain)) {
            revert VSkill__SkillDomainAlreadyExists();
        }
        skillDomains.push(skillDomain);
        emit SkillDomainAdded(skillDomain);
    }

    // function checkFeedbackOfEvidence() external {} // To be implemented and the feedback is provided by the verifier. -> called by the user
    // function updateFeedbackofEvidence() external {} // This will be called by the verifier contract to update the feedback of the evidence. -> only be called by the verifier contract
    // function updateEvidenceStatus() external {} // This will be called by the verifier contract to update the status of the evidence. -> only be called by the verifier contract

    ///////////////////////////////
    /////  Internal Functions  ////
    ///////////////////////////////

    function _isSkillDomainValid(
        string memory skillDomain
    ) internal view returns (bool) {
        uint256 length = skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(skillDomains[i])) ==
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
        uint256 length = skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(skillDomains[i])) ==
                keccak256(abi.encodePacked(skillDomain))
            ) {
                return true;
            }
        }
        return false;
    }

    // function _gainNFTAsProofOfSkill() internal {} // To be implemented and called once the evidence is approved by the verifier -> chainlink automation

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getSubmissionFeeInUsd() external view returns (uint256) {
        return submissionFeeInUsd;
    }

    function getAddressToEvidences(
        address _address
    ) external view returns (evidence[] memory) {
        return addressToEvidences[_address];
    }

    function getEvidenceStatus(
        address _address,
        uint256 index
    ) external view returns (SubmissionStatus) {
        return addressToEvidences[_address][index].status;
    }

    function getSkillDomains() external view returns (string[] memory) {
        return skillDomains;
    }
}
