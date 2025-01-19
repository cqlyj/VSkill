// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Script, console} from "forge-std/Script.sol";
// import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
// import {VSkillUserNft} from "src/nft/VSkillUserNft.sol";
// import {HelperConfig} from "./HelperConfig.s.sol";

// contract MintUserNftVSkillUserNft is Script {
//     string public skillDomain;

//     function mintUserNftVSkillUserNft(address mostRecentlyDeployed) public {
//         vm.startBroadcast();
//         VSkillUserNft vSkillUserNft = VSkillUserNft(mostRecentlyDeployed);
//         string[] memory skillDomains = vSkillUserNft.getSkillDomains();
//         vSkillUserNft.mintUserNft(skillDomains[0]);
//         vm.stopBroadcast();

//         console.log("Minted user NFT for skill domain: ", skillDomains[0]);
//         console.log("User NFT minted successfully");
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "VSkillUserNft",
//             block.chainid
//         );

//         console.log("Most recently deployed address: ", mostRecentlyDeployed);
//         mintUserNftVSkillUserNft(mostRecentlyDeployed);
//     }
// }
