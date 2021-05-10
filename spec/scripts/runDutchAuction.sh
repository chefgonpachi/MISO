certoraRun spec/harness/DutchAuctionHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/DummyWeth.sol spec/harness/Receiver.sol \
	--verify DutchAuctionHarness:spec/dutchAuction.spec \
	--settings -assumeUnwindCond,-ignoreViewFunctions,-enableStorageAnalysis=true \
	--solc solc6.12 \
	--cache dutchAuction \
	--staging  --msg "dutch auction : all rules with fixes"