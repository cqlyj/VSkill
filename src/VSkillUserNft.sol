// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VSkillUserNft is ERC721, AccessControl {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_tokenCounter;
    string[] private s_skillDomains;
    string[] private s_userNftImageUris;
    mapping(string => string) private s_skillDomainToUserNftImageUri;
    mapping(uint256 => string) private s_tokenIdToSkillDomain;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant SKILL_DOMAIN_ADDER_ROLE =
        keccak256("SKILL_DOMAIN_ADDER_ROLE");
    address private skillHandler;
    bool private s_initialized;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error VSkillUserNft__InvalidSkillDomain();
    error VSkillUserNft__NotInitialized();
    error VSkillUserNft__AlreadyInitialized();
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

    // Later we will set the Relayer contract as the owner of this contract
    // That is the minter will be the Relayer contract address
    constructor(
        address minter,
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

        _grantRole(MINTER_ROLE, minter);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // the skillHandler is the one who can add more skills
    function initializeSkillHandler(
        address _skillHandler
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotInitialized {
        skillHandler = _skillHandler;
        _grantRole(SKILL_DOMAIN_ADDER_ROLE, _skillHandler);
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
        string memory skillDomain
    ) public onlyRole(MINTER_ROLE) onlyInitialized {
        if (!_validSkillDomain(skillDomain)) {
            revert VSkillUserNft__InvalidSkillDomain();
        }

        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;
        _safeMint(msg.sender, s_tokenCounter - 1);

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
    ) public onlyRole(SKILL_DOMAIN_ADDER_ROLE) onlyInitialized {
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

// string[] private s_skillDomains = [
//     "Frontend",
//     "Backend",
//     "Fullstack",
//     "DevOps",
//     "Blockchain"
// ];
