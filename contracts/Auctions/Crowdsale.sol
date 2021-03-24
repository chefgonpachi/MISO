pragma solidity 0.6.12;

//----------------------------------------------------------------------------------
//    I n s t a n t
//
//        .:mmm.         .:mmm:.       .ii.  .:SSSSSSSSSSSSS.     .oOOOOOOOOOOOo.  
//      .mMM'':Mm.     .:MM'':Mm:.     .II:  :SSs..........     .oOO'''''''''''OOo.
//    .:Mm'   ':Mm.   .:Mm'   'MM:.    .II:  'sSSSSSSSSSSSSS:.  :OO.           .OO:
//  .'mMm'     ':MM:.:MMm'     ':MM:.  .II:  .:...........:SS.  'OOo:.........:oOO'
//  'mMm'        ':MMmm'         'mMm:  II:  'sSSSSSSSSSSSSS'     'oOOOOOOOOOOOO'  
//
//----------------------------------------------------------------------------------


import "../../interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Utils/SafeTransfer.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../interfaces/IPointList.sol";
import "../../interfaces/IERC20.sol";
import "../Utils/Documents.sol";

/// @notice Attribution to delta.financial


contract Crowdsale is SafeTransfer, Documents , ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice MISOMarket template id for the factory contract.
    uint256 public constant marketTemplate = 1;

    /// @notice The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /** 
    * @notice rate - How many token units a buyer gets per token or wei.
    * The rate is the conversion between wei and the smallest and indivisible token unit.
    * So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    * 1 wei will give you 1 unit, or 0.001 TOK.
    */
    /// @notice goal - Minimum amount of funds to be raised in weis or tokens.
    struct MarketPrice {
        uint128 rate;
        uint128 goal; 
    }
    MarketPrice public marketPrice;

    /// @notice Starting time of crowdsale.
    /// @notice Ending time of crowdsale.
    /// @notice Total number of tokens to sell.
    struct MarketInfo {
        uint64 startTime;
        uint64 endTime; 
        uint128 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Amount of wei raised.
    /// @notice Whether crowdsale has been initialized or not.
    /// @notice Whether crowdsale has been finalized or not.
    struct MarketStatus {
        uint128 amountRaised;
        bool initialized; 
        bool finalized;
        bool hasPointList;
    }
    MarketStatus public marketStatus;

    /// @notice The token being sold.
    address public auctionToken;
    /// @notice Address where funds are collected.
    address payable private wallet;
    /// @notice The currency the crowdsale accepts for payment. Can be ETH or token address.
    address public paymentCurrency;
    /// @notice Address that can finalize crowdsale.
    address public operator;
    /// @notice Address that manages auction approvals.
    address public pointList;

    /// @notice The commited amount of accounts.
    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;

    /**
     * @notice Event for token purchase logging.
     * @param purchaser Who paid for the tokens.
     * @param beneficiary Who got the tokens.
     * @param value Value of wei or token paid for purchase.
     * @param amount Amount of tokens purchased.
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    /// @notice Event for finalization of the crowdsale
    event CrowdsaleFinalized();

    /**
     * @notice Initializes main contract variables and transfers funds for the sale.
     * @dev Init function.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _totalTokens The total number of tokens to sell in crowdsale.
     * @param _startTime Crowdsale start time.
     * @param _endTime Crowdsale end time.
     * @param _rate Number of token units a buyer gets per wei or token.
     * @param _goal Minimum amount of funds to be raised in weis or tokens.
     * @param _operator Address that can finalize crowdsale.
     * @param _pointList Address that will manage auction approvals.
     * @param _wallet Address where collected funds will be forwarded to.
     */
    function initCrowdsale(
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _operator,
        address _pointList,
        address payable _wallet
    ) public {
        require(!marketStatus.initialized, "Crowdsale: already initialized"); 
        require(_startTime < 10000000000, 'Crowdsale: enter an unix timestamp in seconds, not miliseconds');
        require(_endTime < 10000000000, 'Crowdsale: enter an unix timestamp in seconds, not miliseconds');
        require(_startTime >= block.timestamp, "Crowdsale: start time is before current time");
        require(_endTime > _startTime, "Crowdsale: start time is not before end time");
        require(_rate > 0, "Crowdsale: rate is 0");
        require(_paymentCurrency != address(0), "Crowdsale: payment currency is the zero address");
        require(_wallet != address(0), "Crowdsale: wallet is the zero address");
        require(_operator != address(0), "Crowdsale: operator is the zero address");
        require(_totalTokens > 0, "Crowdsale: total tokens is 0");
        require(_goal > 0, "Crowdsale: goal is 0");
        require(IERC20(_token).decimals() == 18, "Crowdsale: Token does not have 18 decimals");

        marketPrice.rate = uint128(_rate);
        marketPrice.goal = uint128(_goal);

        marketInfo.startTime = uint64(_startTime);
        marketInfo.endTime = uint64(_endTime);
        marketInfo.totalTokens = uint128(_totalTokens);

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        wallet = _wallet;
        operator = _operator;

        _setList(_pointList);
        
        require(_getTokenAmount(_goal) <= _totalTokens, "Crowdsale: goal should be equal to or lower than total tokens or equal");

        _safeTransferFrom(_token, _funder, _totalTokens);
        marketStatus.initialized = true;
    }


    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    receive() external payable {
        // revertBecauseUserDidNotProvideAgreement();
        // GP: Allow token direct transfers for testnet
        buyTokensEth(msg.sender, true);
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
     * @notice Checks the amount to commit and processes the buy. Refunds the buyer if commit is too high.
     * @dev low level token purchase with ETH ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param _beneficiary Recipient of the token purchase.
     */
    function buyTokensEth(
        address payable _beneficiary,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public payable nonReentrant   
    {
        require(paymentCurrency == ETH_ADDRESS, "Crowdsale: payment currency is not ETH"); 
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        _preValidatePurchase(_beneficiary, msg.value);

        /// @notice Get ETH able to be committed.
        uint256 ethToTransfer = calculateCommitment(msg.value);

        /// @notice Accept ETH Payments.
        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _processBuy(_beneficiary, ethToTransfer);
        }

        /// @notice Return any ETH to be refunded.
        if (ethToRefund > 0) {
            _beneficiary.transfer(ethToRefund);
        }
    }

    /**
     * @notice Checks if the commitment doesn't exceed the goal of this sale.
     * @param _commitment Number of tokens to be commited.
     * @return committed The amount able to be purchased during a sale.
     */
    function calculateCommitment(uint256 _commitment)
        public
        view
        returns (uint256 committed)
    {
        if (uint256(marketStatus.amountRaised).add(_commitment) > uint256(marketPrice.goal)) {
            return uint256(marketPrice.goal).sub(uint256(marketStatus.amountRaised));
        }
        return _commitment;
    }

    /**
     * @notice Prevalidates purchase, transfers funds and processes the buy.
     * @dev Low level token purchase with a token ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param _beneficiary Recipient of the token purchase.
     * @param _tokenAmount Value in wei or token involved in the purchase.
     */
    function buyTokens(
        address _beneficiary,
        uint256 _tokenAmount,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public nonReentrant 
    {
        require(paymentCurrency != ETH_ADDRESS, "Crowdsale: payment currency is not token");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        _preValidatePurchase(_beneficiary, _tokenAmount);
        _safeTransferFrom(paymentCurrency, msg.sender, _tokenAmount);
        _processBuy(_beneficiary, _tokenAmount);
    }

    /**
     * @notice Updates commitment of the buyer and the amount raised, emits an event.
     * @param beneficiary Recipient of the token purchase.
     * @param amount Value in wei or token involved in the purchase.
     */
    function _processBuy(address beneficiary, uint256 amount) internal {
        commitments[beneficiary] = commitments[beneficiary].add(amount);

        /// @notice Update state.
        // update state
        marketStatus.amountRaised = uint128(uint256(marketStatus.amountRaised).add(amount));

        emit TokensPurchased(msg.sender, beneficiary, amount, _getTokenAmount(amount));
    }

    /**
     * @notice Validation of an incoming purchase.
     * @param beneficiary Address performing the token purchase.
     * @param amount Value in wei or token involved in the purchase.
     */
    function _preValidatePurchase(address beneficiary, uint256 amount) internal view {
        require(block.timestamp >= uint256(marketInfo.startTime), "Crowdsale: not started");
        require(block.timestamp <= uint256(marketInfo.endTime), "Crowdsale: already closed");
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(amount != 0, "Crowdsale: amount is 0");
        if (marketStatus.hasPointList) {
            uint256 newCommitment = commitments[beneficiary].add(amount);
            require(IPointList(pointList).hasPoints(beneficiary, newCommitment));
        }
        uint256 tokensAvail = IERC20(auctionToken).balanceOf(address(this));
        require(_getTokenAmount(uint256(marketStatus.amountRaised).add(amount)) <= tokensAvail, "Crowdsale: amount of tokens exceeded");
    }

    function withdrawTokens() public  {
        withdrawTokens(msg.sender);
    }

    /**
     * @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
     * @dev Withdraw tokens only after crowdsale ends.
     * @param beneficiary Whose tokens will be withdrawn.
     */
    // GP: Think about moving to a safe transfer that considers the dust for the last withdraw
    function withdrawTokens(address payable beneficiary) public nonReentrant {    
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "Crowdsale: not finalized");
            /// @dev Successful auction! Transfer claimed tokens.
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "Crowdsale: no tokens to claim"); 
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);
            _tokenPayment(auctionToken, beneficiary, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.

            require(block.timestamp > uint256(marketInfo.endTime), "Crowdsale: auction has not finished yet");
            uint256 accountBalance = commitments[beneficiary];
            /// @dev claimerBalance = tokensClaimable(beneficiary);
            /// @dev claimAmount = claimerBalance.div(uint256(marketPrice.rate));
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            _tokenPayment(paymentCurrency, beneficiary, accountBalance);
        }
    }

    /**
     * @notice Adjusts users commitment depending on amount already claimed and unclaimed tokens left.
     * @return claimerCommitment How many tokens the user is able to claim.
     */
    function tokensClaimable(address _user) public view returns (uint256 claimerCommitment) {
        uint256 unclaimedTokens = IERC20(auctionToken).balanceOf(address(this));
        claimerCommitment = _getTokenAmount(commitments[_user]);
        claimerCommitment = claimerCommitment.sub(claimed[_user]);
        /// @dev MZ: Is this good to calculate dust for last withdraw?
        /// @dev Does not transfer back the equivalent amount of dust.
        if(claimerCommitment > unclaimedTokens){
            claimerCommitment = unclaimedTokens;
        }
    }
    
    //--------------------------------------------------------
    // Finalize Auction
    //--------------------------------------------------------
    
    /**
     * @notice Manually finalizes the Crowdsale.
     * @dev Must be called after crowdsale ends, to do some extra finalization work.
     * Calls the contracts finalization function.
     */
    function finalize() public {
        require(            
            msg.sender == operator || finalizeTimeExpired(),
            "Crowdsale: sender must be an operator"
        );
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "Crowdsale: already finalized");
        MarketInfo storage info = marketInfo;

        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            require(auctionEnded(), "Crowdsale: Has not finished yet"); 
            _tokenPayment(paymentCurrency, wallet, uint256(status.amountRaised));
            /// @dev Transfer unsold tokens to wallet.
            uint256 soldTokens = _getTokenAmount(uint256(status.amountRaised));
            uint256 unsoldTokens = uint256(info.totalTokens).sub(soldTokens);
            if(unsoldTokens > 0) {
                _tokenPayment(auctionToken, wallet, unsoldTokens);
            }
        } else if ( block.timestamp <= uint256(info.startTime) ) {
            /// @dev Cancelled Auction
            /// @dev You can cancel the auction before it starts
            require( uint256(status.amountRaised) == 0, "Crowdsale: Funds already raised" );
            _tokenPayment(auctionToken, wallet, uint256(info.totalTokens));
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(auctionEnded(), "Crowdsale: Has not finished yet"); 
            _tokenPayment(auctionToken, wallet, uint256(info.totalTokens));
        }

        status.finalized = true;

        emit CrowdsaleFinalized();
    }

    /**
     * @notice Calculates the number of tokens to purchase.
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param amount Value in wei or token to be converted into tokens.
     * @return tokenAmount Number of tokens that can be purchased with the specified amount.
     */
    function _getTokenAmount(uint256 amount) internal view returns (uint256) {
        return amount.mul(uint256(marketPrice.rate));
    }

    /**
     * @notice Checks if the sale is open.
     * @return isOpen True if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        return block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime);
    }

    /**
     * @notice Checks if the sale minimum amount was raised.
     * @return auctionSuccessful True if the amountRaised is equal or higher than goal.
     */
    function auctionSuccessful() public view returns (bool) {
        return uint256(marketStatus.amountRaised) >= uint256(marketPrice.goal);
    }

    /**
     * @notice Checks if the sale has ended.
     * @return auctionEnded True if successful or time has ended.
     */
    function auctionEnded() public view returns (bool) {
        return block.timestamp > uint256(marketInfo.endTime) || _getTokenAmount(uint256(marketStatus.amountRaised)) == uint256(marketInfo.totalTokens);
    }

    /**
     * @return Returns true if market has been finalized
     */
    function finalized() public view returns (bool) {
        return marketStatus.finalized;
    }

    /**
     * @return True if 7 days have passed since the end of the auction
    */
    function finalizeTimeExpired() public view returns (bool) {
        return uint256(marketInfo.endTime) + 14 days < block.timestamp;
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

    //--------------------------------------------------------
    // Point Lists
    //--------------------------------------------------------

    function setList(address _list) external {
        require(msg.sender == operator);
        _setList(_list);
    }

    function enableList(bool _status) external {
        require(msg.sender == operator);
        marketStatus.hasPointList = _status;
    }

    function _setList(address _pointList) private {
        if (_pointList != address(0)) {
            pointList = _pointList;
            marketStatus.hasPointList = true;
        }
    }

    //--------------------------------------------------------
    // Market Launchers
    //--------------------------------------------------------


    /**
     * @notice Decodes and hands Crowdsale data to the initCrowdsale function.
     * @param _data Encoded data for initialization.
     */
    function initMarket(bytes calldata _data) public {
        (
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _operator,
        address _pointList,
        address payable _wallet
        ) = abi.decode(_data, (
            address,
            address,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            address,
            address
            )
        );
    
        initCrowdsale(_funder, _token, _paymentCurrency, _totalTokens, _startTime, _endTime, _rate, _goal, _operator, _pointList, _wallet);
    }

    /**
     * @notice Collects data to initialize the crowd sale.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _totalTokens The total number of tokens to sell in crowdsale.
     * @param _startTime Crowdsale start time.
     * @param _endTime Crowdsale end time.
     * @param _rate Number of token units a buyer gets per wei or token.
     * @param _goal Minimum amount of funds to be raised in weis or tokens.
     * @param _operator Address that can finalize crowdsale.
     * @param _pointList Address that will manage auction approvals.
     * @param _wallet Address where collected funds will be forwarded to.
     * @return _data All the data in bytes format.
     */
    function getCrowdsaleInitData(
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _operator,
        address _pointList,
        address payable _wallet
    )
        external pure returns (bytes memory _data)
    {
        return abi.encode(
            _funder,
            _token,
            _paymentCurrency,
            _totalTokens,
            _startTime,
            _endTime,
            _rate,
            _goal,
            _operator,
            _pointList,
            _wallet
            );
    }
    
    function getBaseInformation() external view returns(
        address, 
        uint64,
        uint64,
        bool 
    ) {
        return (auctionToken, marketInfo.startTime, marketInfo.endTime, marketStatus.finalized);
    }
}
