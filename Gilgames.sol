pragma solidity ^0.4.2;

import "./SafeMath.sol";
import "./Owned.sol";
import "./StandardToken.sol";
import "./VeriSig.sol";

contract tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData); }

contract Gilgames is StandardToken, SafeMath, VeriSig, Owned {
	mapping (address => uint256) public balanceOf;
	string public name;
	string public symbol;
	uint8 public decimals;
	uint public startBlock; 								// Crowdsale start block (set in constructor)
	string private certmsg;									// Certify the read and understood the risks and agreements
	uint public endBlock; 									// Crowdsale end block (set in constructor)
	bool public ecoAlloc = false;							// Ecosystem tokens is allocated
	bool public founderAlloc = false;						// Founder tokens is allocated
	uint256 public ecoAllocTokens = 10000000 * 1 ether;		// Ecosystem tokens
	uint256 public foundAllocTokens = 20000000 * 1 ether;	// Founder tokens
	bool public halted = false;								// Emergency stop switch
	uint public freeze = 357120; 							// Transfers are locked for this many blocks after endBlock (assuming 15 second blocks, this is 2 months)
	uint public freezeFounder = 4285440;					// founder allocation cannot be created until this many blocks after endBlock (assuming 15 second blocks, this is 1 year) //4505142
	uint256 public tokensForSale = 90000000 * 1 ether;		// max amount of tokens to sale during the crowdsale
	uint256 public tokensForPresale = 30000000 * 1 ether;	// max amount of tokens to presale

	event Buy(address indexed _buyer, uint256 _amountEth, uint256 _buyerTokenBalance, bytes _message);
	event AllocateFounderTokens(address indexed _sender, address indexed _to);
	event AllocateEcosystemTokens(address indexed _sender, address indexed _to);
	event Burn(address indexed _address, uint256 _amount);
	event CheckData(bytes32 _data);

	/* Initializes contract with initial supply tokens to the creator of the contract */
	function Gilgames(uint256 _supply, string _name, string _symbol, uint8 _decimals, address _minter, uint _startBlock, uint _endBlock, string _certify) {
		name = _name;								// Gilgames
		symbol = _symbol;							// GGS
		decimals = _decimals;						// 18
		startBlock = _startBlock;					// approx. 3,915,160 block 20th of Jun 2017 (15 sec. block)
		endBlock = _endBlock;						// approx. 4,093,720 block 20th of July 2017 (223,200 block 1 month)
		balanceOf[msg.sender] = _supply * 1 ether;	// 150,000,000 token created
		if(_minter != 0 ) owner = _minter;			// Owner address of smart contract and initial tokens
		certmsg = _certify;							// Certify the read and understood the risks and agreements
	}

	function buy(address _buyer) internal {
		//if(block.number<startBlock) throw;									// PRESALE
		if(block.number>endBlock || halted) throw; 								// Checks the crowdsale dates
		if(block.number>startBlock) {
			if(!checkData(msg.data, msg.sender)) throw;							// Do not allow direct deposits only crowdalse
		}
		uint256 amount = msg.value * checkPrice(block.number);					// Calcaltes the amount
		if (balanceOf[owner] < amount) throw;									// Checks if it has enough to sell
		if (!owner.call.value(msg.value)()) throw;								// Sends the ethers to contract owner
		balanceOf[owner] = safeSub(balanceOf[owner], amount);					// Subtracts amount from seller's balance
		balanceOf[_buyer] = safeAdd(balanceOf[_buyer], amount);					// Adds the amount to buyer's balance
		Buy(_buyer, msg.value / 1 ether, amount / 1 ether, msg.data);			// Notifies the wallet
	}

	function allocateFounderFund(address _to) onlyOwner {
		if (block.number <= endBlock + freezeFounder) throw;					// Checks the freeze date
		if (founderAlloc && !ecoAlloc) throw;									// Checks the allocations is ready
		balanceOf[owner] = safeSub(balanceOf[owner], foundAllocTokens);			// Substract owner account
		balanceOf[_to] = safeAdd(balanceOf[_to], foundAllocTokens);				// Adds Founder account
		founderAlloc = true;													// Allocation is ready
		AllocateFounderTokens(msg.sender, _to);									// Notifies the wallet
	}

	function allocateEcosystemTokens(address _to) onlyOwner {
		if (block.number <= endBlock) throw;									// Checks the crodsale end
		if (ecoAlloc) throw;													// Checks the allocation is ready
		balanceOf[owner] = safeSub(balanceOf[owner], ecoAllocTokens);			// Substract owner account
		balanceOf[_to] = safeAdd(balanceOf[_to], ecoAllocTokens);				// Adds Ecosystem account
		ecoAlloc = true;														// Allocation is ready
		AllocateEcosystemTokens(msg.sender, _to);								// Notifies the wallet
	}

	/**
	* All crowdsale depositors must have read the legal agreement.
	*/
	function checkData(bytes _data, address _sender) private returns (bool result) {
		if(_data.length == 0) return false;
		bytes32 hash = sha3(certmsg);
		if(checkSig(hash, _data) != _sender) return false;
		return true;
	}

	function transfer(address _to, uint256 _value) returns (bool success) {
		//if (block.number < startBlock) {
			// PRESALE
		//} else {
			if (block.number <= endBlock + freeze && msg.sender!=owner) throw;
			if (balanceOf[msg.sender] < _value) throw;							// Check if the sender has enough
			balanceOf[msg.sender] = safeSub(balanceOf[msg.sender], _value);		// Subtract from the sender
			balanceOf[_to] = safeAdd(balanceOf[_to], _value);					// Add the same to the recipient
			Transfer(msg.sender, _to, _value);									// Notify anyone listening that this transfer took place
			return true;
		//}
	}

	function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
		//if (block.number < startBlock) {
			// PRESALE
		//} else {
			if (block.number <= endBlock + freeze && msg.sender!=owner) throw;
			return super.transferFrom(_from, _to, _value);
		//}
	}

	function checkPrice(uint _blockNumber) constant returns(uint) {
		if (_blockNumber>=startBlock && _blockNumber<startBlock+250) return 750;	// power hour
		if (_blockNumber>endBlock) return 500;										// default price
		if (_blockNumber<startBlock) return 850;									// presale
		return 500 + 4*(endBlock - _blockNumber)/(endBlock - startBlock + 1)*200/4;	// crowdsale price
	}

	function halt() onlyOwner {
		halted = true;															// Emergency stop switch
	}

	function unhalt() onlyOwner {
		halted = false;															// Emergency stop switch
	}

	function burn(uint256 _value) onlyOwner returns (bool success) {
		if (balanceOf[msg.sender] < _value) throw;								// Check if the sender has enough
		balanceOf[msg.sender] = safeSub(balanceOf[msg.sender], _value);			// Subtract from the sender
		Burn(msg.sender, _value);
		return true;
	}

	function burnFrom(address _from, uint256 _value) onlyOwner returns (bool success) {
		if (balanceOf[_from] < _value) throw;									// Check if the sender has enough
		if (_value > allowed[_from][msg.sender]) throw;							// Check allowance
		balanceOf[_from] =  safeSub(balanceOf[_from], _value);					// Subtract from the sender
		Burn(_from, _value);
		return true;
	}

	/* Approve and then communicate the approved contract in a single tx */
	function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
		tokenRecipient spender = tokenRecipient(_spender);
		if (approve(_spender, _value)) {
			spender.receiveApproval(msg.sender, _value, this, _extraData);
			return true;
		}
	}

	function() public payable {
		buy(msg.sender);
	}
}
