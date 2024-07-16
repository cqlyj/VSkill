// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Staking} from "src/staking/Staking.sol";
import {DeployStaking} from "script/staking/DeployStaking.s.sol";
import {PriceConverter} from "src/utils/PriceCoverter.sol";
import {HelperConfig} from "script/staking/HelperConfig.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Vm} from "forge-std/Vm.sol";

contract StakingTest is Test {
    using PriceConverter for uint256;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event BecomeVerifier(uint256 indexed id, address indexed verifier);
    event LoseVerifier(address indexed verifier);

    Staking staking;
    HelperConfig helperConfig;
    AggregatorV3Interface priceFeed;
    uint256 public constant MIN_ETH_AMOUNT = 0.01 ether; // 0.01 * 2000 = 20 USD
    uint256 public constant INITIAL_BALANCE = 100 ether;
    address public USER = makeAddr("user");

    function setUp() external {
        DeployStaking deployer = new DeployStaking();
        (staking, helperConfig) = deployer.run();
        priceFeed = AggregatorV3Interface(helperConfig.activeNetworkConfig());
        vm.deal(USER, INITIAL_BALANCE);
    }

    // Initial state

    function testMinUsdAmountIsTwenty() external view {
        uint256 minUsdAmount = staking.getMinUsdAmount();
        assertEq(minUsdAmount, 20e18);
    }

    // Constructor

    function testIdIsOneAfterDeployment() external view {
        uint256 id = staking.getLatestId();
        assertEq(id, 1);
    }

    function testVerifierCountIsZeroAfterDeployment() external view {
        uint256 count = staking.getVerifierCount();
        assertEq(count, 0);
    }

    // stakeToBeTheVerifier

    function testStakeToBeTheVerifierRevertIfNotEnoughUsd() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Staking.Staking__NotEnoughMoneyStaked.selector,
                MIN_ETH_AMOUNT.convertEthToUsd(priceFeed),
                0
            )
        );
        staking.stakeToBeTheVerifier();
    }

    function testStakeToBeTheVerifierOnlyIfEnoughUsd() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_ETH_AMOUNT);
    }

    function testSakeToBeTheVerifierSuccessUpdatesVerifier() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 1);
    }

    function testStakeToBeTheVerifierOnlyCanBeCalledIfNotVerifier() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.expectRevert(Staking.Staking__AlreadyVerifier.selector);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();
    }

    function testStakeToBeTheVerifierSuccessAndIdIncreament() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        address anotherUser = makeAddr("anotherUser");
        vm.deal(anotherUser, INITIAL_BALANCE);
        vm.startPrank(anotherUser);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(anotherUser);
        console.log("id", id);
        assertEq(id, 2);

        uint256 latestId = staking.getLatestId();
        assertEq(latestId, 3);
    }

    function testStakeToBeTheVerifierEmitsStakedEvent() external {
        vm.prank(USER);
        vm.expectEmit(true, false, false, true, address(staking));
        emit Staked(USER, MIN_ETH_AMOUNT);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
    }

    function testStakeToBeTheVerifierEmitsBecomeVerifierEvent() external {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(staking));
        emit BecomeVerifier(1, USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
    }

    function testStakeToBeTheVerifierEmitsBothEvents() external {
        vm.prank(USER);
        vm.recordLogs();
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 staker = entries[0].topics[1];
        bytes32 verifier = entries[1].topics[2];
        assertEq(staker, verifier);
        assertEq(entries.length, 2);
    }

    // withdrawStake

    function testWithdrawStakeRevertIfNotEnoughBalance() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Staking.Staking__NotEnoughBalanceToWithdraw.selector,
                0
            )
        );
        staking.withdrawStake(MIN_ETH_AMOUNT);
    }

    function testWithdrawStakeSuccessUpdatesBalance() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        staking.withdrawStake(MIN_ETH_AMOUNT / 2);
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_ETH_AMOUNT / 2);
    }

    function testWithdrawStakeSuccessChecksVerifierStatus() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        staking.withdrawStake(MIN_ETH_AMOUNT);
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 0);
    }

    function testWithdrawStakeReduceVerifierCountIfSomeoneWithdrawTooMuchToMeetMinUsdAmount()
        external
    {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        address anotherUser = makeAddr("anotherUser");
        vm.deal(anotherUser, INITIAL_BALANCE);
        vm.startPrank(anotherUser);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        vm.startPrank(USER);
        staking.withdrawStake(MIN_ETH_AMOUNT);
        vm.stopPrank();

        uint256 count = staking.getVerifierCount();
        assertEq(count, 1);
    }

    function testWithdrawStakeEmitsWithdrawnEvent() external {
        vm.prank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();

        vm.prank(USER);
        vm.expectEmit(true, false, false, true, address(staking));
        emit Withdrawn(USER, MIN_ETH_AMOUNT);
        staking.withdrawStake(MIN_ETH_AMOUNT);
    }

    function testWithdrawStakeEmitsLoseVerifierEventIfNotEnoughBalance()
        external
    {
        vm.prank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();

        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(staking));
        emit LoseVerifier(USER);
        staking.withdrawStake(MIN_ETH_AMOUNT / 2);
    }

    function testWithdrawStakeEmitsBothEventsIfNotEnoughBalance() external {
        vm.prank(USER);
        staking.stakeToBeTheVerifier{value: MIN_ETH_AMOUNT}();

        vm.prank(USER);
        vm.recordLogs();
        staking.withdrawStake(MIN_ETH_AMOUNT / 2);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 staker = entries[0].topics[1];
        bytes32 verifier = entries[1].topics[1];
        assertEq(staker, verifier);
        assertEq(entries.length, 2);
    }

    // stake

    function testStakeUpdatesBalance() external {
        vm.startPrank(USER);
        staking.stake{value: MIN_ETH_AMOUNT / 2}();
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_ETH_AMOUNT / 2);
    }

    function testStakeCheckVerifierStatus() external {
        vm.startPrank(USER);
        staking.stake{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 1);
        assertEq(staking.getVerifierCount(), 1);
    }

    function testStakeEmitsStakedEvent() external {
        vm.prank(USER);
        vm.expectEmit(true, false, false, true, address(staking));
        emit Staked(USER, MIN_ETH_AMOUNT / 2);
        staking.stake{value: MIN_ETH_AMOUNT / 2}();
    }

    function testStakeEmitsBecomeVerifierEventIfEnoughBalance() external {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(staking));
        emit BecomeVerifier(1, USER);
        staking.stake{value: MIN_ETH_AMOUNT}();
    }

    function testStakeEmitsOnlyStakedEventIfNotEnoughBalance() external {
        vm.prank(USER);
        vm.recordLogs();
        staking.stake{value: MIN_ETH_AMOUNT / 2}();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1);
    }

    function testStakeEmitsBothEventsIfEnoughBalance() external {
        vm.prank(USER);
        vm.recordLogs();
        staking.stake{value: MIN_ETH_AMOUNT}();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 staker = entries[0].topics[1];
        bytes32 verifier = entries[1].topics[2];
        assertEq(staker, verifier);
        assertEq(entries.length, 2);
    }

    // addressToMoneyStaked

    function testMultipleUsersCanTrackTheirMoneyStaked() external {
        for (uint160 i = 1; i < 10; i++) {
            address user = address(i);
            // vm.deal(user, INITIAL_BALANCE);
            // vm.startPrank(user);
            // staking.stake{value: MIN_ETH_AMOUNT}();
            // vm.stopPrank();
            hoax(user, INITIAL_BALANCE);
            staking.stake{value: MIN_ETH_AMOUNT}();
            uint256 balance = staking.getMoneyStaked(user);
            assertEq(balance, MIN_ETH_AMOUNT);
        }
    }

    // verifierToId

    function testUsersCanTrackTheirVerifierId() external {
        vm.startPrank(USER);
        staking.stake{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 1);

        vm.prank(USER);
        staking.withdrawStake(MIN_ETH_AMOUNT);
        vm.stopPrank();

        uint256 newId = staking.getVerifierId(USER);
        assertEq(newId, 0);

        vm.prank(USER);
        staking.stake{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 anotherId = staking.getVerifierId(USER);
        assertEq(anotherId, 2);
    }
}
