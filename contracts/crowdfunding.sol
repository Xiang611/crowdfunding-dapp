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
    mapping(uint => mapping(address => bool)) public tokensClaimed;

    event CampaignCreated(
        uint campaignId,
        address creator,
        uint goal,
        uint deadline
    );

    event Withdrawn(
        uint campaignId, 
        address creator, 
        uint amount
    );

    event Refunded(
        uint campaignId, 
        address contributor,
        uint amount
    );

    event TokensClaimed(
        uint campaignId,
        address contributor, 
        uint amount
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
        require(id < campaigns.length, "Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator,       "Only creator can withdraw");
        require(block.timestamp >= c.deadline, "Campaign still active");
        require(c.amountRaised >= c.goal,      "Funding goal not reached");
        require(!c.withdrawn,                  "Already withdrawn");

        c.withdrawn = true;
        uint amount = c.amountRaised;
        payable(c.creator).transfer(amount);
        emit Withdrawn(id, c.creator, amount);
    }

    function refund(uint id) public {
        require(id < campaigns.length, "Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(block.timestamp > c.deadline, "Campaign not ended yet");
        require(c.amountRaised < c.goal, "Goal was reached, no refund");
        uint amount = contributions[id][msg.sender];
        require(amount > 0, "No contribution to refund");

        contributions[id][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit Refunded(id, msg.sender, amount);
    }

    function getCampaignCount() public view returns (uint) {
        return campaigns.length;
    }

    function claimTokens(uint id) public {
        require(id < campaigns.length, "Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(c.amountRaised >= c.goal,          "Campaign did not succeed");
        require(contributions[id][msg.sender] > 0, "No contribution found");
        require(!tokensClaimed[id][msg.sender], "Tokens already claimed");
        uint contributed  = contributions[id][msg.sender];
        uint wholeEth     = contributed / 1 ether;
        uint tokensToMint = wholeEth * 1e18;
        require(tokensToMint > 0, "Need at least 1 ETH to earn tokens");
        tokensClaimed[id][msg.sender] = true;
        token.mint(msg.sender, tokensToMint);
        emit TokensClaimed(id, msg.sender, tokensToMint);
    }

    function getContribution(uint id, address contributor) public view returns (uint) { return contributions[id][contributor]; }

    function hasClaimedTokens(uint id, address contributor) public view returns (bool) { return tokensClaimed[id][contributor]; }
}
