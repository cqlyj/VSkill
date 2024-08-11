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
import {PriceConverter} from "../utils/PriceCoverter.sol";

contract Staking {
    using PriceConverter for uint256;

    error Staking__NotEnoughBalanceToWithdraw(uint256 currentStakeEthAmount);
    error Staking__NotEnoughStakeToBecomeVerifier(
        uint256 currentStakeUsdAmount,
        uint256 minStakeUsdAmount
    );
    error Staking__WithdrawFailed();
    error Staking__NotVerifier();
    error Staking__AlreadyVerifier();

    struct verifier {
        uint256 id;
        address verifierAddress;
        uint256 reputation;
        string[] skillDomains;
        uint256 moneyStakedInUsd;
        string[] evidenceIpfsHash;
        string[] feedbackIpfsHash;
    }

    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private immutable LOWEST_REPUTATION = 0;
    uint256 private immutable HIGHEST_REPUTATION = 10;
    uint256 private id; // If id is 0, then the address is not a verifier
    uint256 private verifierCount;

    AggregatorV3Interface internal priceFeed;
    mapping(address => uint256) internal addressToId;
    verifier[] internal verifiers;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event BecomeVerifier(uint256 indexed id, address indexed verifier);
    event LoseVerifier(address indexed verifier);

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        id = 1;
        verifierCount = 0;
    }

    receive() external payable {}

    fallback() external payable {}

    function withdrawStake(uint256 amountToWithdraw) external {
        if (addressToId[msg.sender] == 0) {
            revert Staking__NotVerifier();
        }

        if (
            verifiers[addressToId[msg.sender] - 1].moneyStakedInUsd <
            amountToWithdraw
        ) {
            revert Staking__NotEnoughBalanceToWithdraw(
                verifiers[addressToId[msg.sender] - 1].moneyStakedInUsd
            );
        }

        (bool success, ) = msg.sender.call{value: amountToWithdraw}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        verifiers[addressToId[msg.sender] - 1]
            .moneyStakedInUsd -= amountToWithdraw;
        emit Withdrawn(msg.sender, amountToWithdraw);

        if (
            !_currentStakedAmountIsStillAboveMinUsdAmount(
                verifiers[addressToId[msg.sender] - 1].moneyStakedInUsd
            )
        ) {
            addressToId[msg.sender] = 0;
            verifierCount--;
            emit LoseVerifier(msg.sender);

            // Remove the verifier from the array
            uint256 index = addressToId[msg.sender] - 1;
            verifiers[index] = verifiers[verifierCount];
            verifiers.pop();
        }
    }

    function stake(uint256 amountInUsd) external payable {
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

                verifiers[addressToId[msg.sender] - 1].moneyStakedInUsd += msg
                    .value
                    .convertEthToUsd(priceFeed);
                emit Staked(msg.sender, msg.value);
            }
        }

        verifiers[addressToId[msg.sender] - 1].moneyStakedInUsd += msg
            .value
            .convertEthToUsd(priceFeed);
        emit Staked(msg.sender, msg.value);
    }

    /////////////////////////////////
    /////   Internal Functions   ////
    /////////////////////////////////

    function _initializeVerifier(
        address verifierAddress,
        string[] memory skillDomains
    ) internal view returns (verifier memory) {
        return
            verifier({
                id: id,
                verifierAddress: verifierAddress,
                reputation: INITIAL_REPUTATION,
                skillDomains: skillDomains,
                moneyStakedInUsd: 0,
                evidenceIpfsHash: new string[](0),
                feedbackIpfsHash: new string[](0)
            });
    }

    function _currentStakedAmountIsStillAboveMinUsdAmount(
        uint256 currentStakedAmount
    ) internal pure returns (bool) {
        return currentStakedAmount >= MIN_USD_AMOUNT;
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

    function getVerifierMoneyStakedInUsd(
        address verifierAddress
    ) external view returns (uint256) {
        return verifiers[addressToId[verifierAddress] - 1].moneyStakedInUsd;
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
    ) external view returns (verifier memory) {
        return verifiers[addressToId[verifierAddress] - 1];
    }

    function getVerifierById(
        uint256 _id
    ) external view returns (verifier memory) {
        return verifiers[_id - 1];
    }
}
