// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../utils/library/PriceCoverter.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

contract Staking {
    using PriceConverter for uint256;
    using StructDefinition for StructDefinition.StakingVerifier;

    error Staking__NotEnoughBalanceToWithdraw(uint256 currentStakeEthAmount);
    error Staking__NotEnoughStakeToBecomeVerifier(
        uint256 currentStakeUsdAmount,
        uint256 minStakeUsdAmount
    );
    error Staking__WithdrawFailed();
    error Staking__NotVerifier();
    error Staking__AlreadyVerifier();

    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private immutable LOWEST_REPUTATION = 0;
    uint256 private immutable HIGHEST_REPUTATION = 10;
    uint256 private id; // If id is 0, then the address is not a verifier
    uint256 private verifierCount;
    uint256 private bonusMoneyInEth;

    AggregatorV3Interface internal priceFeed;
    mapping(address => uint256) internal addressToId;
    StructDefinition.StakingVerifier[] internal verifiers;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event BecomeVerifier(uint256 indexed id, address indexed verifier);
    event LoseVerifier(address indexed verifier);
    event BonusMoneyUpdated(
        uint256 indexed previousAmountInEth,
        uint256 indexed newAmountInEth
    );
    event VerifierStakeUpdated(
        address indexed verifier,
        uint256 indexed previousAmountInEth,
        uint256 indexed newAmountInEth
    );

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        id = 1;
        verifierCount = 0;
        bonusMoneyInEth = 0;
    }

    receive() external payable {
        stake();
    }

    fallback() external payable {
        stake();
    }

    function withdrawStake(uint256 amountToWithdrawInEth) public virtual {
        if (addressToId[msg.sender] == 0) {
            revert Staking__NotVerifier();
        }

        if (
            verifiers[addressToId[msg.sender] - 1].moneyStakedInEth <
            amountToWithdrawInEth
        ) {
            revert Staking__NotEnoughBalanceToWithdraw(
                verifiers[addressToId[msg.sender] - 1].moneyStakedInEth
            );
        }

        (bool success, ) = msg.sender.call{value: amountToWithdrawInEth}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        verifiers[addressToId[msg.sender] - 1]
            .moneyStakedInEth -= amountToWithdrawInEth;
        emit Withdrawn(msg.sender, amountToWithdrawInEth);
        emit VerifierStakeUpdated(
            msg.sender,
            verifiers[addressToId[msg.sender] - 1].moneyStakedInEth +
                amountToWithdrawInEth,
            verifiers[addressToId[msg.sender] - 1].moneyStakedInEth
        );

        if (
            !_currentStakedAmountIsStillAboveMinUsdAmount(
                verifiers[addressToId[msg.sender] - 1].moneyStakedInEth
            )
        ) {
            // Remove the verifier from the array
            _removeVerifier(msg.sender);
        }
    }

    function stake() public payable virtual {
        uint256 amountInUsd = msg.value.convertEthToUsd(priceFeed);

        if (addressToId[msg.sender] == 0) {
            if (amountInUsd < MIN_USD_AMOUNT) {
                revert Staking__NotEnoughStakeToBecomeVerifier(
                    amountInUsd,
                    MIN_USD_AMOUNT
                );
            } else {
                addressToId[msg.sender] = id;
                verifierCount++;
                verifiers.push(
                    _initializeVerifier(msg.sender, new string[](0))
                );
                emit BecomeVerifier(id, msg.sender);
                id++;

                // Since it's new verifier, the way we find the index is by using the length of the array
                verifiers[verifiers.length - 1].moneyStakedInEth += msg.value;
                emit Staked(msg.sender, msg.value);
                emit VerifierStakeUpdated(
                    msg.sender,
                    0,
                    verifiers[verifiers.length - 1].moneyStakedInEth
                );
            }
        } else {
            verifiers[addressToId[msg.sender] - 1].moneyStakedInEth += msg
                .value;
            emit Staked(msg.sender, msg.value);
            emit VerifierStakeUpdated(
                msg.sender,
                verifiers[addressToId[msg.sender] - 1].moneyStakedInEth -
                    msg.value,
                verifiers[addressToId[msg.sender] - 1].moneyStakedInEth
            );
        }
    }

    // This function for anyone who willing to add bonus money to the contract
    function addBonusMoneyForVerifier() public payable {
        bonusMoneyInEth += msg.value;
        emit BonusMoneyUpdated(bonusMoneyInEth - msg.value, bonusMoneyInEth);
    }

    /////////////////////////////////
    /////   Internal Functions   ////
    /////////////////////////////////

    function _addBonusMoney(uint256 amountInEth) internal {
        bonusMoneyInEth += amountInEth;
        emit BonusMoneyUpdated(bonusMoneyInEth - amountInEth, bonusMoneyInEth);
    }

    function _rewardVerifierInFormOfStake(
        address verifierAddress,
        uint256 amountInEth
    ) internal {
        verifiers[addressToId[verifierAddress] - 1]
            .moneyStakedInEth += amountInEth;
        bonusMoneyInEth -= amountInEth;

        emit BonusMoneyUpdated(bonusMoneyInEth + amountInEth, bonusMoneyInEth);
        emit VerifierStakeUpdated(
            verifierAddress,
            verifiers[addressToId[verifierAddress] - 1].moneyStakedInEth -
                amountInEth,
            verifiers[addressToId[verifierAddress] - 1].moneyStakedInEth
        );
    }

    function _penalizeVerifierStakeToBonusMoney(uint256 amountInEth) internal {
        bonusMoneyInEth += amountInEth;
        emit BonusMoneyUpdated(bonusMoneyInEth - amountInEth, bonusMoneyInEth);
    }

    function _removeVerifier(address verifierAddress) internal {
        uint256 index = addressToId[verifierAddress] - 1;
        verifiers[index] = verifiers[verifierCount - 1];
        verifiers.pop();

        addressToId[verifierAddress] = 0;
        verifierCount--;

        emit LoseVerifier(verifierAddress);
    }

    function _initializeVerifier(
        address verifierAddress,
        string[] memory skillDomains
    ) internal view returns (StructDefinition.StakingVerifier memory) {
        return
            StructDefinition.StakingVerifier({
                id: id,
                verifierAddress: verifierAddress,
                reputation: INITIAL_REPUTATION,
                skillDomains: skillDomains,
                moneyStakedInEth: 0,
                evidenceSubmitters: new address[](0),
                evidenceIpfsHash: new string[](0),
                feedbackIpfsHash: new string[](0)
            });
    }

    function _currentStakedAmountIsStillAboveMinUsdAmount(
        uint256 currentStakedAmountInEth
    ) internal view returns (bool) {
        return
            currentStakedAmountInEth.convertEthToUsd(priceFeed) >=
            MIN_USD_AMOUNT;
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getMinUsdAmount() external pure returns (uint256) {
        return MIN_USD_AMOUNT;
    }

    function getLatestId() external view returns (uint256) {
        return id;
    }

    function getVerifierCount() external view returns (uint256) {
        return verifierCount;
    }

    function getVerifierId(
        address verifierAddress
    ) external view returns (uint256) {
        return addressToId[verifierAddress];
    }

    function getVerifierReputation(
        address verifierAddress
    ) external view returns (uint256) {
        return verifiers[addressToId[verifierAddress] - 1].reputation;
    }

    function getVerifierSkillDomains(
        address verifierAddress
    ) external view returns (string[] memory) {
        return verifiers[addressToId[verifierAddress] - 1].skillDomains;
    }

    function getVerifierMoneyStakedInEth(
        address verifierAddress
    ) external view returns (uint256) {
        return verifiers[addressToId[verifierAddress] - 1].moneyStakedInEth;
    }

    function getVerifierEvidenceSubmitters(
        address verifierAddress
    ) external view returns (address[] memory) {
        return verifiers[addressToId[verifierAddress] - 1].evidenceSubmitters;
    }

    function getVerifierEvidenceIpfsHash(
        address verifierAddress
    ) external view returns (string[] memory) {
        return verifiers[addressToId[verifierAddress] - 1].evidenceIpfsHash;
    }

    function getVerifierFeedbackIpfsHash(
        address verifierAddress
    ) external view returns (string[] memory) {
        return verifiers[addressToId[verifierAddress] - 1].feedbackIpfsHash;
    }

    function getInitialReputation() external pure returns (uint256) {
        return INITIAL_REPUTATION;
    }

    function getLowestReputation() external pure returns (uint256) {
        return LOWEST_REPUTATION;
    }

    function getHighestReputation() external pure returns (uint256) {
        return HIGHEST_REPUTATION;
    }

    function getVerifier(
        address verifierAddress
    ) external view returns (StructDefinition.StakingVerifier memory) {
        return verifiers[addressToId[verifierAddress] - 1];
    }

    function getVerifierById(
        uint256 _id
    ) external view returns (StructDefinition.StakingVerifier memory) {
        return verifiers[_id - 1];
    }

    function getBonusMoneyInEth() public view returns (uint256) {
        return bonusMoneyInEth;
    }

    function getLatestEvidenceSubmitter(
        address verifierAddress
    ) external view returns (address) {
        return
            verifiers[addressToId[verifierAddress] - 1].evidenceSubmitters[
                verifiers[addressToId[verifierAddress] - 1]
                    .evidenceSubmitters
                    .length - 1
            ];
    }

    function getLatestEvidenceIpfsHash(
        address verifierAddress
    ) external view returns (string memory) {
        return
            verifiers[addressToId[verifierAddress] - 1].evidenceIpfsHash[
                verifiers[addressToId[verifierAddress] - 1]
                    .evidenceIpfsHash
                    .length - 1
            ];
    }
}
