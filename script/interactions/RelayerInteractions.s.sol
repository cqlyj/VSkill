// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Relayer} from "src/Relayer.sol";
import {Vm} from "forge-std/Vm.sol";

contract AssignEvidenceToVerifiers is Script {
    function assignEvidenceToVerifiers(address relayer) public {
        vm.startBroadcast();

        Relayer relayerInstance = Relayer(payable(relayer));
        relayerInstance.assignEvidenceToVerifiers();

        vm.stopBroadcast();

        console.log(
            "Evidence assigned successfully on chain id: ",
            block.chainid
        );
    }

    function run() external {
        address relayer = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        assignEvidenceToVerifiers(relayer);
    }
}

contract ProcessEvidenceStatus is Script {
    // @notice Update the batch number you want to process
    uint256 public batchNumber = 0;

    function processEvidenceStatus(address relayer) public {
        vm.startBroadcast();

        Relayer relayerInstance = Relayer(payable(relayer));
        relayerInstance.processEvidenceStatus(batchNumber);

        vm.stopBroadcast();

        console.log(
            "Evidence status processed successfully on chain id: ",
            block.chainid,
            " for batch number: ",
            batchNumber
        );
    }

    function run() external {
        address relayer = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        processEvidenceStatus(relayer);
    }
}

contract HandleEvidenceAfterDeadline is Script {
    // @notice Update the batch number you want to process
    uint256 public batchNumber = 0;

    function handleEvidenceAfterDeadline(address relayer) public {
        vm.startBroadcast();

        Relayer relayerInstance = Relayer(payable(relayer));
        relayerInstance.handleEvidenceAfterDeadline(batchNumber);

        vm.stopBroadcast();

        console.log(
            "Evidence handled successfully on chain id: ",
            block.chainid,
            " for batch number: ",
            batchNumber
        );
    }

    function run() external {
        address relayer = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        handleEvidenceAfterDeadline(relayer);
    }
}

contract AddMoreSkill is Script {
    string skillDomain = "AI & ML";
    string nftImageUri = "https://ipfs.io/ipfs/AiAndMLNftImageUri";

    function addMoreSkill(address relayer) public {
        vm.startBroadcast();

        Relayer relayerInstance = Relayer(payable(relayer));
        relayerInstance.addMoreSkill(skillDomain, nftImageUri);

        vm.stopBroadcast();

        console.log(
            "Skill added successfully on chain id: ",
            block.chainid,
            " for skill domain: ",
            skillDomain
        );
        console.log("NFT image URI: ", nftImageUri);
    }

    function run() external {
        address relayer = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        addMoreSkill(relayer);
    }
}

contract TransferBonusFromVSkillUserToVerifierContract is Script {
    function transferBonusFromVSkillUserToVerifierContract(
        address relayer
    ) public {
        vm.startBroadcast();

        Relayer relayerInstance = Relayer(payable(relayer));
        relayerInstance.transferBonusFromVSkillUserToVerifierContract();

        vm.stopBroadcast();

        console.log(
            "Bonus transferred successfully on chain id: ",
            block.chainid
        );
    }

    function run() external {
        address relayer = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        transferBonusFromVSkillUserToVerifierContract(relayer);
    }
}
