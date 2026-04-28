// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";

contract Crowdfunding {
    address public owner;
    uint public platformFeeBalance;
    Token public token;

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
        owner = msg.sender; //whoever deploys = platform owner
    }

    struct Campaign {
        address creator;
        string title;
        string description;
        uint goal;
        uint deadline;
        uint amountRaised;
        bool withdrawn;
        bool refunded;
    }

    struct User {
        string name;
        string email;
        bool registered;
    }

    mapping(address => User) public users;

    function registerUser(string memory _name, string memory _email) public {
        require(!users[msg.sender].registered, "Already registered");

        users[msg.sender] = User({
            name: _name,
            email: _email,
            registered: true
        });
    }

    function isRegistered(address user) public view returns (bool) {
        return users[user].registered;
    }

    Campaign[] public campaigns;

    mapping(uint => mapping(address => uint)) public contributions;
    mapping(uint => address[]) public contributors;
    mapping(uint => mapping(address => bool)) public tokensClaimed;
    mapping(uint => mapping(address => uint)) public originalContributions;
    mapping(uint => mapping(address => bool)) public hasContributed;

    event CampaignCreated(
        uint campaignId,
        address creator,
        uint goal,
        uint deadline
    );

    event Withdrawn(uint campaignId, address creator, uint amount);

    event Refunded(uint campaignId, address contributor, uint amount);

    event TokensClaimed(uint indexed campaignId, address indexed contributor, uint amount);

    event Contributed(uint indexed campaignId, address indexed contributor, uint amount, uint timestamp);
    
    function createCampaign(
        string memory _title,
        string memory _description,
        uint _goal,
        uint _deadlineTimestamp
    ) public {
        require(_goal > 0, "Goal must be > 0");
        require(
            _deadlineTimestamp > block.timestamp,
            "Deadline must be in the future"
        );
        if (bytes(_title).length == 0) revert("Title cannot be empty");
        if (bytes(_description).length == 0)
            revert("Description cannot be empty");

        campaigns.push(
            Campaign(
                msg.sender,
                _title,
                _description,
                _goal,
                _deadlineTimestamp,
                0,
                false,
                false
            )
        );

        uint campaignId = campaigns.length - 1;
        emit CampaignCreated(campaignId, msg.sender, _goal, _deadlineTimestamp);
    }

    function contribute(uint id) public payable {
        Campaign storage c = campaigns[id];
        if (msg.value == 0) revert("Contribution must be > 0");
        if (block.timestamp > c.deadline) revert("Campaign has ended");

        // ✅ push contributor to array only once
        if (!hasContributed[id][msg.sender]) {
            contributors[id].push(msg.sender);
            hasContributed[id][msg.sender] = true;
        }

        contributions[id][msg.sender] += msg.value;
        originalContributions[id][msg.sender] += msg.value;
        c.amountRaised += msg.value;

        // ✅ emit event with timestamp for history
        emit Contributed(id, msg.sender, msg.value, block.timestamp);
    }

    function withdraw(uint id, bool useCTKDiscount) public {
        require(id < campaigns.length, "Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator, "Only creator can withdraw");
        require(c.amountRaised >= c.goal, "Funding goal not reached");
        require(!c.withdrawn, "Already withdrawn");
        c.withdrawn = true;
        assert(c.withdrawn == true); //checks the mutation succeeded

        //Check if creator holds CTK for fee discount
        uint feePercent;
        if (useCTKDiscount && token.balanceOf(msg.sender) >= 10 * 1e18) {
            feePercent = 1;
        } else {
            feePercent = 3;
        }

        uint fee = (c.amountRaised * feePercent) / 100;
        uint creatorAmount = c.amountRaised - fee;
        assert(creatorAmount + fee == c.amountRaised);
        platformFeeBalance += fee;

        //Auto-mint CTK to all contributors
        address[] memory contribs = contributors[id];
        for (uint i = 0; i < contribs.length; i++) {
            address contributor = contribs[i];

            if (!tokensClaimed[id][contributor]) {
                uint contributed = contributions[id][contributor];
                uint wholeEth = contributed / 1 ether;
                uint tokensToMint = wholeEth * 1e18;

                if (tokensToMint > 0) {
                    try token.mint(contributor, tokensToMint) {
                        tokensClaimed[id][contributor] = true;
                        emit TokensClaimed(id, contributor, tokensToMint);
                    } catch {
                        // mint failed silently — user can still call claimTokens() later
                    }
                }
            }
        }

        // Send ETH to creator
        payable(c.creator).transfer(creatorAmount);
        emit Withdrawn(id, c.creator, creatorAmount);
    }

    function autoRefundAll(uint id) public {
        require(id < campaigns.length, "Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(block.timestamp >= c.deadline, "Campaign not ended yet");
        require(c.amountRaised < c.goal, "Goal was reached, no refund");

        require(!c.refunded, "Already refunded"); // prevent double refund

        c.refunded = true; // mark before sending (prevents reentrancy)

        address[] memory contribs = contributors[id];
        for (uint i = 0; i < contribs.length; i++) {
            address contributor = contribs[i];
            uint amount = contributions[id][contributor];
            if (amount > 0) {
                contributions[id][contributor] = 0;
                assert(contributions[id][contributor] == 0);
                payable(contributor).transfer(amount);
                emit Refunded(id, contributor, amount);
            }
        }
    }

    function getCampaignCount() public view returns (uint) {
        return campaigns.length;
    }

    function claimTokens(uint id) public {
        if (id >= campaigns.length) revert("Campaign does not exist");
        Campaign storage c = campaigns[id];
        require(c.amountRaised >= c.goal, "Campaign did not succeed");
        require(contributions[id][msg.sender] > 0, "No contribution found");
        require(!tokensClaimed[id][msg.sender], "Tokens already claimed");
        uint contributed = contributions[id][msg.sender];
        uint wholeEth = contributed / 1 ether;
        uint tokensToMint = wholeEth * 1e18;
        require(tokensToMint > 0, "Need at least 1 ETH to earn tokens");
        assert(tokensToMint >= 1e18);
        tokensClaimed[id][msg.sender] = true;
        token.mint(msg.sender, tokensToMint);
        emit TokensClaimed(id, msg.sender, tokensToMint);
    }

    function withdrawPlatformFee() public {
        require(msg.sender == owner, "Only owner");
        require(platformFeeBalance > 0, "Nothing to withdraw");

        uint amount = platformFeeBalance;
        platformFeeBalance = 0;
        payable(owner).transfer(amount);
    }

    function getContribution(
        uint id,
        address contributor
    ) public view returns (uint) {
        return contributions[id][contributor];
    }

    function hasClaimedTokens(
        uint id,
        address contributor
    ) public view returns (bool) {
        return tokensClaimed[id][contributor];
    }
}
