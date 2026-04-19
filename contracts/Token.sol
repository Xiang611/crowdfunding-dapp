// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Token {
    string public name = "CrowdToken";
    string public symbol = "CTK";
    uint public totalSupply;
    address public owner;
    address public crowdfundingContract;
    address public stakingContract;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor() {
        owner = msg.sender;
    }

    // ── Only owner can set these, one time only
    function setCrowdfundingContract(address _addr) public {
        require(msg.sender == owner, "Not owner");
        require(crowdfundingContract == address(0), "Already set");
        require(_addr != address(0), "Zero address");
        crowdfundingContract = _addr;
    }

    function setStakingContract(address _addr) public {
        require(msg.sender == owner, "Not owner");
        require(stakingContract == address(0), "Already set");
        require(_addr != address(0), "Zero address");
        stakingContract = _addr;
    }

    // ── Both crowdfunding and staking can mint
    function mint(address to, uint amount) public {
        require(
            msg.sender == crowdfundingContract || msg.sender == stakingContract,
            "Not authorized"
        );
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Not approved");
        require(balanceOf[from] >= amount, "Insufficient balance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function getAllowance(
        address tokenOwner,
        address spender
    ) public view returns (uint) {
        return allowance[tokenOwner][spender];
    }
}
