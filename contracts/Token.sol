// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Token {
    string public name = "CrowdToken";
    string public symbol = "CTK";
    uint public totalSupply;
    address public crowdfundingContract;
    mapping(address => uint) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint value);

    function setCrowdfundingContract(address _addr) public {
        require(crowdfundingContract == address(0), "Already set");
        require(_addr != address(0), "Zero address");
        crowdfundingContract = _addr;
    }

    function mint(address to, uint amount) public {
        require(msg.sender == crowdfundingContract, "Not authorized");
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
}
