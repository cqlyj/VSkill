// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {Vm} from "forge-std/Vm.sol";

contract SubmitEvidence is Script {
    // @notice: Update this cid and skillDomain to the cid and skillDomain of the evidence you want to submit!
    string cid = "bafkreigpyuchim2hb25gfbtqygwdvhhqinko5vobimzstdq6lqwnxm6nza";
    string skillDomain = "Blockchain";

    function submitEvidence(address mostRecentlyDeployed) public {
        vm.startBroadcast();

        VSkillUser vSkillUser = VSkillUser(payable(mostRecentlyDeployed));
        uint256 submissionFeeInEth = vSkillUser.getSubmissionFeeInEth();
        vSkillUser.submitEvidence{value: submissionFeeInEth}(cid, skillDomain);

        vm.stopBroadcast();

        console.log(
            "Evidence submitted successfully on chain id: ",
            block.chainid
        );
    }

    function run() external {
        address vSkillUser = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );

        submitEvidence(vSkillUser);
    }
}

contract ChangeSubmissionFee is Script {
    uint256 newSubmissionFeeInUsd = 20e18; // 20 USD

    function changeSubmissionFee(address vSkillUser) public {
        vm.startBroadcast();

        VSkillUser vSkillUserInstance = VSkillUser(payable(vSkillUser));
        vSkillUserInstance.changeSubmissionFee(newSubmissionFeeInUsd);

        vm.stopBroadcast();

        console.log(
            "Submission fee changed successfully on chain id: ",
            block.chainid,
            " to: ",
            newSubmissionFeeInUsd
        );
    }

    function run() external {
        address vSkillUser = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );

        changeSubmissionFee(vSkillUser);
    }
}

contract WithdrawProfit is Script {
    function withdrawProfit(address vSkillUser) public {
        vm.startBroadcast();

        VSkillUser vSkillUserInstance = VSkillUser(payable(vSkillUser));
        vSkillUserInstance.withdrawProfit();

        vm.stopBroadcast();

        console.log(
            "Profit withdrawn successfully on chain id: ",
            block.chainid
        );
    }

    function run() external {
        address vSkillUser = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );

        withdrawProfit(vSkillUser);
    }
}
