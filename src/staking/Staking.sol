// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../utils/library/PriceCoverter.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

contract Staking {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Staking__NotEnoughBalanceToWithdraw(uint256 currentStakeEthAmount);
    error Staking__NotEnoughStakeToBecomeVerifier();
    error Staking__WithdrawFailed();
    error Staking__NotVerifier();

    using PriceConverter for uint256;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    uint256 private constant INITIAL_REPUTATION = 2;
    // uint256 private constant LOWEST_REPUTATION = 0;
    // uint256 private constant HIGHEST_REPUTATION = 10;

    uint256 private s_verifierCount;
    AggregatorV3Interface immutable i_priceFeed;
    mapping(address verifier => StructDefinition.VerifierInfo verifierInformation)
        internal s_verifierToInfo;
    mapping(address verifier => bool isVerifier) internal s_addressToIsVerifier;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Withdrawn(address indexed staker, uint256 amount);
    event BecomeVerifier(address indexed verifier);
    event LoseVerifier(address indexed verifier);
    event VerifierStakeUpdated(
        address indexed verifier,
        uint256 indexed newAmountInEth
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVerifier() {
        if (!s_addressToIsVerifier[msg.sender]) {
            revert Staking__NotVerifier();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _priceFeed) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        s_verifierCount = 0;
    }

    receive() external payable {
        stake();
    }

    fallback() external payable {
        stake();
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @update we will transfer the stake to Relayer contract and let the Relayer contract handle the stake
    function stake() public payable {
        if (s_addressToIsVerifier[msg.sender]) {
            _verifierStake(msg.sender, msg.value);
        } else {
            _nonVerifierStake(msg.sender, msg.value);
        }
    }

    // This function will withdraw all the stake except the minimum stake required to be a verifier
    function withdrawStake() public onlyVerifier {
        uint256 currentStakeInEth = s_verifierToInfo[msg.sender]
            .moneyStakedInEth;
        uint256 amountToWithdrawInEth = currentStakeInEth -
            MIN_USD_AMOUNT.convertUsdToEth(i_priceFeed);

        // This can happen if the value of eth is too low
        if (amountToWithdrawInEth <= 0) {
            revert Staking__NotEnoughBalanceToWithdraw(currentStakeInEth);
        }

        s_verifierToInfo[msg.sender].moneyStakedInEth -= amountToWithdrawInEth;

        (bool success, ) = msg.sender.call{value: amountToWithdrawInEth}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit Withdrawn(msg.sender, amountToWithdrawInEth);
    }

    // This function will withdraw all the stake and remove the verifier
    function withdrawStakeAndLoseVerifier() public onlyVerifier {
        uint256 currentStakeInEth = s_verifierToInfo[msg.sender]
            .moneyStakedInEth;

        s_verifierToInfo[msg.sender].moneyStakedInEth = 0;
        s_addressToIsVerifier[msg.sender] = false;
        s_verifierCount--;

        (bool success, ) = msg.sender.call{value: currentStakeInEth}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit Withdrawn(msg.sender, currentStakeInEth);
        emit LoseVerifier(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _verifierStake(address verifier, uint256 amountInEth) internal {
        s_verifierToInfo[verifier].moneyStakedInEth += amountInEth;

        emit VerifierStakeUpdated(
            verifier,
            s_verifierToInfo[verifier].moneyStakedInEth
        );
    }

    function _nonVerifierStake(address user, uint256 amountInEth) internal {
        uint256 amountInUsd = amountInEth.convertEthToUsd(i_priceFeed);
        if (amountInUsd < MIN_USD_AMOUNT) {
            revert Staking__NotEnoughStakeToBecomeVerifier();
        }

        s_addressToIsVerifier[user] = true;
        s_verifierToInfo[user] = StructDefinition.VerifierInfo({
            reputation: INITIAL_REPUTATION,
            skillDomains: new string[](0),
            moneyStakedInEth: amountInEth
        });
        s_verifierCount++;

        emit BecomeVerifier(user);
        emit VerifierStakeUpdated(user, amountInEth);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMinUsdAmount() external pure returns (uint256) {
        return MIN_USD_AMOUNT;
    }

    function getVerifierCount() external view returns (uint256) {
        return s_verifierCount;
    }

    function getInitialReputation() external pure returns (uint256) {
        return INITIAL_REPUTATION;
    }

    function getPriceFeed() external view returns (AggregatorV3Interface) {
        return i_priceFeed;
    }

    function getVerifierInfo(
        address verifier
    ) external view returns (StructDefinition.VerifierInfo memory) {
        return s_verifierToInfo[verifier];
    }
}

// This will be in the Relayer contract
// function addBonusMoneyForVerifier() public payable {
//     s_bonusMoneyInEth += msg.value;
//     emit BonusMoneyUpdated(
//         s_bonusMoneyInEth - msg.value,
//         s_bonusMoneyInEth
//     );
// }

// This will be in the Relayer contract
// function _rewardVerifierInFormOfStake(
//     address verifierAddress,
//     uint256 amountInEth
// ) internal {
//     s_verifiers[s_addressToId[verifierAddress] - 1]
//         .moneyStakedInEth += amountInEth;
//     s_bonusMoneyInEth -= amountInEth;
//     emit BonusMoneyUpdated(
//         s_bonusMoneyInEth + amountInEth,
//         s_bonusMoneyInEth
//     );
//     emit VerifierStakeUpdated(
//         verifierAddress,
//         s_verifiers[s_addressToId[verifierAddress] - 1].moneyStakedInEth -
//             amountInEth,
//         s_verifiers[s_addressToId[verifierAddress] - 1].moneyStakedInEth
//     );
// }

// This will be in the Relayer contract
// function _penalizeVerifierStakeToBonusMoney(
//     address verifierAddress,
//     uint256 amountInEth
// ) internal {
//     moneyStakedInEth is uint256, so it can't be negative
//     This function will revert if the amountInEth is greater than the current stake...
//     Is this revert a issue? If the amountInEth is greater than the current stake, it will revert, and the verifier is not penalized....?
//     if the amountInEth is greater than the current stake, the function will revert, and the verifier is not penalized
//     This function only be called by the Verifier contract, so the amountInEth is always valid, not an issue
//     s_verifiers[s_addressToId[verifierAddress] - 1]
//         .moneyStakedInEth -= amountInEth;
//     s_bonusMoneyInEth += amountInEth;
//     uint256 currentStake = s_verifiers[s_addressToId[verifierAddress] - 1]
//         .moneyStakedInEth;
//     emit BonusMoneyUpdated(
//         s_bonusMoneyInEth - amountInEth,
//         s_bonusMoneyInEth
//     );
//     emit VerifierStakeUpdated(
//         verifierAddress,
//         s_verifiers[s_addressToId[verifierAddress] - 1].moneyStakedInEth +
//             amountInEth,
//         s_verifiers[s_addressToId[verifierAddress] - 1].moneyStakedInEth
//     );
//     if (!_currentStakedAmountIsStillAboveMinUsdAmount(currentStake)) {
//         _removeVerifier(verifierAddress);
//     }
// }
