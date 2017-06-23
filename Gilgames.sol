pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./Owned.sol";
import "./StandardToken.sol";

contract Gilgames is StandardToken, Owned {
	string public name;
	string public symbol;
	uint8 public decimals;
	uint public startTime; 								// Crowdsale start block (set in constructor)
	uint public endTime; 									// Crowdsale end block (set in constructor)
	bool public founderAlloc = false;						// Founder tokens is allocated
	uint256 public foundAllocTokens = 20000000 * 1 ether;	// Founder tokens
	bool public halted = false;								// Emergency stop switch
	uint public freeze = 5356800;	 						// Seconds
	uint public freezeFounder = 63072000;					// Seconds
	address private bountyAddress = 0x0;
	address private rfAddress = 0x0;
	address private cdAddress = 0x0;
	address private sideContract = 0x0;

	event Buy(address indexed _buyer, uint256 _amountEth, uint256 _buyerTokenBalance, bytes _message);
	event AllocateFounderTokens(address indexed _sender, address indexed _to, uint256 _amount);
	event Burn(address indexed _address, uint256 _amount);
	event BountyTransferred(address _to, uint256 _amount);

	/* Initializes contract with initial supply tokens to the creator of the contract */
	function Gilgames(uint256 _supply, uint256 _bounty, string _name, string _symbol, uint8 _decimals, address _owner, address _bountyAddress, uint _startTime, uint _endTime) {
		name = _name;										// Gilgames
		symbol = _symbol;									// GGS
		decimals = _decimals;								// 18
		startTime = _startTime;								// Time of start
		endTime = _endTime;									// Time of end
		balances[msg.sender] = (_supply-_bounty) * 1 ether;	// 150,000,000 token created
		balances[_bountyAddress] =  _bounty * 1 ether;
		bountyAddress = _bountyAddress;
		totalSupply = foundAllocTokens + _bounty * 1 ether;
		owner = _owner;										// Owner address of smart contract and initial tokens
	}

	/*
	*	Set sideContract address.
	*	INIT AFTER DEPLOY THE SIDE CONTRACT
	*/
	function setSideContract(address _value) onlyOwner returns(bool res) {
		sideContract = _value;
		return true;
	}

	/*
	*	Set rfAddress if owner or rfAddress is the caller
	*	INIT AFTER DEPLOY THE CONTRACT
	*/
	function setRFAddress(address _address) returns(bool res) {
		if(msg.sender != rfAddress && msg.sender != owner) return false;
		rfAddress = _address;
		return true;
	}

	/*
	*	Set cdAddress if owner or cdAddress is the caller
	*	INIT AFTER DEPLOY THE SIDE CONTRACT
	*/
	function setCDAddress(address _address) returns(bool res) {
		if(msg.sender != cdAddress && msg.sender != owner) return false;
		cdAddress = _address;
		return true;
	}

	/*
	*	Buy the GGS tokens logic.
	*	Untill the crowdsale's end -> endTime
	*	Calculate the price helps the checkPrice function
	*	Check the GGS balances of owner add to the amount the founder alloc tokens
	*	Calculate the dividens to addresses
	*	Send the ethers
	*	Manipulate the balances
	*	Send an Event to wallet
	*/
	function buy(address _buyer) internal returns(bool res) {
		if(halted) return false;
		if(now>endTime) return false;
		uint256 amount = msg.value * checkPrice(now);
		if (balances[owner] < safeAdd(amount,foundAllocTokens)) return false;
		uint256 _value = 0;
		if (rfAddress != 0x0) {
			_value = safeAdd(_value, (msg.value/200));
			if (!rfAddress.call.value(msg.value/200)()) return false;
		}
		if (cdAddress != 0x0) {
			_value = safeAdd(_value, (msg.value/200));
			if (!cdAddress.call.value(msg.value/200)()) return false;
		}
		if (!owner.call.value(safeSub(msg.value,_value))()) return false;
		balances[owner] = safeSub(balances[owner], amount);
		balances[_buyer] = safeAdd(balances[_buyer], amount);
		totalSupply = safeAdd(totalSupply, amount);
		Buy(_buyer, msg.value / 1 ether, amount / 1 ether, msg.data);
		return true;
	}

	/*
	*	Allocation founder tokens to an address after the founder freezeing time
	*/
	function allocateFounderFund(address _to) onlyOwner returns(bool res) {
		if (now <= endTime + freezeFounder) return false;
		if (founderAlloc) return false;
		balances[msg.sender] = safeSub(balances[msg.sender], foundAllocTokens);
		balances[_to] = safeAdd(balances[_to], foundAllocTokens);
		founderAlloc = true;
		AllocateFounderTokens(msg.sender, _to, foundAllocTokens);
		return true;
	}

	/*
	*	Pay the Ecosystem bounty program rewards and sponsorations not neccessary
	*	to wait the end of freezing time to pay bounty and sponsorship
	*/
	function transferBounty(address _to, uint256 _value) returns (bool res) {
		if (msg.sender != bountyAddress) return false;
		return super.transfer(_to, _value);
	}

	/*
	*	transferFrom inherited from StandardToken + freeze time
	*/
	function transfer(address _to, uint256 _value) returns(bool res) {
		if (now <= endTime + freeze && msg.sender!=owner) return false;
		return super.transfer(_to, _value);
	}

	/*
	*	transferFrom inherited from StandardToken + freeze time
	*/
	function transferFrom(address _from, address _to, uint256 _value) returns(bool res) {
		if (msg.sender != sideContract) {
			if (now <= endTime + freeze && msg.sender!=owner) return false;
			return super.transferFrom(_from, _to, _value);
		} else {
			totalSupply = safeAdd(totalSupply, _value);
			return super.transferFrom(_from, _to, _value);
		}
	}

	/*
	*	Calculate the price with the blocknumber.
	*	Approx ((60/15)*60*24*7) 15sec Block time average
	*	Power Hour 220 block (~1 hour) 1/850
	*	Default price 1/500
	*	Presale price 1/850
	*	Crowdsale price 1/650-1/500 dividend to 4 week
	*/
	function checkPrice(uint _now) constant returns(uint) {
		if (_now<1497952800) return 850;
		if (_now>=1497952800 && _now<1497956400) return 750;
		if (_now>=1497956400 && _now<1498557600) return 650;
		if (_now>=1498557600 && _now<1499162400) return 600;
		if (_now>=1499162400 && _now<1499767200) return 550;
		if (_now>1499767200) return 500;
	}

	/*
	*	Emergency stop the crowdsale
	*/
	function halt() onlyOwner {
		halted = true;
	}

	/*
	*	Emergency stop switch off
	*/
	function unhalt() onlyOwner {
		halted = false;
	}

	/*
	*	Burn unsold tokens expect the founder allocate. Needs the allocate ecosystem tokens first!
	*	Calculate the burning tokens, let the founder allocation untouched after burn.
	*/
	function burn() onlyOwner returns(bool res) {
		uint256 _value = safeSub(balances[msg.sender], foundAllocTokens);
		balances[msg.sender] = safeSub(balances[msg.sender], _value);
		Burn(msg.sender, _value);
		return true;
	}

	/*
	*	Approve and then communicate the approved contract in a single tx
	*	call the receiveApproval function on the contract you want to be notified.
	*	This crafts the function signature manually so one doesn't have to include
	*	a contract in here just for this.
	*	receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
	*	it is assumed that when does this that the call *should* succeed,
	*	otherwise one would use vanilla approve instead.
	*/
	function approveAndCall(address _spender, uint256 _value, bytes _extraData) onlyOwner returns (bool res) {
		allowed[msg.sender][_spender] = _value;
		Approval(msg.sender, _spender, _value);
		if(!_spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData)) { throw; }
		return true;
	}

	/*
	*	Default fallback payable accept ether and call the buy funct.
	*/
	function() public payable {
		if(!buy(msg.sender)) throw;
	}
}
