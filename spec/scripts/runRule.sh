certoraRun spec/harness/DutchAuctionHarness.sol:DutchAuctionHarness spec/harness/DummyERC20A.sol:DummyERC20A \
spec/harness/DummyERC20B.sol:DummyERC20B spec/harness/DummyWeth.sol:DummyWeth  spec/harness/Receiver.sol \
	--verify DutchAuctionHarness:spec/dutchAuction.spec \
	--settings -assumeUnwindCond,-ignoreViewFunctions,-enableStorageAnalysis=true \
	--solc solc6.12 \
	--rule preserveTotalAssetsOnCommit \
	--cache dutchAuction \
	--staging --msg "dutch auction : preserveTotalAssetsOnCommit"