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

contract Staking {
    using PriceConverter for uint256;

    uint256 private constant MIN_USD_AMOUNT = 20e18; // 20 USD
    mapping(address => uint256) private addressToMoneyStaked;
    address[] private verifiers;
    AggregatorV3Interface internal priceFeed;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
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
    }

    function stakeToBeTheVerifier() public payable {
        if (msg.value.convertEthToUsd(priceFeed) < MIN_USD_AMOUNT) {
            revert Staking__NotEnoughMoneyStaked();
        }
        addressToMoneyStaked[msg.sender] += msg.value;
        verifiers.push(msg.sender);
        emit Staked(msg.sender, msg.value);
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

    function getVerifiers(uint256 index) external view returns (address) {
        return verifiers[index];
    }

    function getVerifiersLength() external view returns (uint256) {
        return verifiers.length;
    }
}
