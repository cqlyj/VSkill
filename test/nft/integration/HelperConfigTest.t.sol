// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployVSkillUserNft} from "../../../script/nft/DeployVSkillUserNft.s.sol";
import {VSkillUserNft} from "../../../src/nft/VSkillUserNft.sol";
import {HelperConfig} from "../../../script/nft/HelperConfig.s.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract HelperConfigTest is Test {
    DeployVSkillUserNft deployer;
    HelperConfig helperConfig;

    function setUp() external {
        deployer = new DeployVSkillUserNft();
        (, helperConfig) = deployer.run();
    }

    function testHelperConfigSvgToImageUri() external view {
        string
            memory expectedImageUri = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkZyb250ZW5kPC90ZXh0PgogIDx0ZXh0IHg9IjUwJSIgeT0iNzAlIiBmaWxsPSIjZmZmZmZmIiBmb250LWZhbWlseT0iJ1NGIFBybyBEaXNwbGF5JywgLWFwcGxlLXN5c3RlbSwgQmxpbmtNYWNTeXN0ZW1Gb250LCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjMyIiBmb250LXdlaWdodD0iNjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+RGV2ZWxvcGVyPC90ZXh0PgoKICA8IS0tIFN1YnRsZSBzaGFkb3cgZm9yIGRlcHRoIC0tPgogIDxyZWN0IHg9IjEwIiB5PSIxMCIgd2lkdGg9IjIzMCIgaGVpZ2h0PSIyMzAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIHN0cm9rZS13aWR0aD0iNSIgb3BhY2l0eT0iMC4xIiAvPgo8L3N2Zz4=";
        string memory svg = vm.readFile("./image/frontend.svg");
        string memory imageUri = helperConfig.svgToImageUri(svg);
        assertEq(
            keccak256(abi.encodePacked(imageUri)),
            keccak256(abi.encodePacked(expectedImageUri))
        );
    }
}
