// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";

contract Crowdfunding {
    Token public token;

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
    }

    struct Campaign {
        address creator;
        string title;
        string description;
        uint goal;
        uint deadline;
        uint amountRaised;
        bool withdrawn;
    }

    Campaign[] public campaigns;

    mapping(uint => mapping(address => uint)) public contributions;
    mapping(uint => address[]) public contributors;

    event CampaignCreated(
        uint campaignId,
        address creator,
        uint goal,
        uint deadline
    );

    function createCampaign(
        string memory _title,
        string memory _description,
        uint _goal,
        uint _durationInDays
    ) public {

        require(_goal > 0, "Goal must be > 0");
        require(_durationInDays > 0, "Duration must be > 0");

        uint deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns.push(
            Campaign(
                msg.sender,
                _title,
                _description,
                _goal,
                deadline,
                0,
                false
            )
        );

        uint campaignId = campaigns.length - 1;

        emit CampaignCreated(campaignId, msg.sender, _goal, deadline);
    }

    function contribute(uint id) public payable {
        Campaign storage c = campaigns[id];

        require(block.timestamp < c.deadline, "Campaign ended");

        if (contributions[id][msg.sender] == 0) {
            contributors[id].push(msg.sender);
        }

        contributions[id][msg.sender] += msg.value;
        c.amountRaised += msg.value;
    }

    function withdraw(uint id) public {
        Campaign storage c = campaigns[id];

        require(msg.sender == c.creator, "Not creator");
        require(c.amountRaised >= c.goal, "Goal not reached");
        require(!c.withdrawn, "Already withdrawn");

        c.withdrawn = true;
        payable(c.creator).transfer(c.amountRaised);

        for (uint i = 0; i < contributors[id].length; i++) {
            address user = contributors[id][i];
            uint amount = contributions[id][user];

            token.mint(user, amount);
        }
    }

    function refund(uint id) public {
        Campaign storage c = campaigns[id];

        require(block.timestamp > c.deadline, "Not ended");
        require(c.amountRaised < c.goal, "Goal reached");

        uint amount = contributions[id][msg.sender];
        require(amount > 0, "No contribution");

        contributions[id][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getCampaignCount() public view returns (uint) {
        return campaigns.length;
    }
}
