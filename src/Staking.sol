// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {StructDefinition} from "src/library/StructDefinition.sol";

contract Staking {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Staking__NotEnoughBalanceToWithdraw(uint256 currentStakeEthAmount);
    error Staking__NotCorrectStakeAmount();
    error Staking__WithdrawFailed();
    error Staking__NotVerifier();
    error Staking__AlreadyVerifier();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant STAKE_ETH_AMOUNT = 0.1 ether; // 0.1 ether staking amount
    uint256 private constant INITIAL_REPUTATION = 2;
    // uint256 private constant LOWEST_REPUTATION = 0;
    // uint256 private constant HIGHEST_REPUTATION = 10;

    uint256 private s_verifierCount;
    mapping(address verifier => StructDefinition.VerifierInfo verifierInformation)
        internal s_verifierToInfo;
    mapping(address verifier => bool isVerifier) internal s_addressToIsVerifier;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Withdrawn(address indexed staker, uint256 amount);
    event StakeSuccess(address indexed staker);
    event LoseVerifier(address indexed verifier);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVerifier() {
        if (!s_addressToIsVerifier[msg.sender]) {
            revert Staking__NotVerifier();
        }
        _;
    }

    modifier onlyNonVerifier() {
        if (s_addressToIsVerifier[msg.sender]) {
            revert Staking__AlreadyVerifier();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
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
    // The actual become verifier function will be in the Verifier contract
    // This only handles the stake
    function stake() public payable onlyNonVerifier {
        if (msg.value != STAKE_ETH_AMOUNT) {
            revert Staking__NotCorrectStakeAmount();
        }

        s_verifierCount += 1;
        s_addressToIsVerifier[msg.sender] = true;
        s_verifierToInfo[msg.sender] = StructDefinition.VerifierInfo(
            INITIAL_REPUTATION,
            new string[](0)
        );

        emit StakeSuccess(msg.sender);
    }

    // This function will withdraw all the stake and remove the verifier
    function withdrawStake() public onlyVerifier {
        (bool success, ) = msg.sender.call{value: STAKE_ETH_AMOUNT}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        s_verifierCount -= 1;
        s_addressToIsVerifier[msg.sender] = false;
        delete s_verifierToInfo[msg.sender];

        emit LoseVerifier(msg.sender);
        emit Withdrawn(msg.sender, STAKE_ETH_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getStakeEthAmount() external pure returns (uint256) {
        return STAKE_ETH_AMOUNT;
    }

    function getVerifierCount() external view returns (uint256) {
        return s_verifierCount;
    }

    function getInitialReputation() external pure returns (uint256) {
        return INITIAL_REPUTATION;
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
