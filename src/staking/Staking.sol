// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../utils/library/PriceCoverter.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

/**
 * @title Staking contract for verifiers and for anyone who vunlunteer to add more bonus money to the contract
 * @author Luo Yingjie
 * @notice This contract is used to stake money and withdraw money for verifiers, also for anyone who willing to add bonus money to the contract to incentivize verifiers
 * @dev This is base contract for verifier contract, it contains all the basic functions for staking and withdrawing money
 */
contract Staking {
    error Staking__NotEnoughBalanceToWithdraw(uint256 currentStakeEthAmount);
    error Staking__NotEnoughStakeToBecomeVerifier(
        uint256 currentStakeUsdAmount,
        uint256 minStakeUsdAmount
    );
    error Staking__WithdrawFailed();
    error Staking__NotVerifier();
    error Staking__AlreadyVerifier();

    /**
     * @dev PriceConverter is used to convert the amount of money from USD to ETH and vice versa
     */
    using PriceConverter for uint256;
    /**
     * @dev StructDefinition is used to define the structure of the various complex data types in contracts
     */
    using StructDefinition for StructDefinition.StakingVerifier;

    /**
     * @dev MIN_USD_AMOUNT is the minimum amount of money that a verifier needs to stake in order to become a verifier
     * @dev INITIAL_REPUTATION is the initial reputation of a verifier when they first become a verifier
     * @dev LOWEST_REPUTATION is the lowest reputation that a verifier can have, if lower than this, the verifier will be removed from the array
     * @dev HIGHEST_REPUTATION is the highest reputation that a verifier can have
     */
    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private immutable LOWEST_REPUTATION = 0;
    uint256 private immutable HIGHEST_REPUTATION = 10;

    /**
     * @dev id is used to identify the verifier. If id is 0, then the address is not a verifier
     * @dev verifierCount is used to count the number of verifiers
     * @dev bonusMoneyInEth is the amount of bonus money that is added to the contract
     */
    uint256 private id;
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

    /**
     *
     * @param amountToWithdrawInEth The amount of money that the verifier wants to withdraw
     * @notice This function is used to withdraw the money that the verifier has staked
     * @dev If the verifier is not a verifier, then the function will revert
     * @dev If the verifier does not have enough balance to withdraw, then the function will revert
     * @dev If the withdrawal fails, then the function will revert
     * @dev If the current staked amount after withdraw is not above the minimum USD amount, then the verifier will be removed from the array
     * @dev This function emits Withdrawn and VerifierStakeUpdated events once the withdrawal is successful
     */
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

    /**
     * @notice This function is used to stake money to become a verifier
     * @dev If the verifier has already staked money, then the money will be added to the current staked amount
     * @dev If the new verifier does not have enough money to become a verifier, then the function will revert
     * @dev If the new verifier has enough money to become a verifier, then the verifier will be initialized and added to the array
     * @dev This function emits Staked, BecomeVerifier, and VerifierStakeUpdated events once the staking is successful for new verifier
     * @dev This function emits Staked and VerifierStakeUpdated events once the staking is successful for existing verifier
     */
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

    /**
     * @notice This function is used to add more bonus in the reward pool for verifiers, to incentivize them
     * @dev This function emits BonusMoneyUpdated event once the bonus money is added
     */
    function addBonusMoneyForVerifier() public payable {
        bonusMoneyInEth += msg.value;
        emit BonusMoneyUpdated(bonusMoneyInEth - msg.value, bonusMoneyInEth);
    }

    /////////////////////////////////
    /////   Internal Functions   ////
    /////////////////////////////////

    /**
     *
     * @param amountInEth The amount of money in ETH that the verifier wants to add to the bonus money
     * @notice This function is used to add bonus money to the reward pool for verifiers
     * @dev This function emits BonusMoneyUpdated event once the bonus money is added
     */
    function _addBonusMoney(uint256 amountInEth) internal {
        bonusMoneyInEth += amountInEth;
        emit BonusMoneyUpdated(bonusMoneyInEth - amountInEth, bonusMoneyInEth);
    }

    /**
     *
     * @param verifierAddress The address of the verifier that will be rewarded
     * @param amountInEth The amount of money in ETH that the verifier will be rewarded
     * @notice This function is used to reward the verifier in the form of stake
     * @dev This function will just update the bonusMoneyInEth of the verifier, to get the reward, the verifier needs to withdraw the money => pull over push
     * @dev This function emits BonusMoneyUpdated and VerifierStakeUpdated events once the verifier is rewarded
     */
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

    /**
     *
     * @param verifierAddress The address of the verifier that will be penalized
     * @param amountInEth The amount of money in ETH that the verifier will be penalized
     * @notice This function is used to penalize the verifier in the form of bonus money
     * @dev This function will just update the bonusMoneyInEth of the verifier, to get the penalty, the verifier needs to withdraw the money => pull over push
     * @dev If the current staked amount after penalize is not above the minimum USD amount, then the verifier will be removed from the array
     * @dev This function emits BonusMoneyUpdated and VerifierStakeUpdated events once the verifier is penalized
     */
    function _penalizeVerifierStakeToBonusMoney(
        address verifierAddress,
        uint256 amountInEth
    ) internal {
        verifiers[addressToId[verifierAddress] - 1]
            .moneyStakedInEth -= amountInEth;
        bonusMoneyInEth += amountInEth;
        uint256 currentStake = verifiers[addressToId[verifierAddress] - 1]
            .moneyStakedInEth;
        emit BonusMoneyUpdated(bonusMoneyInEth - amountInEth, bonusMoneyInEth);
        emit VerifierStakeUpdated(
            verifierAddress,
            verifiers[addressToId[verifierAddress] - 1].moneyStakedInEth +
                amountInEth,
            verifiers[addressToId[verifierAddress] - 1].moneyStakedInEth
        );
        if (!_currentStakedAmountIsStillAboveMinUsdAmount(currentStake)) {
            _removeVerifier(verifierAddress);
        }
    }

    /**
     *
     * @param verifierAddress The address of the verifier that will be removed
     * @notice This function is used to remove the verifier from the array
     * @dev This function will remove the verifier from the array and update the addressToId mapping and verifierCount
     * @dev This function emits LoseVerifier event once the verifier is removed
     */
    function _removeVerifier(address verifierAddress) internal {
        uint256 index = addressToId[verifierAddress] - 1;
        verifiers[index] = verifiers[verifierCount - 1];
        verifiers.pop();

        addressToId[verifierAddress] = 0;
        verifierCount--;

        emit LoseVerifier(verifierAddress);
    }

    /**
     *
     * @param verifierAddress The address of who will be initialized as a verifier
     * @param skillDomains The skill domains of the verifier is good at
     * @return StructDefinition.StakingVerifier The verifier that has been initialized
     */
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

    /**
     *
     * @param currentStakedAmountInEth The current staked amount in ETH of the verifier
     * @return bool Whether the current staked amount is still above the minimum USD amount
     * @notice This function is used to check whether the current staked amount is still above the minimum USD amount
     */
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
    ) public view returns (string[] memory) {
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

    function getPriceFeed() external view returns (AggregatorV3Interface) {
        return priceFeed;
    }
}
