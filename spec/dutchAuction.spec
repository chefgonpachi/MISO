/*
 * This is a specification file for smart contract verification with the
 * Certora Prover.
 */

/*
 * Declaration of contracts used in the spec 
 */
using DummyERC20A as tokenA
using DummyERC20B as tokenB
using DummyWeth as wethTokenImpl
using Receiver as receiver 

/*
 * Declaration of methods that are used in the rules.
 * envfree indicate that the method is not dependent on the environment
 * (msg.value, msg.sender).
 * Methods that are not declared here are assumed to be dependent on env.
 */
methods {
	tokenPrice() returns (uint256) 
	priceFunction() returns (uint256) 

	// envfree methods
	commitments(address) returns (uint256) envfree
	claimed(address) returns (uint256) envfree
	paymentCurrency() returns (address) envfree
	auctionToken() returns (address) envfree
	tokenBalanceOf(address, address) returns (uint256) envfree
	getCommitmentsTotal() returns (uint256) envfree
	getTotalTokens() returns (uint256) envfree

	// IERC20 methods to be called to one of the tokens (DummyERC201, DummyWeth)
	balanceOf(address) => DISPATCHER(true) 
	totalSupply() => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)
	permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) => NONDET

	// weth specific methods
	deposit() => DISPATCHER(true)
	withdraw(uint256 amount) => DISPATCHER(true)
	decimals() => DISPATCHER(true)

	// receiver if weth
	sendTo() => DISPATCHER(true)

	// eth transfer
	transfer(uint256 amount) => DISPATCHER(true)

	// IPointList
	hasPoints(address account, uint256 amount) => NONDET
}

definition MAX_UNSIGNED_INT() returns uint256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

// a ghost function that tracks the sum of all commitments
ghost sumCommitments() returns uint256 {
	init_state axiom sumCommitments() == 0;
}

// on updated to commitments, update to the sumCommitments
hook Sstore commitments[KEY uint a] uint commit (uint oldCommit) STORAGE {
	havoc sumCommitments assuming sumCommitments@new() == sumCommitments@old() + commit - oldCommit; 
}

// when loading userCollateralShare[a] assume that the sum is more than the loaded value
hook Sload uint256 commit commitments[KEY uint a] STORAGE { 
	require sumCommitments() >= commit;
}

invariant commitmentsTotal()
	sumCommitments() == getCommitmentsTotal()

//Since we assume the following property in other rules we make to sure this is always true
rule initState(method f) filtered 
		{f-> (f.selector == initMarket(bytes).selector ||
			f.selector == initAuction(address,address,uint256,uint256,uint256,address,uint256,uint256,address,address,address).selector)}
{
	env e;
	uint64 _startTime;
    uint64 _endTime;
    uint128 _totalTokens;
	uint128 _startPrice;
    uint128 _minimumPrice;

	calldataarg args;
	f(e,args);

	_startTime, _endTime, _totalTokens = marketInfo(e);
	_startPrice, _minimumPrice = marketPrice(e);
    assert ( _startTime < _endTime  && _minimumPrice > 0 && _startPrice > _minimumPrice);
	
}

rule marketInfoAndPriceUnmodifiable(method f) {
	env e;
	uint64 _startTime;
    uint64 _endTime;
    uint128 _totalTokens;
	uint128 _startPrice;
    uint128 _minimumPrice;
	uint128 commitmentsTotal;
	// todo - check init flag
    // bool _initialized; 
    bool finalized;
    bool usePointList;
    _startTime, _endTime, _totalTokens = marketInfo(e);
	_startPrice, _minimumPrice = marketPrice(e);
    // commitmentsTotal, _initialized, finalized, usePointList  = marketStatus(e);

	calldataarg args;
	require (f.selector != initMarket(bytes).selector &&
			f.selector != initAuction(address,address,uint256,uint256,uint256,address,uint256,uint256,address,address,address).selector);
	f(e,args);
	
	uint64 startTime_;
    uint64 endTime_;
    uint128 totalTokens_;
	uint128 startPrice_;
    uint128 minimumPrice_;
    // bool initialized_; 
    startTime_, endTime_, totalTokens_ = marketInfo(e);
	startPrice_, minimumPrice_ = marketPrice(e);
	// commitmentsTotal, initialized_, finalized, usePointList  = marketStatus(e);
	
	assert _startTime == startTime_ &&
			_endTime == endTime_ &&
			_totalTokens == totalTokens_ &&
			_startPrice == startPrice_ &&
			_minimumPrice == minimumPrice_ ;
			
		//	&& _initialized == initialized_ ; 
}

rule tokenPriceIncreasesMonotonically(method f) {
	env e1;
	env e2;
	assumeInitState();
	require e1.block.timestamp <= e2.block.timestamp;
	uint256 _tokenPrice = tokenPrice(e1);
	uint256 _commitsTotal = getCommitmentsTotal(); 
	uint256 _totalTokens = getTotalTokens();

	calldataarg args;
	f(e1, args);

	uint256 tokenPrice_ = tokenPrice(e2);
	uint256 commitsTotal_ = getCommitmentsTotal(); 
	uint256 totalTokens_ = getTotalTokens();

	assert (_tokenPrice <= tokenPrice_);
}

rule preserveTotalAssetsOnCommit(address user, uint256 amount, method f) {
	env e;

	require paymentCurrency() == wethTokenImpl || paymentCurrency() == tokenA ||
			paymentCurrency() == tokenB;

	require user == e.msg.sender;

	require e.msg.sender != currentContract; // Ask about this (Nurit)

	uint256 _userPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), user);
	uint256 _userCommitments = commitments(user);

	uint256 possibleCommitment = calculateCommitment(e, amount);

	require f.selector == commitEth(address, bool).selector ||
	        f.selector == commitTokens(uint256, bool).selector;

	if (f.selector == commitTokens(uint256, bool).selector) {
		commitTokens(e, possibleCommitment, true);
	} else {
		commitEth(e, user, true);
	}

	mathint userPaymentCurrencyBalance_ = _userPaymentCurrencyBalance - possibleCommitment;
	uint256 actualUserBalance_ = tokenBalanceOf(paymentCurrency(), user);
	uint256 userCommitments_ = commitments(user);

	if (userPaymentCurrencyBalance_ >= 0) {
		assert (actualUserBalance_ == userPaymentCurrencyBalance_, "line 177");
		assert (userCommitments_ == _userCommitments + possibleCommitment, "line 178");
	} else {
		assert (actualUserBalance_ == _userPaymentCurrencyBalance, "line 180");
		assert (userCommitments_ == _userCommitments, "line 181");
	}
}

// rule auctionSuccessfulWithdraw() {
// 	require e.block.timestamp > marketInfo.endTime; // both are uints but might be of different sizes (Check with Nurit)

// 	// after closing
// 	if (auctionSuccessful()) {
// 		// Need to define commitmentsToAuctionTokens (Check with Nurit)
// 		assert (auctionToken.balanceOf(user) == userAuctionTokenBalace + commitmentsToAuctionTokens(possibleCommitment));
// 	} else {
// 		assert (auctionToken.balanceOf(user) == userAuctionTokenBalance &&
// 				tokenBalanceOf(paymentCurrency(), user) == userPaymentCurrencyBalance);
// 	}
// }

rule auctionUnsuccessfulWithdraw() {
	env e;

	require paymentCurrency() == wethTokenImpl || paymentCurrency() == tokenA ||
			paymentCurrency() == tokenB;

	require auctionSuccessful(e) == false;

	require e.msg.sender != currentContract; // Ask about this (Nurit)

	uint256 _userPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 _userCommitments = commitments(e.msg.sender);
	// Ask Nurit about claimed (They don't update claimed,
	// but since the auction is unsuccessful, it might not matter)

	withdrawTokens(e);

	uint256 userPaymentCurrencyBalance_ = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 userCommitments_ = commitments(e.msg.sender);

	assert(userPaymentCurrencyBalance_ == _userPaymentCurrencyBalance + _userCommitments);
	assert(userCommitments_ == 0);
}

rule noChangeToOthersAssets(method f, address other, address from) {
	env e;

	// TODO: (Make less contraint)
	// other's paymentToken can only go up
	// other's auctionToken can only go up
	// other's commitments can only go up
	// other's claimed can not change
	require e.msg.sender != other && other != receiver;

	uint256 _otherCommitment = commitments(other);
	uint256 _otherClaimed = claimed(other);

	uint256 amount;
	callFunction(e.msg.sender, from, receiver, amount, f);

	uint256 otherCommitment_ = commitments(other);
	uint256 otherClaimed_ = claimed(other);

	assert (_otherCommitment == otherCommitment_ && _otherClaimed == otherClaimed_);
}

// additivity of commitTokens? commitEth? (Ask Nurit)
rule additivityOfaddCommitment(address bidder, uint256 x, uint256 y, method f) 
				filtered {f -> (f.selector == commitEth(address,bool).selector ||
								f.selector == commitTokensFrom(address,uint256,bool).selector) } 
	{
	address sender;
	address beneficiary;

	require paymentCurrency() == wethTokenImpl || paymentCurrency() == tokenA ||
			paymentCurrency() == tokenB;

	storage initStorage = lastStorage;

	callFunction(sender, bidder, beneficiary, x, f);
	callFunction(sender, bidder, beneficiary, y, f);

	uint256 splitScenarioCommitment = commitments(bidder);
	uint256 splitScenarioBiddersBalanceOf = tokenBalanceOf(paymentCurrency(), bidder);

	require x + y <= MAX_UNSIGNED_INT();
	uint256 sum = x + y;
	callFunction(sender, bidder, beneficiary, sum, f) at initStorage;
	
	uint256 sumScenarioCommitment = commitments(bidder);
	uint256 sumScenarioBiddersBalanceOf = tokenBalanceOf(paymentCurrency(), bidder);

	assert(splitScenarioCommitment == sumScenarioCommitment, 
		   "addCommitment not additive on commitment");

	assert(splitScenarioBiddersBalanceOf == sumScenarioBiddersBalanceOf, 
		   "addCommitment not additive on bidder's balanceOf");
}

rule auctionSuccessfulStaysTrue(method f) {
	env e;

	require (auctionSuccessful(e));

	calldataarg args;
	f(e,args);

	assert (auctionSuccessful(e));
}

//////////////////////////////////////////////////////////////////////
//                         Helper Functions                         //
//////////////////////////////////////////////////////////////////////

function callFunction(address sender, address from, address beneficiary,
			          uint256 amount, method f) {
	env e;
	bool agreementAccepted;

	require e.msg.sender == sender;

	if (f.selector == commitEth(address, bool).selector) {
		require e.msg.value == amount;
		commitEth(e, beneficiary, agreementAccepted);
	} else if (f.selector == withdrawTokens(address).selector) {
		withdrawTokens(e, beneficiary);
	} else if (f.selector == commitTokensFrom(address,uint256,bool).selector) {
		commitTokensFrom(e, from, amount, agreementAccepted);
	} else if (f.selector == commitTokens(uint256,bool).selector) {
		commitTokens(e, amount, agreementAccepted);
	} else {
		calldataarg args;
		f(e,args);
	}
}

function assumeInitState() {
		env e;
	uint128 startPrice;
    uint128 minimumPrice;
	uint64 startTime;
    uint64 endTime;
    uint128 totalTokens;

	startTime, endTime, totalTokens = marketInfo(e);
	startPrice, minimumPrice = marketPrice(e);
	
	require (startTime < endTime && minimumPrice > 0 && startPrice > minimumPrice);
}