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

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract VSkillUserNft is ERC721 {
    uint256 private tokenCounter;
    string[] private skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];
    string[] private userNftImageUris;
    mapping(string => string) private skillDomainToUserNftImageUri;
    mapping(uint256 => string) private tokenIdToSkillDomain;

    constructor(
        string[] memory _userNftImageUris
    ) ERC721("VSkillUserNft", "VSU") {
        tokenCounter = 0;
        userNftImageUris = _userNftImageUris;
        uint256 skillDomainLength = skillDomains.length;
        for (uint256 i = 0; i < skillDomainLength; i++) {
            skillDomainToUserNftImageUri[skillDomains[i]] = userNftImageUris[i];
        }
    }

    function mintUserNft(string memory skillDomain) external {
        _safeMint(msg.sender, tokenCounter);
        tokenIdToSkillDomain[tokenCounter] = skillDomain;
        tokenCounter++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory skillDomain = tokenIdToSkillDomain[tokenId];
        string memory imageUri = skillDomainToUserNftImageUri[skillDomain];

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes( // bytes casting actually unnecessary as 'abi.encodePacked()' returns a bytes
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"Proof of capability of the skill", ',
                                '"attributes": [{"trait_type": "skill", "value": 100}], "image":"',
                                imageUri,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
