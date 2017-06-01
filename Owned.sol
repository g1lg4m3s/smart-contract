pragma solidity ^0.4.2;

contract Owned {
	address public owner;

	function Owned() {
		owner = msg.sender;
	}

	modifier onlyOwner {
		if (msg.sender != owner) throw;
		_;
	}

	function transferOwnership(address newOwner) internal onlyOwner {
		owner = newOwner;
	}
}
