// SPDX-License-Identifier: MIT

// @written audit-info floating pragma
pragma solidity 0.8.26;

import {StructDefinition} from "../library/StructDefinition.sol";

/**
 * @title VerifierInterfacev that will be implemented by the Verifier contract
 * @author Luo Yingjie
 * @notice This interface is for the Distribution contract call the Verifier contract callback function => _selectedVerifiersAddressCallback
 */
interface VerifierInterface {
    function _selectedVerifiersAddressCallback(
        StructDefinition.VSkillUserEvidence memory ev,
        uint256[] memory randomWords
    ) external;
}
