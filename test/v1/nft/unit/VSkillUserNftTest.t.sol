// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployVSkillUserNft} from "script/nft/DeployVSkillUserNft.s.sol";
import {VSkillUserNft} from "src/nft/VSkillUserNft.sol";
import {HelperConfig} from "script/nft/HelperConfig.s.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract VSkillUserNftTest is Test {
    DeployVSkillUserNft deployer;
    HelperConfig helperConfig;
    VSkillUserNft vskillUserNft;
    string[] userNftImageUris;
    string[] skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];
    address USER = makeAddr("user");
    string constant FRONTEND_TOKEN_URI =
        "data:application/json;base64,eyJuYW1lIjoiVlNraWxsVXNlck5mdCIsICJkZXNjcmlwdGlvbiI6IlByb29mIG9mIGNhcGFiaWxpdHkgb2YgdGhlIHNraWxsIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInNraWxsIiwgInZhbHVlIjogMTAwfV0sICJpbWFnZSI6ImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU1qVXdJaUJvWldsbmFIUTlJakkxTUNJZ2RtbGxkMEp2ZUQwaU1DQXdJREkxTUNBeU5UQWlJSGh0Ykc1elBTSm9kSFJ3T2k4dmQzZDNMbmN6TG05eVp5OHlNREF3TDNOMlp5SStDaUFnUENFdExTQkNZV05yWjNKdmRXNWtJSGRwZEdnZ2IzSnBaMmx1WVd3Z1ozSmhaR2xsYm5RZ0xTMCtDaUFnUEdSbFpuTStDaUFnSUNBOGJHbHVaV0Z5UjNKaFpHbGxiblFnYVdROUltZHlZV1F4SWlCNE1UMGlNQ1VpSUhreFBTSXdKU0lnZURJOUlqRXdNQ1VpSUhreVBTSXhNREFsSWo0S0lDQWdJQ0FnUEhOMGIzQWdiMlptYzJWMFBTSXdKU0lnYzNSNWJHVTlJbk4wYjNBdFkyOXNiM0k2STJKa1l6TmpOenR6ZEc5d0xXOXdZV05wZEhrNk1TSWdMejRLSUNBZ0lDQWdQSE4wYjNBZ2IyWm1jMlYwUFNJeE1EQWxJaUJ6ZEhsc1pUMGljM1J2Y0MxamIyeHZjam9qTW1NelpUVXdPM04wYjNBdGIzQmhZMmwwZVRveElpQXZQZ29nSUNBZ1BDOXNhVzVsWVhKSGNtRmthV1Z1ZEQ0S0lDQThMMlJsWm5NK0NpQWdQSEpsWTNRZ2VEMGlNQ0lnZVQwaU1DSWdkMmxrZEdnOUlqSTFNQ0lnYUdWcFoyaDBQU0l5TlRBaUlISjRQU0l4TlNJZ2NuazlJakUxSWlCbWFXeHNQU0oxY213b0kyZHlZV1F4S1NJZ0x6NEtDaUFnUENFdExTQkNiM0prWlhJZ0xTMCtDaUFnUEhKbFkzUWdlRDBpTVRBaUlIazlJakV3SWlCM2FXUjBhRDBpTWpNd0lpQm9aV2xuYUhROUlqSXpNQ0lnY25nOUlqRTFJaUJ5ZVQwaU1UVWlJR1pwYkd3OUltNXZibVVpSUhOMGNtOXJaVDBpSTJWalpqQm1NU0lnYzNSeWIydGxMWGRwWkhSb1BTSXlJaUF2UGdvS0lDQThJUzB0SUVGd2NDQk9ZVzFsSUdGeklHSmhZMnRuY205MWJtUWdjMmhoY0dVZ0xTMCtDaUFnUEhSbGVIUWdlRDBpTlRBbElpQjVQU0l6TlNVaUlHWnBiR3c5SWlObVptWm1abVlpSUdadmJuUXRabUZ0YVd4NVBTSW5VMFlnVUhKdklFUnBjM0JzWVhrbkxDQXRZWEJ3YkdVdGMzbHpkR1Z0TENCQ2JHbHVhMDFoWTFONWMzUmxiVVp2Ym5Rc0lITmhibk10YzJWeWFXWWlJR1p2Ym5RdGMybDZaVDBpTnpBaUlHWnZiblF0ZDJWcFoyaDBQU0ppYjJ4a0lpQjBaWGgwTFdGdVkyaHZjajBpYldsa1pHeGxJaUJ2Y0dGamFYUjVQU0l3TGpJMUlqNVdVMnRwYkd3OEwzUmxlSFErQ2dvZ0lEd2hMUzBnVkdsMGJHVWdkMmwwYUNCdGIzSmxJR0YwZEdWdWRHbHZiaUF0TFQ0S0lDQThkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqVTFKU0lnWm1sc2JEMGlJMlptWm1abVppSWdabTl1ZEMxbVlXMXBiSGs5SWlkVFJpQlFjbThnUkdsemNHeGhlU2NzSUMxaGNIQnNaUzF6ZVhOMFpXMHNJRUpzYVc1clRXRmpVM2x6ZEdWdFJtOXVkQ3dnYzJGdWN5MXpaWEpwWmlJZ1ptOXVkQzF6YVhwbFBTSXpNaUlnWm05dWRDMTNaV2xuYUhROUlqWXdNQ0lnZEdWNGRDMWhibU5vYjNJOUltMXBaR1JzWlNJZ1pIazlJaTR6WlcwaVBrWnliMjUwWlc1a1BDOTBaWGgwUGdvZ0lEeDBaWGgwSUhnOUlqVXdKU0lnZVQwaU56QWxJaUJtYVd4c1BTSWpabVptWm1abUlpQm1iMjUwTFdaaGJXbHNlVDBpSjFOR0lGQnlieUJFYVhOd2JHRjVKeXdnTFdGd2NHeGxMWE41YzNSbGJTd2dRbXhwYm10TllXTlRlWE4wWlcxR2IyNTBMQ0J6WVc1ekxYTmxjbWxtSWlCbWIyNTBMWE5wZW1VOUlqTXlJaUJtYjI1MExYZGxhV2RvZEQwaU5qQXdJaUIwWlhoMExXRnVZMmh2Y2owaWJXbGtaR3hsSWlCa2VUMGlMak5sYlNJK1JHVjJaV3h2Y0dWeVBDOTBaWGgwUGdvS0lDQThJUzB0SUZOMVluUnNaU0J6YUdGa2IzY2dabTl5SUdSbGNIUm9JQzB0UGdvZ0lEeHlaV04wSUhnOUlqRXdJaUI1UFNJeE1DSWdkMmxrZEdnOUlqSXpNQ0lnYUdWcFoyaDBQU0l5TXpBaUlISjRQU0l4TlNJZ2NuazlJakUxSWlCbWFXeHNQU0p1YjI1bElpQnpkSEp2YTJVOUlpTXdNREFpSUhOMGNtOXJaUzEzYVdSMGFEMGlOU0lnYjNCaFkybDBlVDBpTUM0eElpQXZQZ284TDNOMlp6ND0ifQ==";
    string constant BASE_URI = "data:application/json;base64,";

    event MintNftSuccess(uint256 indexed tokenId, string indexed skillDomain);
    event SkillDomainsForNftAdded(
        string indexed newSkillDomain,
        string indexed newNftImageUri
    );

    function setUp() external {
        deployer = new DeployVSkillUserNft();
        (vskillUserNft, helperConfig) = deployer.run();
        userNftImageUris = helperConfig
            .getActiveNetworkConfig()
            .userNftImageUris;
    }

    ///////////////////////////
    ///     constructor     ///
    ///////////////////////////

    function testVSkillUserNftGetRightTokenCounter() external view {
        uint256 tokenCounter = vskillUserNft.getTokenCounter();
        assertEq(tokenCounter, 0);
    }

    function testVSkillUserNftGetRightUserNftImageUris() external view {
        string[] memory userNftImageUrisActual = vskillUserNft
            .getUserNftImageUris();
        assertEq(userNftImageUrisActual.length, userNftImageUris.length);
        uint256 length = userNftImageUris.length;
        for (uint256 i = 0; i < length; i++) {
            assertEq(
                keccak256(abi.encodePacked(userNftImageUrisActual[i])),
                keccak256(abi.encodePacked(userNftImageUris[i]))
            );
        }
    }

    function testVSkillUserNftGetRightSkillDomains() external view {
        string[] memory skillDomainsActual = vskillUserNft.getSkillDomains();
        assertEq(skillDomainsActual.length, 5);
        uint256 length = skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            assertEq(skillDomainsActual[i], skillDomains[i]);
        }
    }

    ///////////////////////////
    ///     mintUserNft     ///
    ///////////////////////////

    function testVSkillUserNftMintUserNftWillIncreaseTokenCounter() external {
        vm.prank(USER);
        vskillUserNft.mintUserNft(skillDomains[0]);
        uint256 tokenCounter = vskillUserNft.getTokenCounter();
        assertEq(tokenCounter, 1);
    }

    function testVSkillUserNftMintUserNftWillAssignSkillDomainToTokenId()
        external
    {
        vm.prank(USER);
        vskillUserNft.mintUserNft(skillDomains[0]);
        string memory skillDomain = vskillUserNft.getTokenIdToSkillDomain(0);
        assertEq(skillDomain, skillDomains[0]);
    }

    function testVSkillUserNftMintUserNftWillEmitMintNftSuccessEvent()
        external
    {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false, address(vskillUserNft));
        emit MintNftSuccess(0, skillDomains[0]);
        vskillUserNft.mintUserNft(skillDomains[0]);
        vm.stopPrank();
    }

    ////////////////////////
    ///     _baseURI     ///
    ////////////////////////

    function testVSkillUserNftReturnsRightBaseURI() external view {
        string memory baseURI = vskillUserNft.getBaseURI();
        assertEq(baseURI, BASE_URI);
    }

    ////////////////////////
    ///     tokenURI     ///
    ////////////////////////

    function testVSkillUserNftReturnsCorrectTokenURI() external {
        vm.prank(USER);
        vskillUserNft.mintUserNft(skillDomains[0]);
        string memory tokenURI = vskillUserNft.tokenURI(0);
        string memory expectedTokenURI = FRONTEND_TOKEN_URI;
        assertEq(
            keccak256(abi.encodePacked(tokenURI)),
            keccak256(abi.encodePacked(expectedTokenURI))
        );
    }

    ////////////////////////////////////
    ///     _addMoreSkillsForNft     ///
    ////////////////////////////////////

    function testVSkillUserNftAddMoreSkillsForNftUpdateSkillDomains() external {
        string memory newSkillDomain = "AI";
        string memory newNftImageUri = "https://example.com/ai.svg";

        uint256 previousSkillDomainLength = skillDomains.length;
        vskillUserNft._addMoreSkillsForNft(newSkillDomain, newNftImageUri);
        uint256 currentSkillDomainLength = vskillUserNft
            .getSkillDomains()
            .length;
        assertEq(currentSkillDomainLength, previousSkillDomainLength + 1);

        string[] memory skillDomainsActual = vskillUserNft.getSkillDomains();
        string memory lastSkillDomain = skillDomainsActual[
            previousSkillDomainLength
        ];
        assertEq(
            keccak256(abi.encodePacked(lastSkillDomain)),
            keccak256(abi.encodePacked(newSkillDomain))
        );
    }

    function testVSkillUserNftAddMoreSkillsForNftUpdateUserNftImageUris()
        external
    {
        string memory newSkillDomain = "AI";
        string memory newNftImageUri = "https://example.com/ai.svg";

        uint256 previousUserNftImageUrisLength = vskillUserNft
            .getUserNftImageUris()
            .length;
        vskillUserNft._addMoreSkillsForNft(newSkillDomain, newNftImageUri);
        uint256 currentUserNftImageUrisLength = vskillUserNft
            .getUserNftImageUris()
            .length;
        assertEq(
            currentUserNftImageUrisLength,
            previousUserNftImageUrisLength + 1
        );

        string[] memory userNftImageUrisActual = vskillUserNft
            .getUserNftImageUris();
        string memory lastUserNftImageUri = userNftImageUrisActual[
            previousUserNftImageUrisLength
        ];
        assertEq(
            keccak256(abi.encodePacked(lastUserNftImageUri)),
            keccak256(abi.encodePacked(newNftImageUri))
        );
    }

    function testVSkillUserNftAddMoreSkillsForNftUpdateSkillDomainToUserNftImageUri()
        external
    {
        string memory newSkillDomain = "AI";
        string memory newNftImageUri = "https://example.com/ai.svg";

        vskillUserNft._addMoreSkillsForNft(newSkillDomain, newNftImageUri);
        string memory userNftImageUri = vskillUserNft
            .getSkillDomainToUserNftImageUri(newSkillDomain);
        assertEq(
            keccak256(abi.encodePacked(userNftImageUri)),
            keccak256(abi.encodePacked(newNftImageUri))
        );
    }

    function testVSkillUserNftAddMoreSkillsForNftWillEmitSkillDomainsForNftAddedEvent()
        external
    {
        string memory newSkillDomain = "AI";
        string memory newNftImageUri = "https://example.com/ai.svg";

        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false, address(vskillUserNft));
        emit SkillDomainsForNftAdded(newSkillDomain, newNftImageUri);
        vskillUserNft._addMoreSkillsForNft(newSkillDomain, newNftImageUri);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           AUDIT PROOF TESTS
    //////////////////////////////////////////////////////////////*/
    function testUserCanMintANonExistentSkillDomain() external {
        vm.prank(USER);
        vskillUserNft.mintUserNft("non-existent-skill-domain");
        uint256 tokenCounter = vskillUserNft.getTokenCounter();
        assertEq(tokenCounter, 1);
    }

    function testInvalidTokenIdWillReturnBlankString() external view {
        string memory skillDomain = vskillUserNft.tokenURI(100);
        assertEq(
            skillDomain,
            "data:application/json;base64,eyJuYW1lIjoiVlNraWxsVXNlck5mdCIsICJkZXNjcmlwdGlvbiI6IlByb29mIG9mIGNhcGFiaWxpdHkgb2YgdGhlIHNraWxsIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInNraWxsIiwgInZhbHVlIjogMTAwfV0sICJpbWFnZSI6IiJ9"
        );
    }
}
