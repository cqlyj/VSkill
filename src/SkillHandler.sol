// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SkillHandler
/// @author Luo Yingjie
/// @notice This contract is used to add more skills, force the two functions to always be called together
contract SkillHandler is Ownable {
    VSkillUser private s_vSkillUser;
    VSkillUserNft private s_vSkillUserNft;

    constructor(address vskillUser, address vskillUserNft) Ownable(msg.sender) {
        s_vSkillUser = VSkillUser(payable(vskillUser));
        s_vSkillUserNft = VSkillUserNft(vskillUserNft);
    }

    function addMoreSkill(
        string memory skillDomain,
        string memory nftImageUri
    ) external onlyOwner {
        s_vSkillUserNft.addMoreSkillsForNft(skillDomain, nftImageUri);
        s_vSkillUser.addMoreSkills(skillDomain);
    }
}
