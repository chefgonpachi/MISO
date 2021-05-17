pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../contracts/Auctions/DutchAuction.sol";

contract DutchAuctionHarness is DutchAuction {
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    mapping(uint256 => uint256) public currentPrice;

   function _currentPrice() internal override view returns (uint256) {
        uint256 price = currentPrice[block.timestamp];
        require(price <= marketPrice.startPrice);
        require(price >= marketPrice.minimumPrice); 
        return price;
    }

    function clearingPrice() public override view returns (uint256) {
        uint256 tokenPrice_ = tokenPrice();
        uint256 priceFunction_ = tokenPrice();
        if (tokenPrice_ > priceFunction_) {
            return tokenPrice_;
        }
        return priceFunction_;
    }

    function assumeMonotonic(uint256 timestamp1, uint256 timestamp2) public view {
        require(timestamp1 <= timestamp2);
        require(currentPrice[timestamp1] <= currentPrice[timestamp1]);
    }

/*
    mapping(uint256 => uint256 ) public tokenPrice_;

    function tokenPrice() public override view returns (uint256) {
        return tokenPrice_[marketStatus.commitmentsTotal];
    }

    function assumeAdditiveTokenPrice(uint256 commitmentsTotal1, uint256 commitmentsTotal2) public view {
        require(tokenPrice_[commitmentsTotal1] + tokenPrice_[commitmentsTotal2] >= tokenPrice_[commitmentsTotal1] );
        require(commitmentsTotal1 + commitmentsTotal2 >= commitmentsTotal1 );
        require(tokenPrice_[commitmentsTotal1] + tokenPrice_[commitmentsTotal2] == tokenPrice_[commitmentsTotal1+commitmentsTotal2]);
    }
*/
  
    function tokenBalanceOf(address token, address user) public returns (uint256) {
        if (token == ETH_ADDRESS) {
                return address(user).balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }

    function getCommitmentsTotal() public returns (uint256) {
        return marketStatus.commitmentsTotal;
    }

    function batch(bytes[] calldata calls, bool revertOnFail) external override payable
             returns (bool[] memory successes, bytes[] memory results) { }

    function isFinalized() external returns (bool) {
        return marketStatus.finalized;
    }

    function getStartPrice() public returns (uint256) {
        return marketPrice.startPrice;
    }

    function isPaymentCurrencyETH() public view returns (bool) {
        return (paymentCurrency == ETH_ADDRESS);
    }
}