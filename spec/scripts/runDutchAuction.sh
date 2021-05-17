certoraRun spec/harness/DutchAuctionHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/DummyWeth.sol spec/harness/Receiver.sol spec/harness/Wallet.sol:Wallet \
	--verify DutchAuctionHarness:spec/dutchAuction.spec \
	--link DutchAuctionHarness:wallet=Wallet \
	--settings -assumeUnwindCond,-ignoreViewFunctions,-enableStorageAnalysis=true \
	--solc solc6.12 \
	--cache dutchAuction \
	--cloud --msg "dutch auction : all rules $1"