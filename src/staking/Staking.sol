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
import {PriceConverter} from "./PriceCoverter.sol";

error Staking__NotEnoughMoneyStaked();
error Staking__NotEnoughBalanceToWithdraw();
error Staking__WithdrawFailed();
error Staking__NotVerifier();
error Staking__AlreadyVerifier();

contract Staking {
    using PriceConverter for uint256;

    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    uint256 private id; // If id is 0, then the address is not a verifier
    uint256 private verifierCount;
    mapping(address => uint256) private addressToMoneyStaked;
    mapping(address => uint256) private verifierToId;
    AggregatorV3Interface internal priceFeed;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event BecomeVerifier(uint256 indexed id, address indexed verifier);
    event LoseVerifier(address indexed verifier);

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        id = 1;
        verifierCount = 0;
    }

    receive() external payable {
        stakeToBeTheVerifier();
    }

    fallback() external payable {
        stakeToBeTheVerifier();
    }

    function withdrawStake(uint256 amountToWithdraw) external {
        if (addressToMoneyStaked[msg.sender] < amountToWithdraw) {
            revert Staking__NotEnoughBalanceToWithdraw();
        }
        addressToMoneyStaked[msg.sender] -= amountToWithdraw;
        (bool success, ) = msg.sender.call{value: amountToWithdraw}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }
        emit Withdrawn(msg.sender, amountToWithdraw);

        if (addressToMoneyStaked[msg.sender] < MIN_USD_AMOUNT) {
            verifierToId[msg.sender] = 0;
            verifierCount--;
            emit LoseVerifier(msg.sender);
        }
    }

    // In case get penalty, stake more
    function stake() external payable {
        addressToMoneyStaked[msg.sender] += msg.value;
        emit Staked(msg.sender, msg.value);

        if (
            addressToMoneyStaked[msg.sender] >= MIN_USD_AMOUNT &&
            verifierToId[msg.sender] == 0
        ) {
            verifierToId[msg.sender] = id;
            id++;
            verifierCount++;
            emit BecomeVerifier(verifierToId[msg.sender], msg.sender);
        }
    }

    function stakeToBeTheVerifier() public payable {
        if (msg.value.convertEthToUsd(priceFeed) < MIN_USD_AMOUNT) {
            revert Staking__NotEnoughMoneyStaked();
        }
        if (verifierToId[msg.sender] != 0) {
            revert Staking__AlreadyVerifier();
        }

        addressToMoneyStaked[msg.sender] += msg.value;
        verifierToId[msg.sender] = id;
        id++;
        verifierCount++;
        emit Staked(msg.sender, msg.value);
        emit BecomeVerifier(verifierToId[msg.sender], msg.sender);
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getMinUsdAmount() external pure returns (uint256) {
        return MIN_USD_AMOUNT;
    }

    function getMoneyStaked(address staker) external view returns (uint256) {
        return addressToMoneyStaked[staker];
    }

    function getVerifierId(address verifier) external view returns (uint256) {
        return verifierToId[verifier];
    }

    function getLatestId() external view returns (uint256) {
        return id;
    }

    function getVerifierCount() external view returns (uint256) {
        return verifierCount;
    }
}
