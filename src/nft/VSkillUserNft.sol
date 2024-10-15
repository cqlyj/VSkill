// SPDX-License-Identifier: MIT

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

    ////////////////
    //   Events   //
    ////////////////
    event MintNftSuccess(uint256 indexed tokenId, string indexed skillDomain);
    event SkillDomainsForNftAdded(
        string indexed newSkillDomain,
        string indexed newNftImageUri
    );

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

    /**
     *
     * @param skillDomain The domain of the skill
     * @dev Mint a user NFT with the skill domain
     */
    function mintUserNft(string memory skillDomain) public {
        _safeMint(msg.sender, tokenCounter);
        tokenIdToSkillDomain[tokenCounter] = skillDomain;
        tokenCounter++;

        emit MintNftSuccess(tokenCounter - 1, skillDomain);
    }

    /**
     *
     * @param tokenId The id of the token
     * @return The URI of the token
     * @dev Get the URI of the token
     */
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

    ///////////////////////////////
    ///    Internal Functions   ///
    ///////////////////////////////

    /**
     *
     * @param skillDomain The domain of the skill
     * @param newNftImageUri New NFT image URI for the new skill domain
     */
    function _addMoreSkillsForNft(
        string memory skillDomain,
        string memory newNftImageUri
    ) public {
        skillDomains.push(skillDomain);
        userNftImageUris.push(newNftImageUri);
        skillDomainToUserNftImageUri[skillDomain] = newNftImageUri;

        emit SkillDomainsForNftAdded(skillDomain, newNftImageUri);
    }

    /**
     * @return The base URI of the token
     * @dev Get the base URI of the token
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getTokenCounter() external view returns (uint256) {
        return tokenCounter;
    }

    function getSkillDomains() external view returns (string[] memory) {
        return skillDomains;
    }

    function getUserNftImageUris() external view returns (string[] memory) {
        return userNftImageUris;
    }

    function getSkillDomainToUserNftImageUri(
        string memory skillDomain
    ) external view returns (string memory) {
        return skillDomainToUserNftImageUri[skillDomain];
    }

    function getTokenIdToSkillDomain(
        uint256 tokenId
    ) external view returns (string memory) {
        return tokenIdToSkillDomain[tokenId];
    }

    function getBaseURI() external pure returns (string memory) {
        return _baseURI();
    }
}
