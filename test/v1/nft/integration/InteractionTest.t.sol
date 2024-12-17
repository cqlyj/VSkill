// SPDX-License-Identifier: MIT

// import {Test, console} from "forge-std/Test.sol";
// import {DeployVSkillUserNft} from "script/nft/DeployVSkillUserNft.s.sol";
// import {VSkillUserNft} from "src/nft/VSkillUserNft.sol";
// import {MintUserNftVSkillUserNft} from "script/nft/Interactions.s.sol";
// import {Vm} from "forge-std/Vm.sol";

pragma solidity ^0.8.24;

// contract InteractionTest is Test {
//     VSkillUserNft vSkillUserNft;
//     DeployVSkillUserNft deployVSkillUserNft;

//     function setUp() external {
//         deployVSkillUserNft = new DeployVSkillUserNft();
//         (vSkillUserNft, ) = deployVSkillUserNft.run();
//     }

//     function testInteractionsVSkillUserNft() external {
//         MintUserNftVSkillUserNft mintUserNftVSkillUserNft = new MintUserNftVSkillUserNft();

//         vm.recordLogs();
//         mintUserNftVSkillUserNft.mintUserNftVSkillUserNft(
//             address(vSkillUserNft)
//         );
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         assertEq(entries.length, 2);
//         console.log("User NFT minted successfully");
//     }
// }
