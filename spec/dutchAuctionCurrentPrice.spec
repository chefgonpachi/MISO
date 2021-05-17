/*
 * This is a specification file for smart contract verification with the
 * Certora Prover.
 */

/*
 * Rules for verifying priceFunction 
 */

/* priceFunction is always at least minimumPrice and not more than startPrice */
rule currentPriceVal() {
	env e;
	uint128 startPrice;
    uint128 minimumPrice;
	uint64 startTime;
    uint64 endTime;
    uint128 totalTokens;

	startTime, endTime, totalTokens = marketInfo(e);
	startPrice, minimumPrice = marketPrice(e);
	
	require ( startTime < endTime  && minimumPrice > 0 && startPrice > minimumPrice);
	
	uint256 pricedrop = priceDrop(e);
	require pricedrop > 0;
	
	uint256 currentPrice = priceFunction(e);
	
	assert minimumPrice <= currentPrice && currentPrice <= startPrice ;
}


/* priceFunction is monotonically decreasing (on a bigger timestamp, the price is lower) */
rule priceFunctionDecreasesMonotonically() {
	env e1;
	env e2;

	uint128 startPrice;
    uint128 minimumPrice;
	uint64 startTime;
    uint64 endTime;
    uint128 totalTokens;
	uint128 commitmentsTotal;
    bool finalized;
    bool usePointList;

	startTime, endTime, totalTokens = marketInfo(e1);
	startPrice, minimumPrice = marketPrice(e1);
	
	require ( startTime < endTime  && minimumPrice > 0 && startPrice > minimumPrice  && isInitialized(e1));
	
	require e1.block.timestamp <= e2.block.timestamp;
	
	uint256 _priceFunction = priceFunction(e1);

	uint256 priceFunction_ = priceFunction(e2);

	assert (priceFunction_ <= _priceFunction);
}

rule tokenPriceIncreasesMonotonically(method f) filtered {f -> f.selector != batch(bytes[],bool).selector} {
	env e1;
	env e2;
	uint128 startPrice;
    uint128 minimumPrice;
	uint64 startTime;
    uint64 endTime;
    uint128 totalTokens;
	uint128 _commitmentsTotal;
	uint128 commitmentsTotal_;
    bool finalized;
    bool usePointList;
    
	startTime, endTime, totalTokens = marketInfo(e1);
	startPrice, minimumPrice = marketPrice(e1);
	
	require ( startTime < endTime  && minimumPrice > 0 && startPrice > minimumPrice  && isInitialized(e1));
	
	require e1.block.timestamp <= e2.block.timestamp;
	uint256 _tokenPrice = tokenPrice(e1);
	
	calldataarg args;
	f(e1, args);
	
	uint256 tokenPrice_ = tokenPrice(e2);


	assert (_tokenPrice <= tokenPrice_);
}