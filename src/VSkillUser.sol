// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "src/library/PriceCoverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Distribution} from "src/Distribution.sol";
import {Relayer} from "src/Relayer.sol";

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
    error VSkillUser__NotRelayer();
    error VSkillUser__WithdrawFailed();
    error VSkillUser__TransferBonusFailed();

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
    AggregatorV3Interface private immutable i_priceFeed;
    address private i_relayer;
    bool private s_initialized;
    Distribution private immutable i_distribution;
    // This bonus will be sent to the Verifier contract in a certain interval
    uint256 private s_bonus;
    mapping(uint256 requestId => address[] verifiersApprovedEvidence)
        private s_requestIdToVerifiersApprovedEvidence;
    uint256 private constant BONUS_WEIGHT = 20;
    uint256 private constant TOTAL_WEIGHT = 100;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VSkillUser__EvidenceSubmitted(address indexed submitter);
    event VSkillUser__SubmissionFeeChanged(uint256 newFeeInUsd);
    event VSkillUser__SkillDomainAdded(string skillDomain);
    event VSkillUser__Initialized(address relayer);
    event VSkillUser__TransferBonus(uint256 bonus);

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

    modifier onlyRelayer() {
        // The Relayer is the one who can add more skills
        // The tx.origin is the user who is calling the function to add more skills
        if (msg.sender != i_relayer || tx.origin != owner()) {
            revert VSkillUser__NotRelayer();
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

    function initializeRelayer(
        address _relayer
    ) external onlyOwner onlyNotInitialized {
        //slither-disable-next-line missing-zero-check
        i_relayer = _relayer;
        s_initialized = true;

        emit VSkillUser__Initialized(i_relayer);
    }

    // For those unexpected ETH received, we will take them as the bonus for verifiers
    receive() external payable {
        s_bonus += msg.value;
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
                // for now all false, will be updated by the verifier if they approve the evidence
                // for those who doesn't provide the feedback in time, we will take it as false
                statusApproveOrNot: [false, false, false],
                feedbackCids: new string[](0),
                // This will be updated once the evidence is distributed to the verifiers
                deadline: block.timestamp
            })
        );

        s_evidences.push(
            StructDefinition.VSkillUserEvidence({
                submitter: msg.sender,
                cid: cid,
                skillDomain: skillDomain,
                status: StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                statusApproveOrNot: [false, false, false],
                feedbackCids: new string[](0),
                deadline: block.timestamp
            })
        );

        // update this mapping so that Relayer can get the evidence
        uint256 requestId = i_distribution
            .distributionRandomNumberForVerifiers();
        s_requestIdToEvidence[requestId] = s_evidences[s_evidences.length - 1];

        // 20% will be the bonus for verifiers
        s_bonus += (msg.value * BONUS_WEIGHT) / TOTAL_WEIGHT;
        // rest will be the profit or the money required for Chainlink services

        emit VSkillUser__EvidenceSubmitted(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/

    function approveEvidenceStatus(
        uint256 requestId,
        string memory feedbackCid
    ) public onlyInitialized {
        _calledByVerifierContract();
        StructDefinition.VSkillUserEvidence
            storage evidence = s_requestIdToEvidence[requestId];

        // check for the statusApproveOrNot array
        // if it's false, we will update it to true
        // else jump to the next one
        for (uint8 i = 0; i < evidence.statusApproveOrNot.length; i++) {
            if (!evidence.statusApproveOrNot[i]) {
                evidence.statusApproveOrNot[i] = true;
                s_requestIdToVerifiersApprovedEvidence[requestId].push(
                    // the tx.origin is the one who initiated the transaction
                    // @audit test this!
                    tx.origin
                );
                evidence.feedbackCids.push(feedbackCid);
                break;
            }
        }
    }

    function setDeadline(
        uint256 requestId,
        uint256 deadline
    ) public onlyInitialized onlyRelayer {
        s_requestIdToEvidence[requestId].deadline = deadline;
    }

    function setEvidenceStatus(
        uint256 requestId,
        StructDefinition.VSkillUserSubmissionStatus status
    ) public onlyInitialized onlyRelayer {
        s_requestIdToEvidence[requestId].status = status;
    }

    function transferBonusToVerifierContract(
        address verifierContractAddress
    ) public onlyInitialized onlyRelayer returns (uint256) {
        uint256 bonusAmount = s_bonus;
        s_bonus = 0;
        //slither-disable-next-line missing-zero-check
        (bool success, ) = verifierContractAddress.call{value: bonusAmount}("");
        if (!success) {
            revert VSkillUser__TransferBonusFailed();
        }

        emit VSkillUser__TransferBonus(bonusAmount);

        return bonusAmount;
    }

    function addMoreSkills(
        string memory skillDomain
    ) external virtual onlyInitialized onlyRelayer {
        if (_skillDomainAlreadyExists(skillDomain)) {
            revert VSkillUser__SkillDomainAlreadyExists();
        }

        s_skillDomains.push(skillDomain);
        emit VSkillUser__SkillDomainAdded(skillDomain);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @written audit-info centralization of the submission fee, is it a good idea?
    function changeSubmissionFee(
        uint256 newFeeInUsd
    ) public onlyOwner onlyInitialized {
        s_submissionFeeInUsd = newFeeInUsd;
        emit VSkillUser__SubmissionFeeChanged(newFeeInUsd);
    }

    function withdrawProfit() external onlyOwner onlyInitialized {
        (bool success, ) = msg.sender.call{
            value: address(this).balance - s_bonus
        }("");
        if (!success) {
            revert VSkillUser__WithdrawFailed();
        }
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

    function _calledByVerifierContract() internal view {
        if (msg.sender != Relayer(i_relayer).getVerifierContractAddress()) {
            revert VSkillUser__NotRelayer();
        }
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

    function getRequestIdToEvidenceStatus(
        uint256 requestId
    ) public view returns (StructDefinition.VSkillUserSubmissionStatus) {
        return s_requestIdToEvidence[requestId].status;
    }

    function getRequestIdToDeadline(
        uint256 requestId
    ) public view returns (uint256) {
        return s_requestIdToEvidence[requestId].deadline;
    }

    function getRequestIdToEvidenceSkillDomain(
        uint256 requestId
    ) public view returns (string memory) {
        return s_requestIdToEvidence[requestId].skillDomain;
    }

    function getRequestIdToVerifiersApprovedEvidence(
        uint256 requestId
    ) public view returns (address[] memory) {
        return s_requestIdToVerifiersApprovedEvidence[requestId];
    }

    function getRequestIdToVerifiersApprovedEvidenceLength(
        uint256 requestId
    ) public view returns (uint256) {
        return s_requestIdToVerifiersApprovedEvidence[requestId].length;
    }

    function getDistributionContractAddress() public view returns (address) {
        return address(i_distribution);
    }

    function getBonus() public view returns (uint256) {
        return s_bonus;
    }

    function getBonusWeight() public pure returns (uint256) {
        return BONUS_WEIGHT;
    }

    function getTotalWeight() public pure returns (uint256) {
        return TOTAL_WEIGHT;
    }

    function getSubmissionFeeInEth() public view returns (uint256) {
        return s_submissionFeeInUsd.convertUsdToEth(i_priceFeed);
    }
}
