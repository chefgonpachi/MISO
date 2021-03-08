pragma solidity 0.6.12;

//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
//  Hyperbolic Auction V1.3
//   Copyright (c) 2020 DutchSwap.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// ------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later                        
// ------------------------------------------------------------------------
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ███████ Instant ████████████████████████████████████████████████████████
// ███████████▀▀▀████████▀▀▀███████▀█████▀▀▀▀▀▀▀▀▀▀█████▀▀▀▀▀▀▀▀▀▀█████████
// ██████████ ▄█▓┐╙████╙ ▓█▄ ▓█████ ▐███  ▀▀▀▀▀▀▀▀████▌ ▓████████▓ ╟███████
// ███████▀╙ ▓████▄ ▀▀ ▄█████ ╙▀███ ▐███▀▀▀▀▀▀▀▀▀  ████ ╙▀▀▀▀▀▀▀▀╙ ▓███████
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ------------------------------------------------------------------------


// GP: Restory reentracy guard once code coverage is tested
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Utils/SafeTransfer.sol";
import "../../interfaces/IPointList.sol";
import "../Utils/Documents.sol";

contract HyperbolicAuction is SafeTransfer, Documents /*, ReentrancyGuard */ {
    using SafeMath for uint256;

    // MISOMarket template id.
    uint256 public constant marketTemplate = 4;
    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Main market variables.
    struct MarketInfo {
        uint64 startTime;
        uint64 endTime;
        uint128 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Market price variables.
    struct MarketPrice {
        uint128 minimumPrice;
        uint128 alpha;
        // GP: Can be added later as exponent factor
        // uint16 factor;
    }
    MarketPrice public marketPrice;

    /// @notice Market dynamic variables.
    struct MarketStatus {
        uint128 commitmentsTotal;
        bool initialized; 
        bool finalized;
        bool hasPointList;

    }
    MarketStatus public marketStatus;

    /// @notice The token being sold.
    address public auctionToken; 
    /// @notice The currency the auction accepts for payment. Can be ETH or token address.
    address public paymentCurrency;  
    /// @notice Where the auction funds will get paid.
    address payable public wallet;  
    /// @notice Address that can finalize auction.
    address public operator;
    /// @notice Address that manages auction approvals.
    address public pointList;

    /// @notice The commited amount of accounts.
    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;

    event AddedCommitment(address addr, uint256 commitment);

    /// @notice Event for finalization of the auction.
    event AuctionFinalized();

    /**
     * @notice Initializes main contract variables and transfers funds for the auction.
     * @dev Init function
     * @param _funder The address that funds the token for crowdsale
     * @param _token Address of the token being sold
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address
     * @param _totalTokens The total number of tokens to sell in auction
     * @param _startTime Auction start time
     * @param _endTime Auction end time
     * @param _factor Inflection point of the auction
     * @param _minimumPrice The minimum auction price
     * @param _operator Address that can finalize auction.
     * @param _pointList Address that will manage auction approvals.
     * @param _wallet Address where collected funds will be forwarded to
     */
    function initAuction(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _factor,
        uint256 _minimumPrice,
        address _operator,
        address _pointList,
        address payable _wallet
    ) public {
        require(!marketStatus.initialized, "HyperbolicAuction: auction already initialized");
        require(_startTime >= block.timestamp, "HyperbolicAuction: start time is before current time");
        require(_totalTokens > 0,"HyperbolicAuction: total tokens must be greater than zero");
        require(_endTime > _startTime, "HyperbolicAuction: end time must be older than start price");
        require(_minimumPrice > 0, "HyperbolicAuction: minimum price must be greater than 0"); 
        require(_wallet != address(0), "HyperbolicAuction: wallet is the zero address");
        require(_operator != address(0), "HyperbolicAuction: operator is the zero address");
        require(_token != address(0), "HyperbolicAuction: token is the zero address");

   
        // GP: consider checking tokens for different decimals
        
        marketInfo.startTime = uint64(_startTime);
        marketInfo.endTime = uint64(_endTime);
        marketInfo.totalTokens = uint128(_totalTokens);

        marketPrice.minimumPrice = uint128(_minimumPrice);

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        wallet = _wallet;
        operator = _operator;
        
        if (_pointList != address(0)) {
            pointList = _pointList;
            marketStatus.hasPointList = true;
        }

         // factor = exponent which can later be used to alter the curve
        uint256 _duration = _endTime - _startTime;
        uint256 _alpha = _duration.mul(_minimumPrice);
        require (_alpha > 0);
        marketPrice.alpha = uint128(_alpha);

        _safeTransferFrom(_token, _funder, _totalTokens);
        marketStatus.initialized = true;
    }


    ///--------------------------------------------------------
    /// Auction Pricing
    ///--------------------------------------------------------

    /**
     * @notice Calculates the average price of each token from all commitments.
     * @return Average token price.
     */
    function tokenPrice() public view returns (uint256) {
        return uint256(marketStatus.commitmentsTotal).mul(1e18).div(uint256(marketInfo.totalTokens));
    }

    /**
     * @notice Returns auction price in any time.
     * @return Fixed start price or minimum price if outside of auction time, otherwise calculated current price.
     */
    function priceFunction() public view returns (uint256) {
        /// @dev Return Auction Price
        if (block.timestamp <= uint256(marketInfo.startTime)) {
            return uint256(-1);
        }
        if (block.timestamp >= uint256(marketInfo.endTime)) {
            return uint256(marketPrice.minimumPrice);
        }
        return _currentPrice();
    }

    /// @notice The current clearing price of the Hyperbolic auction
    function clearingPrice() public view returns (uint256) {
        /// @dev If auction successful, return tokenPrice
        if (tokenPrice() > priceFunction()) {
            return tokenPrice();
        }
        return priceFunction();
    }

    /**
     * @notice Calculates price during the auction.
     * @return Current auction price.
     */
    function _currentPrice() private view returns (uint256) {
        uint256 elapsed = block.timestamp.sub(uint256(marketInfo.startTime));
        uint256 currentPrice = uint256(marketPrice.alpha).div(elapsed);
        return currentPrice;
    }

    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    /**
     * @notice Buy Tokens by committing ETH to this contract address
     * @dev Needs sufficient gas limit for additional state changes
     */
    receive() external payable {
        // revertBecauseUserDidNotProvideAgreement();
        // GP: Allow token direct transfers for testnet
        commitEth(msg.sender, true);
    }

    function marketParticipationAgreement() public pure returns (string memory) {
        return "I understand that I'm interacting with a smart contract. I understand that tokens commited are subject to the token issuer and local laws where applicable. I reviewed code of the smart contract and understand it fully. I agree to not hold developers or other people associated with the project liable for any losses or misunderstandings";
    }
    /** 
     * @dev Not using modifiers is a purposeful choice for code readability.
    */ 
    function revertBecauseUserDidNotProvideAgreement() internal pure {
        revert("No agreement provided, please review the smart contract before interacting with it");
    }

    /**
     * @notice Checks the amount of ETH to commit and adds the commitment. Refunds the buyer if commit is too high.
     * @param _beneficiary Auction participant ETH address.
     */
    function commitEth(
        address payable _beneficiary,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public payable
    {
        require(paymentCurrency == ETH_ADDRESS, "HyperbolicAuction: payment currency is not ETH address"); 
        // Get ETH able to be committed
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        require(msg.value > 0, "HyperbolicAuction: Value must be higher than 0");
        uint256 ethToTransfer = calculateCommitment(msg.value);

        /// @notice Accept ETH Payments.
        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _addCommitment(_beneficiary, ethToTransfer);
        }
        /// @notice Return any ETH to be refunded.
        if (ethToRefund > 0) {
            _beneficiary.transfer(ethToRefund);
        }
    }

    /**
     * @notice Buy Tokens by commiting approved ERC20 tokens to this contract address.
     * @param _amount Amount of tokens to commit.
     */
    function commitTokens(uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public {
        commitTokensFrom(msg.sender, _amount, readAndAgreedToMarketParticipationAgreement);
    }

    /// @dev Users must approve contract prior to committing tokens to auction
    function commitTokensFrom(
        address _from,
        uint256 _amount,
        bool readAndAgreedToMarketParticipationAgreement
    )
        public /* nonReentrant */ 
    {
        require(paymentCurrency != ETH_ADDRESS, "HyperbolicAuction: payment currency is not a token");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        require(_amount> 0, "HyperbolicAuction: Value must be higher than 0");
        uint256 tokensToTransfer = calculateCommitment(_amount);
        if (tokensToTransfer > 0) {
            _safeTransferFrom(paymentCurrency, _from, tokensToTransfer);
            _addCommitment(_from, tokensToTransfer);
        }
    }

    /**
     * @notice Calculates total amount of tokens committed at current auction price.
     * @return Number of tokens commited.
     */
    function totalTokensCommitted() public view returns (uint256) {
        return uint256(marketStatus.commitmentsTotal).mul(1e18).div(clearingPrice());
    }

    /**
     * @notice Calculates the amout able to be committed during an auction.
     * @param _commitment Commitment user would like to make.
     * @return Amount allowed to commit.
     */
    function calculateCommitment(uint256 _commitment) public view returns (uint256 ) {
        uint256 maxCommitment = uint256(marketInfo.totalTokens).mul(clearingPrice()).div(1e18);
        if (uint256(marketStatus.commitmentsTotal).add(_commitment) > maxCommitment) {
            return maxCommitment.sub(uint256(marketStatus.commitmentsTotal));
        }
        return _commitment;
    }


    /**
     * @notice Updates commitment for this address and total commitment of the auction.
     * @param _addr Bidders address.
     * @param _commitment The amount to commit.
     */
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime), "HyperbolicAuction: outside auction hours"); 
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "HyperbolicAuction: auction already finalized");

        uint256 newCommitment = commitments[_addr].add(_commitment);
        if (status.hasPointList) {
            require(IPointList(pointList).hasPoints(_addr, newCommitment));
        }

        commitments[_addr] = newCommitment;
        status.commitmentsTotal = uint128(uint256(status.commitmentsTotal).add(_commitment));
        emit AddedCommitment(_addr, _commitment);
    }


    ///--------------------------------------------------------
    /// Finalize Auction
    ///--------------------------------------------------------

    /**
     * @notice Successful if tokens sold equals totalTokens.
     * @return True if tokenPrice is bigger or equal clearingPrice.
     */
    function auctionSuccessful() public view returns (bool) {
        return tokenPrice() >= clearingPrice();
    }

    /**
     * @notice Checks if the auction has ended.
     * @return True if auction is successful or time has ended.
     */
    function auctionEnded() public view returns (bool) {
        return auctionSuccessful() || block.timestamp > uint256(marketInfo.endTime);
    }

    /**
     * @return Returns true if market has been finalized
     */
    function finalized() public view returns (bool) {
        return marketStatus.finalized;
    }

    /**
     * @return Returns true if 14 days have passed since the end of the auction
     */
    function finalizeTimeExpired() public view returns (bool) {
        return uint256(marketInfo.endTime) + 14 days < block.timestamp;
    }

    /**
     * @notice Auction finishes successfully above the reserve
     * @dev Transfer contract funds to initialized wallet.
     */
    function finalizeAuction()
        public /* nonReentrant */
    {
        require(msg.sender == operator || finalizeTimeExpired(), "HyperbolicAuction: sender must be an operator");
        MarketStatus storage status = marketStatus;
        MarketInfo storage info = marketInfo;

        require(!status.finalized, "HyperbolicAuction: auction already finalized");
        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _tokenPayment(paymentCurrency, wallet, uint256(status.commitmentsTotal));
        } else if ( block.timestamp <= uint256(info.startTime) ) {
            /// @dev Cancelled Auction
            /// @dev You can cancel the auction before it starts
            require( uint256(status.commitmentsTotal) == 0, "HyperbolicAuction: auction already committed" );
            _tokenPayment(auctionToken, wallet, uint256(info.totalTokens));
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(block.timestamp > uint256(info.endTime), "HyperbolicAuction: auction has not finished yet"); 
            _tokenPayment(auctionToken, wallet, uint256(info.totalTokens));
        }
        status.finalized = true;
        emit AuctionFinalized();
    }

    /** 
     * @notice How many tokens the user is able to claim.
     * @param _user Auction participant address.
     * @return User commitments reduced by already claimed tokens.
     */
    function tokensClaimable(address _user) public view returns (uint256) {
        uint256 tokensAvailable = commitments[_user].mul(1e18).div(clearingPrice());
        return tokensAvailable.sub(claimed[msg.sender]);
    }


   /// @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
    function withdrawTokens() public  {
        withdrawTokens(msg.sender);
    }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens(address payable beneficiary) 
        public /* nonReentrant */
    {
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "HyperbolicAuction: not finalized");
            /// @dev Successful auction! Transfer claimed tokens.
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "HyperbolicAuction: no tokens to claim"); 
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);

            _tokenPayment(auctionToken, beneficiary, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > uint256(marketInfo.endTime), "HyperbolicAuction: auction has not finished yet");
            uint256 fundsCommitted = commitments[beneficiary];
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            _tokenPayment(paymentCurrency, beneficiary, fundsCommitted);
        }
    }

    //--------------------------------------------------------
    // Documents
    //--------------------------------------------------------

    function setDocument(bytes32 _name, string calldata _uri, bytes32 _documentHash) external {
        require(msg.sender == operator);
        _setDocument( _name, _uri, _documentHash);
    }

    function removeDocument(bytes32 _name) external {
        require(msg.sender == operator);
        _removeDocument(_name);
    }


    ///--------------------------------------------------------
    /// Market Launchers
    ///--------------------------------------------------------

    /**
     * @notice Decodes and hands auction data to the initAuction function.
     * @param _data Encoded data for initialization.
     */
    function initMarket(bytes calldata _data) public {
        (
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _factor,
        uint256 _minimumPrice,
        address _operator,
        address _pointList,
        address payable _wallet
        ) = abi.decode(_data, (
            address,
            address,
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            address,
            address,
            address
        ));
        initAuction(_funder, _token, _totalTokens, _startTime, _endTime, _paymentCurrency, _factor, _minimumPrice, _operator, _pointList, _wallet);
    }

    /**
     * @notice Collects data to initialize the auction and encodes them.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _totalTokens The total number of tokens to sell in auction.
     * @param _startTime Auction start time.
     * @param _endTime Auction end time.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _factor Inflection point of the auction.
     * @param _minimumPrice The minimum auction price.
     * @param _wallet Address where collected funds will be forwarded to.
     * @return _data All the data in bytes format.
     */
    function getAuctionInitData(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _factor,
        uint256 _minimumPrice,
        address _operator,
        address _pointList,
        address payable _wallet
    )
        external pure returns (bytes memory _data) {
            return abi.encode(
                _funder,
                _token,
                _totalTokens,
                _startTime,
                _endTime,
                _paymentCurrency,
                _factor,
                _minimumPrice,
                _operator,
                _pointList,
                _wallet
            );
        }
}
