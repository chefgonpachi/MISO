certoraRun spec/harness/DutchAuctionSimplifyAdmin.sol \
	--verify DutchAuctionSimplifyAdmin:spec/dutchAuctionCurrentPrice.spec \
	--solc solc6.12 \
	--cache dutchAuctionPrice  \
	--settings -assumeUnwindCond \
	--cloud  --msg "dutch auction price function : all rules"