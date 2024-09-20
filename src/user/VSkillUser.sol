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
import {Staking} from "../staking/Staking.sol";
import {VSkillUserNft} from "../nft/VSkillUserNft.sol";

contract VSkillUser is Ownable, Staking, VSkillUserNft {
    using PriceConverter for uint256;

    error VSkillUser__NotEnoughSubmissionFee(
        uint256 requiredFeeInUsd,
        uint256 submittedFeeInUsd
    );
    error VSkillUser__InvalidSkillDomain();
    error VSkillUser__SkillDomainAlreadyExists();
    error VSkillUser__EvidenceNotApprovedYet(SubmissionStatus status);

    struct evidence {
        address submitter;
        string evidenceIpfsHash;
        string skillDomain;
        SubmissionStatus status;
        string feedbackIpfsHash;
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

    uint256 private submissionFeeInUsd; // 5e18 -> 5 USD for each submission
    mapping(address => evidence[]) public addressToEvidences;

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
        submissionFeeInUsd = _submissionFeeInUsd;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function submitEvidence(
        string memory evidenceIpfsHash,
        string memory skillDomain
    ) external payable {
        if (msg.value.convertEthToUsd(priceFeed) < submissionFeeInUsd) {
            revert VSkillUser__NotEnoughSubmissionFee(
                submissionFeeInUsd,
                msg.value.convertEthToUsd(priceFeed)
            );
        }

        if (!_isSkillDomainValid(skillDomain)) {
            revert VSkillUser__InvalidSkillDomain();
        }

        addressToEvidences[msg.sender].push(
            evidence({
                submitter: msg.sender,
                evidenceIpfsHash: evidenceIpfsHash,
                skillDomain: skillDomain,
                status: SubmissionStatus.Submmited,
                feedbackIpfsHash: ""
            })
        );

        emit EvidenceSubmitted(msg.sender, evidenceIpfsHash, skillDomain);
    }

    function checkFeedbackOfEvidence(
        uint256 index
    ) external view returns (string memory) {
        return addressToEvidences[msg.sender][index].feedbackIpfsHash;
    }

    function earnUserNft(evidence memory _evidence) external {
        _earnUserNft(_evidence);
    }

    ///////////////////////////////
    //////  Owner Functions  //////
    ///////////////////////////////

    function changeSubmissionFee(uint256 newFeeInUsd) external onlyOwner {
        submissionFeeInUsd = newFeeInUsd;
        emit SubmissionFeeChanged(newFeeInUsd);
    }

    function addMoreSkills(
        string memory skillDomain,
        string memory newNftImageUri
    ) external onlyOwner {
        if (_skillDomainAlreadyExists(skillDomain)) {
            revert VSkillUser__SkillDomainAlreadyExists();
        }
        skillDomains.push(skillDomain);
        super._addMoreSkillsForNft(skillDomain, newNftImageUri);
        emit SkillDomainAdded(skillDomain);
    }

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

    function _earnUserNft(evidence memory _evidence) internal {
        if (_evidence.status != SubmissionStatus.Approved) {
            revert VSkillUser__EvidenceNotApprovedYet(_evidence.status);
        }

        mintUserNft(_evidence.skillDomain);
    }

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
}
