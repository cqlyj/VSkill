// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VSkillUserNft is ERC721, AccessControl {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // @audit-gas the visibility can be internal as it's only used in this contract
    uint256 private s_tokenCounter;
    string[] private s_skillDomains;
    string[] private s_userNftImageUris;
    mapping(string => string) private s_skillDomainToUserNftImageUri;
    mapping(uint256 => string) private s_tokenIdToSkillDomain;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address private i_relayer;
    bool private s_initialized;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error VSkillUserNft__InvalidSkillDomain();
    error VSkillUserNft__NotInitialized();
    error VSkillUserNft__AlreadyInitialized();
    // @audit-info unused error
    error VSkillUserNft__NotSkillHandler();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VSkillUserNftMinted(
        uint256 indexed tokenId,
        string indexed skillDomain
    );
    event SkillDomainsForNftAdded(
        string indexed newSkillDomain,
        string indexed newNftImageUri
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyInitialized() {
        if (!s_initialized) {
            revert VSkillUserNft__NotInitialized();
        }
        _;
    }

    modifier onlyNotInitialized() {
        if (s_initialized) {
            revert VSkillUserNft__AlreadyInitialized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // Later we will set the Relayer contract as the one who can mint the NFT or add more skills
    constructor(
        string[] memory _skillDomains,
        string[] memory _userNftImageUris
    ) ERC721("VSkillUserNft", "VSU") {
        s_tokenCounter = 0;
        s_userNftImageUris = _userNftImageUris;
        s_skillDomains = _skillDomains;
        uint256 skillDomainLength = s_skillDomains.length;
        // length here will not be too large, so it's okay to use for loop
        for (uint256 i = 0; i < skillDomainLength; i++) {
            s_skillDomainToUserNftImageUri[
                s_skillDomains[i]
            ] = s_userNftImageUris[i];
        }
        s_initialized = false;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // the Relayer is the one who can add more skills
    function initializeRelayer(
        address _relayer
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotInitialized {
        //slither-disable-next-line missing-zero-check
        i_relayer = _relayer;
        _grantRole(MINTER_ROLE, _relayer);
        s_initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                           OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mintUserNft(
        string memory skillDomain,
        address to
    ) public onlyRole(MINTER_ROLE) onlyInitialized {
        if (!_validSkillDomain(skillDomain)) {
            revert VSkillUserNft__InvalidSkillDomain();
        }

        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;
        _safeMint(to, s_tokenCounter - 1);

        emit VSkillUserNftMinted(s_tokenCounter - 1, skillDomain);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // If the token is not minted yet, return empty string
        if (tokenId >= s_tokenCounter) {
            return "";
        }

        string memory skillDomain = s_tokenIdToSkillDomain[tokenId];
        string memory imageUri = s_skillDomainToUserNftImageUri[skillDomain];

        // abi.encodePacked() should not be used with dynamic types when passing the result to a hash function such as keccak256()
        // but for this case, it's not a big deal
        // @audit-info we should use abi.encode() instead of abi.encodePacked() to avoid the hash collision
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

    function addMoreSkillsForNft(
        string memory skillDomain,
        string memory newNftImageUri
    ) public onlyRole(MINTER_ROLE) onlyInitialized {
        s_skillDomains.push(skillDomain);
        s_userNftImageUris.push(newNftImageUri);
        s_skillDomainToUserNftImageUri[skillDomain] = newNftImageUri;

        emit SkillDomainsForNftAdded(skillDomain, newNftImageUri);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function _validSkillDomain(
        string memory skillDomain
    ) internal view returns (bool) {
        uint256 skillDomainLength = s_skillDomains.length;
        for (uint256 i = 0; i < skillDomainLength; i++) {
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
