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


import "../OpenZeppelin/utils/ReentrancyGuard.sol";
import "../OpenZeppelin/math/SafeMath.sol";
import "../Utils/SafeTransfer.sol";
import "../Utils/Documents.sol";
import "../../interfaces/IPointList.sol";
import "../../interfaces/IERC20.sol";

/// @notice Attribution to delta.financial


contract BatchAuction is SafeTransfer, Documents, ReentrancyGuard  {
    using SafeMath for uint256;

    /// @notice MISOMarket template id for the factory contract.
    uint256 public constant marketTemplate = 3;

    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Main market variables.
    struct MarketInfo {
        uint64 startTime;
        uint64 endTime; 
        uint128 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Market dynamic variables.
    struct MarketStatus {
        uint256 commitmentsTotal;
        uint256 minimumCommitmentAmount;
        bool initialized; 
        bool finalized;
        bool hasPointList;
    }

    MarketStatus public marketStatus;

    address public auctionToken;
    /// @notice The currency the crowdsale accepts for payment. Can be ETH or token address.
    address public paymentCurrency;
    /// @notice Address that can finalize auction.
    address public operator;
    /// @notice Address that manages auction approvals.
    address public pointList;
    address payable public wallet; // Where the auction funds will get paid

    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;

    /// @notice Event for adding a commitment.
    event AddedCommitment(address addr, uint256 commitment);
    /// @notice Event for finalization of the auction.
    event AuctionFinalized();

    /**
     * @notice Initializes main contract variables and transfers funds for the auction.
     * @dev Init function.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _totalTokens The total number of tokens to sell in auction.
     * @param _startTime Auction start time.
     * @param _endTime Auction end time.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _minimumCommitmentAmount Minimum amount user can commit in auction.
     * @param _operator Address that can finalize auction.
     * @param _wallet Address where collected funds will be forwarded to.
     */
    function initAuction(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _minimumCommitmentAmount,
        address _operator,
        address _pointList,
        address payable _wallet
    ) public {
        require(!marketStatus.initialized, "BatchAuction: auction already initialized");
        require(_startTime < 10000000000, 'BatchAuction: enter an unix timestamp in seconds, not miliseconds');
        require(_endTime < 10000000000, 'BatchAuction: enter an unix timestamp in seconds, not miliseconds');
        require(_startTime >= block.timestamp, "BatchAuction: start time is before current time");
        require(_endTime > _startTime, "BatchAuction: end time must be older than start price");
        require(_totalTokens > 0,"BatchAuction: total tokens must be greater than zero");
        require(_paymentCurrency != address(0), "BatchAuction: payment currency is the zero address");
        require(_operator != address(0), "BatchAuction: operator is the zero address");
        require(_wallet != address(0), "BatchAuction: wallet is the zero address");
        require(IERC20(_token).decimals() == 18, "BatchAuction: Token does not have 18 decimals");

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        marketStatus.minimumCommitmentAmount = _minimumCommitmentAmount;
        
        marketInfo.startTime = uint64(_startTime);
        marketInfo.endTime = uint64(_endTime);
        marketInfo.totalTokens = uint128(_totalTokens);

        operator = _operator;
        wallet = _wallet;

        _setList(_pointList);
        _safeTransferFrom(auctionToken, _funder, _totalTokens);

        marketStatus.initialized = true;
    }


    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    receive() external payable {
        revertBecauseUserDidNotProvideAgreement();
    }
    
    /** 
     * @dev Attribution to the awesome delta.financial contracts
    */  
    function marketParticipationAgreement() public pure returns (string memory) {
        return "I understand that I'm interacting with a smart contract. I understand that tokens commited are subject to the token issuer and local laws where applicable. I have reviewed the code of this smart contract and understand it fully. I agree to not hold developers or other people associated with the project liable for any losses or misunderstandings";
    }
    /** 
     * @dev Not using modifiers is a purposeful choice for code readability.
    */ 
    function revertBecauseUserDidNotProvideAgreement() internal pure {
        revert("No agreement provided, please review the smart contract before interacting with it");
    }

    /**
     * @notice Commit ETH to buy tokens on auction.
     * @param _beneficiary Auction participant ETH address.
     */
    function commitEth(address payable _beneficiary, bool readAndAgreedToMarketParticipationAgreement) public payable {
        require(paymentCurrency == ETH_ADDRESS, "BatchAuction: payment currency is not ETH");

        require(msg.value > 0, "BatchAuction: Value must be higher than 0");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        _addCommitment(_beneficiary, msg.value);
    }

    /**
     * @notice Buy Tokens by commiting approved ERC20 tokens to this contract address.
     * @param _amount Amount of tokens to commit.
     */
    function commitTokens(uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public {
        commitTokensFrom(msg.sender, _amount, readAndAgreedToMarketParticipationAgreement);
    }

    /**
     * @notice Checks if amout not 0 and makes the transfer and adds commitment.
     * @dev Users must approve contract prior to committing tokens to auction.
     * @param _from User ERC20 address.
     * @param _amount Amount of approved ERC20 tokens.
     */
    function commitTokensFrom(address _from, uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public   nonReentrant  {
        /// @dev Isn't "paymentCurrency == ETH_ADDRESS" enough?
        require(paymentCurrency != ETH_ADDRESS, "BatchAuction: Payment currency is not a token");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        require(_amount> 0, "BatchAuction: Value must be higher than 0");
        _safeTransferFrom(paymentCurrency, _from, _amount);
        _addCommitment(_from, _amount);

    }


    /// @notice Commits to an amount during an auction
    /**
     * @notice Updates commitment for this address and total commitment of the auction.
     * @param _addr Auction participant address.
     * @param _commitment The amount to commit.
     */
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(block.timestamp >= marketInfo.startTime && block.timestamp <= marketInfo.endTime, "BatchAuction: outside auction hours"); 

        uint256 newCommitment = commitments[_addr].add(_commitment);
        if (marketStatus.hasPointList) {
            require(IPointList(pointList).hasPoints(_addr, newCommitment));
        }
        commitments[_addr] = newCommitment;
        marketStatus.commitmentsTotal = marketStatus.commitmentsTotal.add(_commitment);
        emit AddedCommitment(_addr, _commitment);
    }

    /**
     * @notice Calculates amount of auction tokens for user to receive.
     * @param amount Amount of tokens to commit.
     * @return Auction token amount.
     */
    function _getTokenAmount(uint256 amount) internal view returns (uint256) { 
        if (marketStatus.commitmentsTotal == 0) return 0;
        return amount.mul(1e18).div(tokenPrice());
    }

    /**
     * @notice Calculates the price of each token from all commitments.
     * @return Token price.
     */
    function tokenPrice() public view returns (uint256) {
        return marketStatus.commitmentsTotal.mul(1e18).div(uint256(marketInfo.totalTokens));
    }


    ///--------------------------------------------------------
    /// Finalize Auction
    ///--------------------------------------------------------

    /// @notice Auction finishes successfully above the reserve
    /// @dev Transfer contract funds to initialized wallet.
    function finalize() public    nonReentrant 
    {
        require(msg.sender == operator || finalizeTimeExpired(),  "BatchAuction: Sender must be operator");
        require(!marketStatus.finalized, "BatchAuction: Auction has already finalized");
        require(block.timestamp > marketInfo.endTime, "BatchAuction: Auction has not finished yet");
        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _tokenPayment(paymentCurrency, wallet, marketStatus.commitmentsTotal);
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(block.timestamp > marketInfo.endTime, "BatchAuction: Auction has not finished yet");
            _tokenPayment(auctionToken, wallet, marketInfo.totalTokens);
        }
        marketStatus.finalized = true;
        emit AuctionFinalized();
    }

    /// @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
    function withdrawTokens() public  {
        withdrawTokens(msg.sender);
    }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens(address payable beneficiary) public   nonReentrant  {
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "BatchAuction: not finalized");
            /// @dev Successful auction! Transfer claimed tokens.
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "BatchAuction: No tokens to claim");
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);

            _tokenPayment(auctionToken, beneficiary, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > marketInfo.endTime, "BatchAuction: Auction has not finished yet");
            uint256 fundsCommitted = commitments[beneficiary];
            require(fundsCommitted > 0, "BatchAuction: No funds committed");
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            _tokenPayment(paymentCurrency, beneficiary, fundsCommitted);
        }
    }


    /**
     * @notice How many tokens the user is able to claim.
     * @param _user Auction participant address.
     * @return Tokens left to claim.
     */
    function tokensClaimable(address _user) public view returns (uint256) {
        if (commitments[_user] == 0) return 0;
        uint256 tokensAvailable = _getTokenAmount(commitments[_user]);
        return tokensAvailable.sub(claimed[_user]);
    }

    /**
     * @notice Checks if raised more than minimum amount.
     * @return True if tokens sold greater than or equals to the minimum commitment amount.
     */
    function auctionSuccessful() public view returns (bool) {
        return marketStatus.commitmentsTotal >= marketStatus.minimumCommitmentAmount && marketStatus.commitmentsTotal > 0;
    }

    /**
     * @notice Checks if the auction has ended.
     * @return True if current time is greater than auction end time.
     */
    function auctionEnded() public view returns (bool) {
        return block.timestamp > marketInfo.endTime;
    }


    /// @notice Returns true if 7 days have passed since the end of the auction
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


    function initMarket(
        bytes calldata _data
    ) public {
        (
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _minimumCommitmentAmount,
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
            address,
            address,
            address
        ));
        initAuction(_funder, _token, _totalTokens, _startTime, _endTime, _paymentCurrency, _minimumCommitmentAmount, _operator, _pointList,  _wallet);
    }

     function getBatchAuctionInitData(
       address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _minimumCommitmentAmount,
        address _operator,
        address _pointList,
        address payable _wallet
    )
        external
        pure
        returns (bytes memory _data)
    {
        return abi.encode(
            _funder,
            _token,
            _totalTokens,
            _startTime,
            _endTime,
            _paymentCurrency,
            _minimumCommitmentAmount,
            _operator,
            _pointList,
            _wallet
            );
    }

    function getBaseInformation() external view returns(
        address token, 
        uint64 startTime,
        uint64 endTime,
        bool finalized
    ) {
        return (auctionToken, marketInfo.startTime, marketInfo.endTime, marketStatus.finalized);
    }

}
