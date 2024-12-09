// SPDX-License-Identifier: MIT

// @written audit-info floating pragma
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title VSkillUserNft contract for minting user NFTs with skill domains
 * @author Luo Yingjie
 * @notice This is the contract for minting user NFTs with skill domains
 * @dev The user NFTs are minted with skill domains, it's a ERC721 svg NFT
 */
contract VSkillUserNft is ERC721 {
    uint256 private s_tokenCounter;
    string[] private s_skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];
    string[] private s_userNftImageUris;
    mapping(string => string) private s_skillDomainToUserNftImageUri;
    mapping(uint256 => string) private s_tokenIdToSkillDomain;

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
        s_tokenCounter = 0;
        s_userNftImageUris = _userNftImageUris;
        uint256 skillDomainLength = s_skillDomains.length;
        // e length here is just 5, it's fine
        for (uint256 i = 0; i < skillDomainLength; i++) {
            s_skillDomainToUserNftImageUri[
                s_skillDomains[i]
            ] = s_userNftImageUris[i];
        }
    }

    /**
     *
     * @param skillDomain The domain of the skill
     * @dev Mint a user NFT with the skill domain
     */

    // @audit-low This function not checking for the skillDomain input, users can mint NFT with non-existing skill domains, not a big deal
    // @written audit-high This function is not restricted to any specific user, anyone can mint a NFT
    // Users can directly call this function to mint a NFT with any skill domain instead of providing a proof of skill
    function mintUserNft(string memory skillDomain) public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;

        emit MintNftSuccess(s_tokenCounter - 1, skillDomain);
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
        string memory skillDomain = s_tokenIdToSkillDomain[tokenId];
        // what if skillDomain is not found?
        // imageUri will not revert, but just be blank
        // @audit-info/low if the tokenId is not found, the function will return a blank string
        string memory imageUri = s_skillDomainToUserNftImageUri[skillDomain];

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
        s_skillDomains.push(skillDomain);
        s_userNftImageUris.push(newNftImageUri);
        s_skillDomainToUserNftImageUri[skillDomain] = newNftImageUri;

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
        return s_tokenCounter;
    }

    function getSkillDomains() external view returns (string[] memory) {
        return s_skillDomains;
    }

    function getUserNftImageUris() external view returns (string[] memory) {
        return s_userNftImageUris;
    }

    function getSkillDomainToUserNftImageUri(
        string memory skillDomain
    ) external view returns (string memory) {
        return s_skillDomainToUserNftImageUri[skillDomain];
    }

    function getTokenIdToSkillDomain(
        uint256 tokenId
    ) external view returns (string memory) {
        return s_tokenIdToSkillDomain[tokenId];
    }

    function getBaseURI() external pure returns (string memory) {
        return _baseURI();
    }
}
