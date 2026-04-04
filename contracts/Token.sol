// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Token {
    string public name = "CrowdToken";
    string public symbol = "CTK";
    uint public totalSupply;

    mapping(address => uint) public balanceOf;

    function mint(address to, uint amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}
