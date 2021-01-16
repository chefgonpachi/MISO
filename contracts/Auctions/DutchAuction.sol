pragma solidity ^0.6.9;

// import "../../interfaces/IMisoAuction.sol";
// import "../Utils/SafeMathPlus.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract DutchAuction {

    using SafeMath for uint256;
    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public startDate;
    uint256 public endDate;
    uint256 public startPrice;
    uint256 public minimumPrice;
    uint256 public totalTokens;  // Amount to be sold
    uint256 public priceDrop; // Price reduction from startPrice at endDate
    uint256 public commitmentsTotal;
    bool private initialised;    // AG: should be private
    bool public finalised;
    address public auctionToken;
    address public paymentCurrency;
    address payable public wallet;  // Where the auction funds will get paid
    mapping(address => uint256) public commitments;
    mapping(address => uint256) public claimed;

    // MISOMarket template id
    uint256 public constant marketTemplate = 2;

    event AddedCommitment(address addr, uint256 commitment);

    /// @dev Init function
    function initAuction(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startDate,
        uint256 _endDate,
        address _paymentCurrency,
        uint256 _startPrice,
        uint256 _minimumPrice,
        address payable _wallet
    )
        external
    {
        require(!initialised);                // Already Initialised
        require(_endDate > _startDate);       // End date earlier than start date
        require(_startPrice > _minimumPrice); // Starting price lower than minimum price
        require(_minimumPrice > 0);           // Minimum price must be greater than 0
        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        totalTokens = _totalTokens;
        startDate = _startDate;
        endDate = _endDate;
        startPrice = _startPrice;
        minimumPrice = _minimumPrice;
        wallet = _wallet;

        uint256 numerator = startPrice.sub(minimumPrice);
        uint256 denominator = endDate.sub(startDate);
        priceDrop = numerator.div(denominator);

        // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
        _safeTransferFrom(auctionToken, _funder, _totalTokens);
        initialised = true;

    }

    // Dutch Auction Price Function
    // ============================
    //
    // Start Price -----
    //                   \
    //                    \
    //                     \
    //                      \ ------------ Clearing Price
    //                     / \            = AmountRaised/TokenSupply
    //      Token Price  --   \
    //                  /      \
    //                --        ----------- Minimum Price
    // Amount raised /          End Time
    //

    /// @notice The average price of each token from all commitments. 
    function tokenPrice() public view returns (uint256) {
        return commitmentsTotal.mul(1e18).div(totalTokens);
    }

      /// @notice Returns price during the auction 
    function priceFunction() public view returns (uint256) {
        /// @dev Return Auction Price
        if (block.timestamp <= startDate) {
            return startPrice;
        }
        if (block.timestamp >= endDate) {
            return minimumPrice;
        }
        uint256 priceDiff = block.timestamp.sub(startDate).mul(priceDrop);
        return startPrice.sub(priceDiff);
    }

    /// @notice The current clearing price of the Dutch auction
    function clearingPrice() public view returns (uint256) {
        /// @dev If auction successful, return tokenPrice
        if (tokenPrice() > priceFunction()) {
            return tokenPrice();
        }
        return priceFunction();
    }

    /// @notice How many tokens the user is able to claim
    function tokensClaimable(address _user) public view returns (uint256) {
        uint256 tokensAvailable = commitments[_user].mul(1e18).div(clearingPrice());
        return tokensAvailable.sub(claimed[msg.sender]);
    }

    /// @notice Total amount of tokens committed at current auction price
    function totalTokensCommitted() public view returns(uint256) {
        return commitmentsTotal.mul(1e18).div(clearingPrice());
    }


    //--------------------------------------------------------
    // Commit to buying tokens! 
    //--------------------------------------------------------

    /// @notice Buy Tokens by committing ETH to this contract address 
    /// @dev Needs sufficient gas limit for additional state changes
    receive () external payable {
        commitEth(msg.sender);
    }

    /// @notice Commit ETH to buy tokens on sale
    function commitEth (address payable _from) public payable {
        require(address(paymentCurrency) == ETH_ADDRESS);       // Payment currency is not ETH
        // Get ETH able to be committed
        uint256 ethToTransfer = calculateCommitment( msg.value);

        // Accept ETH Payments
        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _addCommitment(_from, ethToTransfer);
        }
        // Return any ETH to be refunded
        if (ethToRefund > 0) {
            _from.transfer(ethToRefund);
        }
    }

    /// @notice Commits to an amount during an auction
    function _addCommitment(address _addr,  uint256 _commitment) internal {
        require(block.timestamp >= startDate && block.timestamp <= endDate);  // Outside auction hours
        commitments[_addr] = commitments[_addr].add(_commitment);
        commitmentsTotal = commitmentsTotal.add(_commitment);
        emit AddedCommitment(_addr, _commitment);
    }

    /// @notice Commit approved ERC20 tokens to buy tokens on sale
    function commitTokens(uint256 _amount) public {
        commitTokensFrom(msg.sender, _amount);
    }

    /// @dev Users must approve contract prior to committing tokens to auction
    function commitTokensFrom(address _from, uint256 _amount) public /* nonReentrant */{
        require(address(paymentCurrency) != ETH_ADDRESS);          // Only token transfers
        uint256 tokensToTransfer = calculateCommitment( _amount);
        if (tokensToTransfer > 0) {
            _safeTransferFrom(paymentCurrency, _from, _amount);
            _addCommitment(_from, tokensToTransfer);
        }
    }

    /// @notice Returns the amout able to be committed during an auction
    function calculateCommitment( uint256 _commitment) 
        public view returns (uint256 committed) 
    {
        uint256 maxCommitment = totalTokens.mul(clearingPrice()).div(1e18);
        if (commitmentsTotal.add(_commitment) > maxCommitment) {
            return maxCommitment.sub(commitmentsTotal);
        }
        return _commitment;
    }


    //--------------------------------------------------------
    // Finalise Auction
    //--------------------------------------------------------

    /// @notice Successful if tokens sold equals totalTokens
    function auctionSuccessful() public view returns (bool){
        return commitmentsTotal.mul(1e18).div(totalTokens) >= clearingPrice();
    }

    /// @notice Returns bool if successful or time has ended
    function auctionEnded() public view returns (bool){
        return auctionSuccessful() || block.timestamp > endDate;
    }

    /// @notice Auction finishes successfully above the reserve
    /// @dev Transfer contract funds to initialised wallet. 
    function finaliseAuction () public /* nonReentrant */ {
        require(!finalised);                                  // Auction already finalised
        if( auctionSuccessful() ) 
        {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _tokenPayment(paymentCurrency, wallet, commitmentsTotal);
        }
        else
        {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(block.timestamp > endDate);               // Auction not yet finished
            _tokenPayment(auctionToken, wallet, totalTokens);
        }
        finalised = true;
    }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens() public /* nonReentrant */ {
        if( auctionSuccessful() ) 
        {
            /// @dev Successful auction! Transfer claimed tokens.
            /// @dev AG: Could be only > min to allow early withdraw
            uint256 tokensToClaim = tokensClaimable(msg.sender);
            require(tokensToClaim > 0 );                      // No tokens to claim
            claimed[ msg.sender] = tokensToClaim;
            _tokenPayment(auctionToken, msg.sender, tokensToClaim);
        }
        else 
        {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > endDate);               // Auction not yet finished
            uint256 fundsCommitted = commitments[ msg.sender];
            commitments[msg.sender] = 0; // Stop multiple withdrawals and free some gas
            _tokenPayment(paymentCurrency, msg.sender, fundsCommitted);       
        }
    }


    //--------------------------------------------------------
    // Helper Functions
    //--------------------------------------------------------

    // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
    // Im trying to make it a habit to put external calls last (reentrancy)
    // You can put this in an internal function if you like.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0xa9059cbb = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 Transfer failed 
    }

    function _safeTransferFrom(address token, address from, uint256 amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 TransferFrom failed 
    }

    /// @dev Helper function to handle both ETH and ERC20 payments
    function _tokenPayment(address _token, address payable _to, uint256 _amount) internal {
        if (address(_token) == ETH_ADDRESS) {
            _to.transfer(_amount);
        } else {
            _safeTransfer(_token, _to, _amount);
        }
    }
}