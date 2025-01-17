// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "src/library/PriceCoverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Distribution} from "src/Distribution.sol";

contract VSkillUser is Ownable {
    using PriceConverter for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error VSkillUser__NotEnoughSubmissionFee();
    error VSkillUser__InvalidSkillDomain();
    error VSkillUser__SkillDomainAlreadyExists();
    error VSkillUser__EvidenceNotApprovedYet(
        StructDefinition.VSkillUserSubmissionStatus status
    );
    error VSkillUser__EvidenceIndexOutOfRange();
    error VSkillUser__NotInitialized();
    error VSkillUser__AlreadyInitialized();
    error VSkillUser__NotSkillHandler();

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
    mapping(uint256 requestId => StructDefinition.VSkillUserEvidence)
        public s_requestIdToEvidence;
    StructDefinition.VSkillUserEvidence[] public s_evidences;
    AggregatorV3Interface private i_priceFeed;
    address private skillHandler;
    bool private s_initialized;
    Distribution private immutable i_distribution;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event EvidenceSubmitted(address indexed submitter);
    event SubmissionFeeChanged(uint256 newFeeInUsd);
    event SkillDomainAdded(string skillDomain);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyInitialized() {
        if (!s_initialized) {
            revert VSkillUser__NotInitialized();
        }
        _;
    }

    modifier onlyNotInitialized() {
        if (s_initialized) {
            revert VSkillUser__AlreadyInitialized();
        }
        _;
    }

    modifier onlySkillHandler() {
        // The skillHandler is the one who can add more skills
        // The tx.origin is the user who is calling the function to add more skills
        if (msg.sender != skillHandler || tx.origin != owner()) {
            revert VSkillUser__NotSkillHandler();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _submissionFeeInUsd,
        address _priceFeed,
        address _distribution
    ) Ownable(msg.sender) {
        s_submissionFeeInUsd = _submissionFeeInUsd;
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        s_initialized = false;
        i_distribution = Distribution(_distribution);
    }

    function initializeSkillHandler(
        address _skillHandler
    ) external onlyOwner onlyNotInitialized {
        skillHandler = _skillHandler;
        s_initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // cid is the lighthouse cid of the evidence
    function submitEvidence(
        string memory cid,
        string memory skillDomain
    ) public payable onlyInitialized {
        if (msg.value.convertEthToUsd(i_priceFeed) < s_submissionFeeInUsd) {
            revert VSkillUser__NotEnoughSubmissionFee();
        }

        if (!_isSkillDomainValid(skillDomain)) {
            revert VSkillUser__InvalidSkillDomain();
        }

        s_addressToEvidences[msg.sender].push(
            StructDefinition.VSkillUserEvidence({
                submitter: msg.sender,
                cid: cid,
                skillDomain: skillDomain,
                status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                feedbackCids: new string[](0)
            })
        );

        s_evidences.push(
            StructDefinition.VSkillUserEvidence({
                submitter: msg.sender,
                cid: cid,
                skillDomain: skillDomain,
                status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                feedbackCids: new string[](0)
            })
        );

        // update this mapping so that Relayer can get the evidence
        uint256 requestId = i_distribution
            .distributionRandomNumberForVerifiers();
        s_requestIdToEvidence[requestId] = s_evidences[s_evidences.length - 1];

        emit EvidenceSubmitted(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @written audit-info centralization of the submission fee, is it a good idea?
    function changeSubmissionFee(
        uint256 newFeeInUsd
    ) public onlyOwner onlyInitialized {
        s_submissionFeeInUsd = newFeeInUsd;
        emit SubmissionFeeChanged(newFeeInUsd);
    }

    function addMoreSkills(
        string memory skillDomain
    ) external virtual onlyOwner onlyInitialized onlySkillHandler {
        if (_skillDomainAlreadyExists(skillDomain)) {
            revert VSkillUser__SkillDomainAlreadyExists();
        }

        s_skillDomains.push(skillDomain);
        emit SkillDomainAdded(skillDomain);
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

    function getSkillDomains() external view returns (string[] memory) {
        return s_skillDomains;
    }

    function getFeedbackOfEvidence(
        uint256 indexOfUserEvidence
    ) public view returns (string[] memory) {
        if (indexOfUserEvidence >= s_evidences.length) {
            revert VSkillUser__EvidenceIndexOutOfRange();
        }

        return
            s_addressToEvidences[msg.sender][indexOfUserEvidence].feedbackCids;
    }

    function getRequestIdToEvidence(
        uint256 requestId
    ) public view returns (StructDefinition.VSkillUserEvidence memory) {
        return s_requestIdToEvidence[requestId];
    }
}

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
