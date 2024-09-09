// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Timelock is Ownable {
    uint256 public delay;
    uint256 public minDelay;

    mapping(bytes32 => uint256) public queuedProposals;

    constructor(uint256 _delay) Ownable(msg.sender) {
        delay = _delay;
        minDelay = _delay;
    }

    function propose(bytes calldata _proposal) external {
        bytes32 proposalHash = keccak256(_proposal);
        queuedProposals[proposalHash] = block.timestamp + delay;
    }

    function queue(bytes calldata _proposal) external onlyOwner {
        bytes32 proposalHash = keccak256(_proposal);
        require(queuedProposals[proposalHash] > 0 && block.timestamp >= queuedProposals[proposalHash], "Proposal not queued or expired");
        queuedProposals[proposalHash] = 0;
    }

    function execute(bytes calldata _proposal) external onlyOwner {
        bytes32 proposalHash = keccak256(_proposal);
        require(queuedProposals[proposalHash] > 0 && block.timestamp >= queuedProposals[proposalHash], "Proposal not queued or expired");
        queuedProposals[proposalHash] = 0;

        (bool success, ) = address(this).call(_proposal);
        require(success, "Proposal execution failed");
    }

    // ... (other functions for updating delay, etc.)
}