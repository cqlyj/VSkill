// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ILogAutomation, Log} from "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";

interface IRelayer is ILogAutomation {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Relayer__InvalidBatchNumber();
    error Relayer__OnlyForwarder();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Relayer__UnhandledRequestIdAdded(
        uint256 indexed unhandledRequestIdsLength
    );
    event Relayer__NotEnoughVerifierForThisSkillDomainYet();
    event Relayer__EvidenceAssignedToVerifiers();
    event Relayer__EvidenceProcessed(uint256 indexed batchNumber);
    event Relayer__UserNftsMinted(uint256 indexed batchNumber);
    event Relayer__ForwarderSet(address forwarder);

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setForwarder(address forwarder) external;

    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;

    function assignEvidenceToVerifiers() external;

    function processEvidenceStatus(uint256 batchNumber) external;

    function handleEvidenceAfterDeadline(uint256 batchNumber) external;

    function mintUserNfts(uint256 batchNumber) external;

    function rewardOrPenalizeVerifiers(uint256 batchNumber) external;

    function addMoreSkill(
        string memory skillDomain,
        string memory nftImageUri
    ) external;

    function transferBonusFromVSkillUserToVerifierContract() external;

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getVerifierContractAddress() external view returns (address);

    function getForwarder() external view returns (address);

    function getUnhandledRequestIds() external view returns (uint256[] memory);

    function getUnhandledRequestIdsLength() external view returns (uint256);

    function getBatchProcessed() external view returns (uint256);

    function getBatchToProcessedRequestIds(
        uint256 batchNumber
    ) external view returns (uint256[] memory);

    function getBatchToDeadline(
        uint256 batchNumber
    ) external view returns (uint256);

    function getBatchProcessedOrNot(
        uint256 batchNumber
    ) external view returns (StructDefinition.RelayerBatchStatus);

    function getDeadline() external pure returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                OWNABLE
    //////////////////////////////////////////////////////////////*/

    function owner() external view returns (address);
}
