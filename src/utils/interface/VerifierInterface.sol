// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {StructDefinition} from "../library/StructDefinition.sol";

interface VerifierInterface {
    function _selectedVerifiersAddressCallback(
        StructDefinition.VSkillUserEvidence memory ev,
        uint256[] memory randomWords
    ) external;
}
