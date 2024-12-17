// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.24;

// import {Test, console} from "lib/forge-std/src/Test.sol";
// import {Staking} from "src/staking/Staking.sol";
// import {DeployStaking} from "script/staking/DeployStaking.s.sol";
// import {PriceConverter} from "src/utils/library/PriceCoverter.sol";
// import {HelperConfig} from "script/staking/HelperConfig.s.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {StructDefinition} from "src/utils/library/StructDefinition.sol";

// contract StakingTest is Test {
//     using PriceConverter for uint256;
//     using StructDefinition for StructDefinition.StakingVerifier;

//     event Staked(address indexed staker, uint256 amount);
//     event Withdrawn(address indexed staker, uint256 amount);
//     event BecomeVerifier(uint256 indexed id, address indexed verifier);
//     event LoseVerifier(address indexed verifier);
//     event BonusMoneyUpdated(
//         uint256 indexed previousAmountInEth,
//         uint256 indexed newAmountInEth
//     );
//     event VerifierStakeUpdated(
//         address indexed verifier,
//         uint256 indexed previousAmountInEth,
//         uint256 indexed newAmountInEth
//     );

//     Staking staking;
//     HelperConfig helperConfig;
//     AggregatorV3Interface priceFeed;
//     uint256 public MIN_ETH_AMOUNT;
//     uint256 public constant INITIAL_BALANCE = 100 ether;
//     uint256 public constant MIN_USD_AMOUNT = 20e18;
//     uint256 private constant INITIAL_REPUTATION = 2;
//     uint256 private immutable LOWEST_REPUTATION = 0;
//     uint256 private immutable HIGHEST_REPUTATION = 10;
//     address public USER = makeAddr("user");

//     function setUp() external {
//         DeployStaking deployer = new DeployStaking();
//         (staking, helperConfig) = deployer.run();
//         priceFeed = AggregatorV3Interface(helperConfig.activeNetworkConfig());
//         MIN_ETH_AMOUNT = MIN_USD_AMOUNT.convertUsdToEth(priceFeed);
//         vm.deal(USER, INITIAL_BALANCE);
//     }

//     ///////////////////////////
//     //     Initial state     //
//     ///////////////////////////

//     function testMinUsdAmountIsTwenty() external view {
//         uint256 minUsdAmount = staking.getMinUsdAmount();
//         assertEq(minUsdAmount, MIN_USD_AMOUNT);
//     }

//     function testInitialReputationIsTwo() external view {
//         uint256 reputation = staking.getInitialReputation();
//         assertEq(reputation, INITIAL_REPUTATION);
//     }

//     function testLowestReputationIsZero() external view {
//         uint256 lowestReputation = staking.getLowestReputation();
//         assertEq(lowestReputation, LOWEST_REPUTATION);
//     }

//     function testHighestReputationIsTen() external view {
//         uint256 highestReputation = staking.getHighestReputation();
//         assertEq(highestReputation, HIGHEST_REPUTATION);
//     }

//     ///////////////////////////
//     //      Constructor      //
//     ///////////////////////////

//     function testIdIsOneAfterDeployment() external view {
//         uint256 id = staking.getLatestId();
//         assertEq(id, 1);
//     }

//     function testVerifierCountIsZeroAfterDeployment() external view {
//         uint256 count = staking.getVerifierCount();
//         assertEq(count, 0);
//     }

//     function testBonusMoneyInEthIsZeroAfterDeployment() external view {
//         uint256 bonus = staking.getBonusMoneyInEth();
//         assertEq(bonus, 0);
//     }

//     ///////////////////////////
//     //        modifier       //
//     ///////////////////////////

//     // modifier to skip tests if not local chain -> Just a simple way to skip tests
//     modifier skipFork() {
//         if (block.chainid != 31337) {
//             return;
//         }
//         _;
//     }

//     ////////////////////////////
//     //      withdrawStake     //
//     ////////////////////////////

//     function testWIthdrawStakeCanOnlyBeCalledByVerifier() external {
//         vm.startPrank(USER);
//         vm.expectRevert(
//             abi.encodeWithSelector(Staking.Staking__NotVerifier.selector)
//         );
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         vm.stopPrank();
//     }

//     function testWithdrawStakeRevertIfNotEnoughBalance() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Staking.Staking__NotEnoughBalanceToWithdraw.selector,
//                 MIN_ETH_AMOUNT
//             )
//         );
//         staking.withdrawStake(2 * MIN_ETH_AMOUNT);
//         vm.stopPrank();
//     }

//     function testWithdrawStakeSuccessUpdatesBalance() external {
//         vm.startPrank(USER);
//         staking.stake{value: 2 * MIN_ETH_AMOUNT}();
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         vm.stopPrank();

//         uint256 balance = staking.getVerifierMoneyStakedInEth(USER);
//         uint256 contractBalance = address(staking).balance;
//         assertEq(balance, MIN_ETH_AMOUNT);
//         assertEq(contractBalance, MIN_ETH_AMOUNT);
//     }

//     function testWithdrawStakeSuccessChecksVerifierStatus() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         vm.stopPrank();

//         uint256 id = staking.getVerifierId(USER);
//         uint256 count = staking.getVerifierCount();
//         assertEq(id, 0);
//         assertEq(count, 0);
//     }

//     function testWithdrawStakeReduceVerifierCountIfSomeoneWithdrawTooMuchToMeetMinUsdAmount()
//         external
//     {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         address anotherUser = makeAddr("anotherUser");
//         vm.deal(anotherUser, INITIAL_BALANCE);
//         vm.startPrank(anotherUser);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         vm.startPrank(USER);
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         vm.stopPrank();

//         uint256 count = staking.getVerifierCount();
//         assertEq(count, 1);
//     }

//     function testWithdrawStakeEmitsWithdrawnEvent() external {
//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.expectEmit(true, false, false, true, address(staking));
//         emit Withdrawn(USER, MIN_ETH_AMOUNT);
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//     }

//     function testWithdrawStakeEmitsVerifierStakeUpdatedEvent() external {
//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.expectEmit(true, true, true, true, address(staking));
//         emit VerifierStakeUpdated(USER, MIN_ETH_AMOUNT, 0);
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//     }

//     function testWithdrawStakeEmitsLoseVerifierEventIfNotEnoughBalance()
//         external
//     {
//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.expectEmit(true, false, false, false, address(staking));
//         emit LoseVerifier(USER);
//         staking.withdrawStake(MIN_ETH_AMOUNT / 2);
//     }

//     function testWithdrawStakeEmitsTwoEventsIfEnoughBalance() external {
//         vm.prank(USER);
//         staking.stake{value: 2 * MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.recordLogs();
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         Vm.Log[] memory entries = vm.getRecordedLogs();

//         bytes32 verifier1 = entries[0].topics[1];
//         bytes32 verifier2 = entries[1].topics[1];
//         assertEq(verifier1, verifier2);
//         assertEq(entries.length, 2);
//     }

//     function testWithdrawStakeEmitsAllEventsIfNotEnoughBalance() external {
//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.recordLogs();
//         staking.withdrawStake(MIN_ETH_AMOUNT / 2);
//         Vm.Log[] memory entries = vm.getRecordedLogs();

//         // topics[0] is the event signature
//         bytes32 verifier1 = entries[0].topics[1];
//         bytes32 verifier2 = entries[1].topics[1];
//         bytes32 verifierThatLost = entries[2].topics[1];
//         assertEq(verifierThatLost, verifier2);
//         assertEq(verifier1, verifier2);
//         assertEq(entries.length, 3);
//     }

//     ////////////////////////////
//     //         stake          //
//     ////////////////////////////

//     function testStakeRevertIfNotEnoughMoneyToBecomeVerifier() external {
//         vm.startPrank(USER);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Staking.Staking__NotEnoughStakeToBecomeVerifier.selector,
//                 MIN_USD_AMOUNT / 2,
//                 MIN_USD_AMOUNT
//             )
//         );
//         staking.stake{value: MIN_ETH_AMOUNT / 2}();
//         vm.stopPrank();
//     }

//     function testStakeSuccessUpdatesVerifiers() external {
//         vm.startPrank(USER);

//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.stopPrank();

//         uint256 id = staking.getVerifierId(USER);
//         uint256 count = staking.getVerifierCount();
//         assertEq(id, 1);
//         assertEq(count, 1);
//     }

//     function testStakeUpdatesBalance() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 balance = staking.getVerifierMoneyStakedInEth(USER);
//         assertEq(balance, MIN_ETH_AMOUNT);

//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 newBalance = staking.getVerifierMoneyStakedInEth(USER);
//         assertEq(newBalance, 2 * MIN_ETH_AMOUNT);
//     }

//     function testStakeSuccessInitializeVerifierIfNewVerifier() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 id = staking.getVerifierId(USER);
//         uint256 reputation = staking.getVerifierReputation(USER);
//         string[] memory skillDomains = staking.getVerifierSkillDomains(USER);
//         uint256 moneyStakedInEth = staking.getVerifierMoneyStakedInEth(USER);
//         address[] memory evidenceSubmitters = staking
//             .getVerifierEvidenceSubmitters(USER);
//         string[] memory evidenceIpfsHash = staking.getVerifierEvidenceIpfsHash(
//             USER
//         );
//         string[] memory feedbackIpfsHash = staking.getVerifierFeedbackIpfsHash(
//             USER
//         );

//         assertEq(id, 1);
//         assertEq(reputation, INITIAL_REPUTATION);
//         assertEq(skillDomains.length, 0);
//         assertEq(moneyStakedInEth, MIN_ETH_AMOUNT);
//         assertEq(evidenceSubmitters.length, 0);
//         assertEq(evidenceIpfsHash.length, 0);
//         assertEq(feedbackIpfsHash.length, 0);
//     }

//     function testStakeEmitsStakedEvent() external {
//         vm.prank(USER);
//         vm.expectEmit(true, false, false, true, address(staking));
//         emit Staked(USER, MIN_ETH_AMOUNT);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//     }

//     function testStakeEmitsBecomeVerifierEventIfNewVerifier() external {
//         vm.prank(USER);
//         vm.expectEmit(true, true, false, false, address(staking));
//         emit BecomeVerifier(1, USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//     }

//     function testStakeEmitsVerifierStakeUpdatedEvent() external {
//         vm.prank(USER);
//         vm.expectEmit(true, true, true, true, address(staking));
//         emit VerifierStakeUpdated(USER, 0, MIN_ETH_AMOUNT);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//     }

//     function testStakeEmitsAllEventsIfNewVerifier() external {
//         vm.prank(USER);
//         vm.recordLogs();
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         bytes32 staker = entries[0].topics[2];
//         bytes32 verifier1 = entries[1].topics[1];
//         bytes32 verifier2 = entries[2].topics[1];
//         assertEq(staker, verifier1);
//         assertEq(verifier1, verifier2);
//         assertEq(entries.length, 3);
//     }

//     function testStakeEmitsTwoEventsOnlyIfAlreadyVerifier() external {
//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();

//         vm.prank(USER);
//         vm.recordLogs();
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         Vm.Log[] memory entries = vm.getRecordedLogs();

//         bytes32 verifier1 = entries[0].topics[1];
//         bytes32 verifier2 = entries[1].topics[1];
//         assertEq(verifier1, verifier2);
//         assertEq(entries.length, 2);
//     }

//     function testStakeDoesNotUpdateVerifierCountAndIdIfAlreadyVerifier()
//         external
//     {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 count = staking.getVerifierCount();
//         assertEq(count, 1);
//         uint256 id = staking.getVerifierId(USER);
//         assertEq(id, 1);

//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT / 2}();
//         vm.stopPrank();

//         uint256 newCount = staking.getVerifierCount();
//         assertEq(newCount, 1);
//         uint256 newId = staking.getVerifierId(USER);
//         assertEq(newId, 1);
//     }

//     ////////////////////////////////////////
//     ////   addBonusMoneyForVerifier   //////
//     ////////////////////////////////////////

//     function testAddBonusMoneyForVerifier() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         staking.addBonusMoneyForVerifier{value: MIN_ETH_AMOUNT}();
//         uint256 bonus = staking.getBonusMoneyInEth();
//         uint256 contractBalance = address(staking).balance;
//         assertEq(bonus, MIN_ETH_AMOUNT);
//         assertEq(contractBalance, MIN_ETH_AMOUNT * 2);
//     }

//     function testAddBonusMoneyForVerifierEmitsBonusMoneyUpdatedEvent()
//         external
//     {
//         vm.prank(USER);
//         vm.expectEmit(true, true, false, true, address(staking));
//         emit BonusMoneyUpdated(0, MIN_ETH_AMOUNT);
//         staking.addBonusMoneyForVerifier{value: MIN_ETH_AMOUNT}();
//     }

//     /////////////////////////////////
//     //     addressToMoneyStaked    //
//     /////////////////////////////////

//     function testMultipleUsersCanTrackTheirMoneyStaked() external {
//         for (uint160 i = 1; i < 10; i++) {
//             address user = address(i);
//             // vm.deal(user, INITIAL_BALANCE);
//             // vm.startPrank(user);
//             // staking.stake{value: MIN_ETH_AMOUNT}();
//             // vm.stopPrank();
//             hoax(user, INITIAL_BALANCE);
//             staking.stake{value: MIN_ETH_AMOUNT}();
//             uint256 balance = staking.getVerifierMoneyStakedInEth(user);
//             assertEq(balance, MIN_ETH_AMOUNT);
//         }
//     }

//     /////////////////////////////////
//     //        verifierToId         //
//     /////////////////////////////////

//     function testUsersCanTrackTheirVerifierId() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 id = staking.getVerifierId(USER);
//         assertEq(id, 1);

//         vm.prank(USER);
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//         vm.stopPrank();

//         uint256 newId = staking.getVerifierId(USER);
//         assertEq(newId, 0);

//         vm.prank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 anotherId = staking.getVerifierId(USER);
//         assertEq(anotherId, 2);
//     }

//     //////////////////////
//     ///     Getter     ///
//     //////////////////////

//     function testGetVerifier() external {
//         vm.startPrank(USER);
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         StructDefinition.StakingVerifier memory v = staking.getVerifier(USER);
//         assertEq(v.id, 1);
//         assertEq(v.verifierAddress, USER);
//         assertEq(v.reputation, INITIAL_REPUTATION);
//         assertEq(v.skillDomains.length, 0);
//         assertEq(v.moneyStakedInEth, MIN_ETH_AMOUNT);
//         assertEq(v.evidenceSubmitters.length, 0);
//         assertEq(v.evidenceIpfsHash.length, 0);
//         assertEq(v.feedbackIpfsHash.length, 0);
//     }

//     /*//////////////////////////////////////////////////////////////
//                            AUDIT PROOF TESTS
//     //////////////////////////////////////////////////////////////*/

//     function testVerifierCanDrainTheProtocolByReenterWithdrawStakeFunction()
//         external
//     {
//         vm.startPrank(USER);
//         staking.stake{value: 2 * MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         MaliciousUser attacker = new MaliciousUser(staking);
//         address attackUser = makeAddr("attackUser");
//         vm.deal(attackUser, MIN_ETH_AMOUNT);

//         uint256 balanceBefore = address(staking).balance;
//         uint256 balanceBeforeAttacker = address(attacker).balance;
//         console.log("Balance before attack: ", balanceBefore);
//         console.log("Attacker balance before attack: ", balanceBeforeAttacker);

//         vm.expectRevert();
//         vm.startPrank(attackUser);
//         attacker.hack{value: MIN_ETH_AMOUNT}();
//         vm.stopPrank();

//         uint256 balanceAfter = address(staking).balance;
//         uint256 balanceAfterAttacker = address(attacker).balance;
//         console.log("Balance after attack: ", balanceAfter);
//         console.log("Attacker balance after attack: ", balanceAfterAttacker);
//     }
// }

// contract MaliciousUser {
//     using PriceConverter for uint256;

//     Staking staking;
//     // Only works on anvil local chain, since we know the price is 2000 USD per ETH
//     uint256 MIN_ETH_AMOUNT = 1e16;

//     constructor(Staking _stakingContract) {
//         staking = _stakingContract;
//     }

//     function hack() external payable {
//         staking.stake{value: MIN_ETH_AMOUNT}();
//         staking.withdrawStake(MIN_ETH_AMOUNT);
//     }

//     receive() external payable {
//         if (address(staking).balance >= MIN_ETH_AMOUNT) {
//             staking.withdrawStake(MIN_ETH_AMOUNT);
//         }
//     }
// }
