pragma solidity ^0.6.9;

// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BatchAuction {
    using SafeMath for uint256;
    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalTokens; // Amount to be sold
    uint256 public commitmentsTotal;
    uint256 public minimumCommitmentAmount;
    address public auctionToken;
    address public paymentCurrency;
    address payable public wallet; // Where the auction funds will get paid
    bool public finalized;
    bool private initialized;
    mapping(address => uint256) public commitments;
    mapping(address => uint256) public claimed;

    event AddedCommitment(address addr, uint256 commitment);

    /// @dev Init function
    function initAuction(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _minimumCommitmentAmount,
        address payable _wallet
    ) external {
        require(!initialized, "BatchAuction: Auction already initialized");
        require(_endTime > _startTime, "BatchAuction: End time must be older than start price");
        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        totalTokens = _totalTokens;
        minimumCommitmentAmount = _minimumCommitmentAmount;
        startTime = _startTime;
        endTime = _endTime;
        wallet = _wallet;

        // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
        _safeTransferFrom(auctionToken, _funder, _totalTokens);
        initialized = true;
    }

    //--------------------------------------------------------
    // Commit to buying tokens!
    //--------------------------------------------------------

    /// @notice Buy Tokens by committing ETH to this contract address
    /// @dev Needs sufficient gas limit for additional state changes
    receive() external payable {
        commitEth(msg.sender);
    }

    /// @notice Commit ETH to buy tokens on sale
    function commitEth(address payable _from) public payable {
        require(msg.value > 0, "BatchAuction: ETH value must be higher than 0");
        require(address(paymentCurrency) == ETH_ADDRESS, "BatchAuction: Payment currency is not ETH");
        _addCommitment(_from, msg.value);
    }

    /// @notice Commit approved ERC20 tokens to buy tokens on sale
    function commitTokens(uint256 _amount) public {
        commitTokensFrom(msg.sender, _amount);
    }

    /// @dev Users must approve contract prior to committing tokens to auction
    function commitTokensFrom(address _from, uint256 _amount)
        public
    /* nonReentrant */
    {
        require(address(paymentCurrency) != ETH_ADDRESS, "BatchAuction: Payment currency is not a token");
        if (_amount > 0) {
            _safeTransferFrom(paymentCurrency, _from, _amount);
            _addCommitment(_from, _amount);
        }
    }

    //--------------------------------------------------------
    // Finalize Auction
    //--------------------------------------------------------

    /// @notice Auction finishes successfully above the reserve
    /// @dev Transfer contract funds to initialized wallet.
    function finalizeAuction() public /* nonReentrant */
    {
        require(!finalized, "BatchAuction: Auction has already finalized");
        require(block.timestamp > endTime, "BatchAuction: Auction has not finished yet");
        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _tokenPayment(paymentCurrency, wallet, commitmentsTotal);
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(block.timestamp > endTime, "BatchAuction: Auction has not finished yet");
            _tokenPayment(auctionToken, wallet, totalTokens);
        }
        finalized = true;
    }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens() public /* nonReentrant */
    {
        if (auctionSuccessful()) {
            /// @dev Successful auction! Transfer claimed tokens.
            /// @dev AG: Could be only > min to allow early withdraw
            uint256 tokensToClaim = tokensClaimable(msg.sender);
            require(tokensToClaim > 0, "BatchAuction: No tokens to claim");
            claimed[msg.sender] = tokensToClaim;
            _tokenPayment(auctionToken, msg.sender, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > endTime, "BatchAuction: Auction has not finished yet");
            uint256 fundsCommitted = commitments[msg.sender];
            commitments[msg.sender] = 0; // Stop multiple withdrawals and free some gas
            _tokenPayment(paymentCurrency, msg.sender, fundsCommitted);
        }
    }

    function tokenPrice() public view returns (uint256) {
        if (commitmentsTotal == 0) return 0;
        return commitmentsTotal.mul(1e18).div(totalTokens);
    }

    /// @notice How many tokens the user is able to claim
    function tokensClaimable(address _user) public view returns (uint256) {
        if (commitments[_user] == 0) return 0;

        uint256 tokensAvailable = _getTokenAmount(commitments[_user]);
        return tokensAvailable.sub(claimed[_user]);
    }

    /// @notice Successful if tokens sold greater than or equals to the minimum commitment amount
    function auctionSuccessful() public view returns (bool) {
        return commitmentsTotal >= minimumCommitmentAmount;
    }

    /// @notice Returns bool if successful or time has ended
    function auctionEnded() public view returns (bool) {
        return block.timestamp > endTime;
    }

    /// @notice Commits to an amount during an auction
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "BatchAuction: Outside auction hours"); 
        commitments[_addr] = commitments[_addr].add(_commitment);
        commitmentsTotal = commitmentsTotal.add(_commitment);
        emit AddedCommitment(_addr, _commitment);
    }

    function _getTokenAmount(uint256 amount) internal view returns (uint256) {
        return totalTokens.mul(amount).div(commitmentsTotal);
    }

    //--------------------------------------------------------
    // Helper Functions
    //--------------------------------------------------------

    /// @dev Helper function to handle both ETH and ERC20 payments
    function _tokenPayment(
        address _token,
        address payable _to,
        uint256 _amount
    ) internal {
        if (address(_token) == ETH_ADDRESS) {
            _to.transfer(_amount);
        } else {
            _safeTransfer(_token, _to, _amount);
        }
    }

    // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
    // Im trying to make it a habit to put external calls last (reentrancy)
    // You can put this in an internal function if you like.
    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) =
            token.call(
                // 0xa9059cbb = bytes4(keccak256("transferFrom(address,address,uint256)"))
                abi.encodeWithSelector(0xa9059cbb, to, amount)
            );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 Transfer failed
    }

    function _safeTransferFrom(
        address token,
        address from,
        uint256 amount
    ) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) =
            token.call(
                // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
                abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
            );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 TransferFrom failed
    }
}
