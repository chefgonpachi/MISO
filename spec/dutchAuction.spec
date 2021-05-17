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
 * envfree indicates that the method is not dependent on the environment, eg:
 * msg.value, msg.sender, etc.
 * Methods that are not declared here are assumed to be dependent on env.
 */
methods {
	
	// envfree methods
	commitments(address) returns (uint256) envfree
	claimed(address) returns (uint256) envfree
	paymentCurrency() returns (address) envfree
	auctionToken() returns (address) envfree
	tokenBalanceOf(address, address) returns (uint256) envfree
	getCommitmentsTotal() returns (uint256) envfree
	getTotalTokens() returns (uint256) envfree
	isFinalized() returns (bool) envfree
	isInitialized() returns (bool) envfree
	 

	// IERC20 methods to be called to one of the tokens (DummyERC201, DummyWeth)
	balanceOf(address) => DISPATCHER(true) 
	totalSupply() => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)
	permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) => NONDET
	decimals() => DISPATCHER(true)
	
	// receiver if weth
	sendTo() => DISPATCHER(true)

	// IPointList
	hasPoints(address account, uint256 amount) => NONDET
}

definition MAX_UNSIGNED_INT() returns uint256 =
 			0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

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
	{
		preserved withdrawTokens() with (env e) {
			require isOpen(e);
		}

		preserved withdrawTokens(address a) with (env e) {
			require isOpen(e);
		}
	}

invariant integrityOfTokensClaimable(address user, env e) 
	((commitments(user) == 0) => (tokensClaimable(e, user) == 0)) &&
	(tokensClaimable(e, user) <= commitments(user) * getStartPrice(e) * 1000000000000000000)
	

// Since we assume the following property in other rules we make to sure this is always true
rule initState(method f) filtered 
		{f -> (f.selector == initMarket(bytes).selector ||
			f.selector == initAuction(address, address, uint256, uint256,
									  uint256, address, uint256, uint256,
									  address, address, address).selector)} {
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
    assert (_startTime < _endTime  && _minimumPrice > 0 && _startPrice > _minimumPrice);
	
}

rule marketInfoAndPriceUnmodifiable(method f) {
	env e;
	uint64 _startTime;
    uint64 _endTime;
    uint128 _totalTokens;
	uint128 _startPrice;
    uint128 _minimumPrice;
	uint128 commitmentsTotal;
	bool finalized;
    bool usePointList;
    _startTime, _endTime, _totalTokens = marketInfo(e);
	_startPrice, _minimumPrice = marketPrice(e);
    
	calldataarg args;
	require (f.selector != initMarket(bytes).selector &&
			f.selector != initAuction(address, address, uint256, uint256,
									  uint256, address, uint256, uint256, 
									  address, address, address).selector);
	f(e,args);
	
	uint64 startTime_;
    uint64 endTime_;
    uint128 totalTokens_;
	uint128 startPrice_;
    uint128 minimumPrice_;
    startTime_, endTime_, totalTokens_ = marketInfo(e);
	startPrice_, minimumPrice_ = marketPrice(e);
	
	assert 	_totalTokens == totalTokens_ &&
			( getCommitmentsTotal() > 0 => (_startPrice == startPrice_ && 
			_minimumPrice == minimumPrice_  &&
			_endTime == endTime_ &&
			_startTime == startTime_ )); 		
		
}



rule preserveTotalAssetsOnCommit(address user, uint256 amount, method f) {
	env e;

	require user == e.msg.sender;

	require e.msg.sender != currentContract; 

	uint256 _userPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), user);
	uint256 _userCommitments = commitments(user);

	uint256 possibleCommitment = calculateCommitment(e, amount);

	require f.selector == commitEth(address, bool).selector ||
	        f.selector == commitTokens(uint256, bool).selector;

	if (f.selector == commitTokens(uint256, bool).selector) {
		commitTokens(e, possibleCommitment, true);
	} else {
		require user == receiver;
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

rule auctionSuccessfulWithdraw() {
	env e;

	require auctionToken() != paymentCurrency();

	require auctionSuccessful(e) == true;

	require e.msg.sender == receiver;

	uint256 _userPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 _userAuctionTokenBalance = tokenBalanceOf(auctionToken(), e.msg.sender);
	uint256 _userClaimed = claimed(e.msg.sender);
	uint256 claimableTokens = tokensClaimable(e, e.msg.sender);

	withdrawTokens(e);

	uint256 userPaymentCurrencyBalance_ = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 userAuctionTokenBalance_ = tokenBalanceOf(auctionToken(), e.msg.sender);
	uint256 userClaimed_ = claimed(e.msg.sender);

	assert(_userPaymentCurrencyBalance == userPaymentCurrencyBalance_);
	assert(userAuctionTokenBalance_ == _userAuctionTokenBalance + claimableTokens);
	assert(userClaimed_ == _userClaimed + claimableTokens);
}

rule auctionUnsuccessfulWithdraw() {
	env e;

	require auctionSuccessful(e) == false;

	require e.msg.sender != currentContract;

	uint256 _userPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 _userCommitments = commitments(e.msg.sender);

	withdrawTokens(e);

	uint256 userPaymentCurrencyBalance_ = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 userCommitments_ = commitments(e.msg.sender);

	assert(userPaymentCurrencyBalance_ == _userPaymentCurrencyBalance + _userCommitments);
	assert(userCommitments_ == 0);
}

rule noChangeToOthersAssets(method f, address other, address from) {
	env e;
	assumeInitState();
	require e.msg.sender != other && other == receiver;

	require paymentCurrency() != auctionToken();
	uint256 _otherPaymentCurrencyBalance = tokenBalanceOf(paymentCurrency(), other);
	uint256 _otherAuctionTokenBalance = tokenBalanceOf(auctionToken(), other);
	uint256 _otherCommitment = commitments(other);
	uint256 _otherClaimed = claimed(other);

	uint256 amount;
	callFunction(e.msg.sender, from, receiver, amount, f);

	uint256 otherPaymentCurrencyBalance_ = tokenBalanceOf(paymentCurrency(), other);
	uint256 otherAuctionTokenBalance_ = tokenBalanceOf(auctionToken(), other);
	uint256 otherCommitment_ = commitments(other);
	uint256 otherClaimed_ = claimed(other);

	assert(_otherPaymentCurrencyBalance <= otherPaymentCurrencyBalance_,
		    "other's payment balance decreased");

	// if other is receiver, it is expected that after withdraw, their
	// commitment decreases and claimed increases
	if (f.selector == withdrawTokens(address).selector ) {
		assert(_otherCommitment >= otherCommitment_, "other's commitment increased");
		assert(_otherClaimed <= otherClaimed_, "other's claimed didn't update");
		assert(_otherAuctionTokenBalance <= otherAuctionTokenBalance_,
		       "other's auction balance decreased");
	} else {
		assert(_otherCommitment <= otherCommitment_, "other's commitment decreased");
		assert(_otherClaimed == otherClaimed_, "other's claimed changed");
		assert(_otherAuctionTokenBalance <= otherAuctionTokenBalance_,
		       "other's auction balance changed");
	}
}


/*
rule additivityOfCommitEth(address user, address beneficiary, uint256 x, uint256 y) {
	env ex;
	env ey;
	env exy;
	bool agreement;
		
	require x + y <= MAX_UNSIGNED_INT();
	uint256 sum = x + y;

	require user != currentContract;
	require ex.msg.sender == user && ey.msg.sender == user && exy.msg.sender == user;
	require ex.msg.value == x && ey.msg.sender == y && exy.msg.sender == sum;
	require beneficiary == receiver;

	storage initStorage = lastStorage;
	
	commitEth(ex, beneficiary, agreement);
	commitEth(ey, beneficiary, agreement);
	
	
	uint256 splitScenarioCommitment = commitments(beneficiary);
	uint256 splitScenarioSenderBalanceOf = tokenBalanceOf(paymentCurrency(), user);

	
	commitEth(exy, beneficiary, agreement) at initStorage;
	
	uint256 sumScenarioCommitment = commitments(beneficiary);
	uint256 sumScenarioSenderBalanceOf = tokenBalanceOf(paymentCurrency(), user);

	assert(splitScenarioCommitment == sumScenarioCommitment, 
		   "addCommitment not additive on commitment");

	assert(splitScenarioSenderBalanceOf == sumScenarioSenderBalanceOf, 
		   "addCommitment not additive on sender's balanceOf");
	
}
*/

rule additivityOfCommitTokensFrom(uint256 x, uint256 y,
								  address from, bool agreement) {
	env e;

	require e.msg.sender != currentContract;

	storage initStorage = lastStorage;
	
	commitTokensFrom(e, from, x, agreement);
	commitTokensFrom(e, from, y, agreement);
	
	uint256 splitScenarioCommitment = commitments(from);
	uint256 splitScenarioSenderBalanceOf = tokenBalanceOf(paymentCurrency(), e.msg.sender);
	uint256 splitTotalCommitments = getCommitmentsTotal();

	require x + y <= MAX_UNSIGNED_INT();
	uint256 sum = x + y;
	commitTokensFrom(e, from, sum, agreement) at initStorage;
	uint256 sumTotalCommitments = getCommitmentsTotal();
	
	uint256 sumScenarioCommitment = commitments(from);
	uint256 sumScenarioSenderBalanceOf = tokenBalanceOf(paymentCurrency(), e.msg.sender);

	assert(splitScenarioCommitment == sumScenarioCommitment, 
		   "addCommitment not additive on commitment");

	assert(splitScenarioSenderBalanceOf == sumScenarioSenderBalanceOf, 
		   "addCommitment not additive on sender's balanceOf");
	
	assert(splitTotalCommitments == sumTotalCommitments, 
		   "addCommitment not additive on totalCommitments");
	
}

rule auctionSuccessfulSteadyState(method f) {
	env e;
	assumeInitState();
	uint256 tokenPriceBefore = tokenPrice(e);
	uint256 clearingPriceBefore = clearingPrice(e);
	uint256 commitmentsBefore = getCommitmentsTotal();
	
	require (isInitialized() && auctionSuccessful(e)  && getCommitmentsTotal() > 0 );

	calldataarg args;
	f(e,args);
	uint256 tokenPriceAfter = tokenPrice(e);
	uint256 clearingPriceAfter = clearingPrice(e);
	uint256 commitmentsAfter = getCommitmentsTotal();

	assert (auctionSuccessful(e) && clearingPriceAfter == clearingPriceBefore && commitmentsAfter == commitmentsBefore);
}

rule noCommitmentsBeforeOpen(method f) 
				filtered {f -> (f.selector == commitEth(address,bool).selector ||
								f.selector == commitTokens(uint256,bool).selector) } 
{
	env e;
	address sender;
	address user; 
	uint256 amount;
	bool b;
	require (commitments(user) == 0);
	if (f.selector == commitEth(address,bool).selector) {
		require (e.msg.sender == user && e.msg.value == amount);
		commitEth(e, user ,b);
	}
	else  {
		require (e.msg.sender == user);
		commitTokens(e, amount, b);
	}
	uint64 startTime_;
    uint64 endTime_;
    uint128 totalTokens_;

	startTime_, endTime_, totalTokens_ = marketInfo(e);
	assert ( commitments(user) > 0 => e.block.timestamp >= startTime_);
}

/* this rule is timing out */
/*
rule noFrontRunningOnWithdraw(method f) 
		// this methods can cause the withdraw to fail, since the auction can be now successful or finalized
		filtered { f-> (f.selector !=  commitEth(address,bool).selector &&
						f.selector !=  commitTokensFrom(address,uint256,bool).selector &&
						f.selector !=  commitTokens(uint256,bool).selector  &&
						f.selector !=  finalize().selector )}
	
{
	env e;
	env eF;
	calldataarg argsF;
	uint64 startTime_;
    uint64 endTime_;
    uint128 totalTokens_;

	startTime_, endTime_, totalTokens_ = marketInfo(e);
	assumeInitState();
	uint256 commitments_ = commitments(e.msg.sender);
	address other;
	require( other != e.msg.sender);
	require (eF.msg.sender != currentContract && e.msg.sender != currentContract);
	require (eF.msg.sender != e.msg.sender || f.selector != withdrawTokens().selector );
	require (commitments_ <= getCommitmentsTotal() );
	require( commitments_ > 0 => e.block.timestamp >= startTime_ );
	require( commitments_ > 0);
	storage initStorage = lastStorage;
	
	//first scenario: user can call withdrawTokens
	withdrawTokens(e);

	//second scenario: someone else calls another function (or same user calls another function beside withdraw) 
	if (f.selector != withdrawTokens(address).selector) {
		withdrawTokens(eF, other) at initStorage;
	}
	else {
		f(eF,argsF) at initStorage;
	}
	//Verify that user can call withdrawTokens
	withdrawTokens@withrevert(e);
	assert !lastReverted;
}
*/



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
	uint128 startPrice__;
    uint128 minimumPrice__;
	uint64 startTime__;
    uint64 endTime__;
    uint128 totalTokens__;

	startTime__, endTime__, totalTokens__ = marketInfo(e);
	startPrice__, minimumPrice__ = marketPrice(e);
	
	require (startTime__ < endTime__ && minimumPrice__ > 0 && startPrice__ > minimumPrice__ && isInitialized());
}

