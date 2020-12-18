pragma solidity ^0.6.9;

import "../../interfaces/IERC20.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Crowdsale is Context, ReentrancyGuard {
    using SafeMath for uint256;

    // The token being sold
    address public token;

    // Address where funds are collected
    address payable private wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 public rate;
    // Amount of wei raised
    uint256 public weiRaised;
    // minimum amount of funds to be raised in weis
    uint256 public goal;
    uint256 public startTime;
    uint256 public endTime;
    bool private initialised;
    bool private finalized;

    // the balances of accounts
    mapping(address => uint256) private balances;

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen {
        require(isOpen(), "TimedCrowdsale: not open");
        _;
    }

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event CrowdsaleFinalized();

    /**
     * @param _rate Number of token units a buyer gets per wei
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param _startTime Crowdsale start time
     * @param _endTime Crowdsale end time
     * @param _wallet Address where collected funds will be forwarded to
     * @param _token Address of the token being sold
     */

    function initCrowdsale(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address payable _wallet
    ) external {
        require(!initialised, "Crowdsale: already initialised"); 
        require(_startTime >= block.timestamp, "Crowdsale: start time is before current time");
        require(_endTime > _startTime, "Crowdsale: start time is not before end time");
        require(_rate > 0, "Crowdsale: rate is 0");
        require(_wallet != address(0), "Crowdsale: wallet is the zero address");
        require(_token != address(0), "Crowdsale: token is the zero address");
        require(_totalTokens > 0, "Crowdsale: total tokens is 0");
        require(_goal > 0, "Crowdsale: goal is 0");

        token = _token;
        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
        wallet = _wallet;
        token = _token;
        goal = _goal;

        require(_getTokenAmount(_goal) <= _totalTokens, "Crowdsale: goal should be equal to or lower than total tokens or equal");
        
        _safeTransferFrom(_token, _funder, _totalTokens);
        initialised = true;
        finalized = false;
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public payable nonReentrant {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);
        balances[beneficiary] = balances[beneficiary].add(tokens);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        // _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, weiAmount);
     *     require(weiRaised().add(weiAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        onlyWhileOpen
    {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        uint256 totalTokens = IERC20(token).balanceOf(address(this));
        require(_getTokenAmount(weiRaised.add(weiAmount)) <= totalTokens, "Crowdsale: amount of tokens exceeded");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _safeTransfer(token, beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
    {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Withdraw tokens only after crowdsale ends.
     * @param beneficiary Whose tokens will be withdrawn.
     */
    function withdrawTokens(address payable beneficiary) public /* nonReentrant */ {
        require(hasClosed(), "Crowdsale: not closed");
        
        uint256 claimerBalance = balances[beneficiary];
        require(claimerBalance > 0, "Crowdsale: claimer balance is 0");

        if(goalReached()) {
            uint256 tokenAmount = _getTokenAmount(claimerBalance);
            _deliverTokens(beneficiary, tokenAmount);
        } else {
            uint256 claimAmount = claimerBalance.div(rate);
            beneficiary.transfer(claimAmount);
        }
        balances[beneficiary] = 0;
    }

    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() public {
        require(!finalized, "Crowdsale: already finalized");
        require(hasClosed(), "Crowdsale: not closed");
        uint256 unsoldTokens = IERC20(token).balanceOf(address(this));

        if(goalReached()) {
            _forwardFunds();
            uint256 soldTokens = _getTokenAmount(weiRaised);
            unsoldTokens = unsoldTokens.sub(soldTokens);
        }

        if(unsoldTokens > 0) {
            _deliverTokens(wallet, unsoldTokens);
        }

        finalized = true;

        emit CrowdsaleFinalized();
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        returns (uint256)
    {
        return weiAmount.mul(rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        wallet.transfer(address(this).balance);
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {
        buyTokens(_msgSender());
    }

    /**
     * @return the balance of an account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    /**
     * @return true if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime;
    }

    /**
     * @dev Checks whether funding goal was reached.
     * @return Whether funding goal was reached
     */
    function goalReached() public view returns (bool) {
        return weiRaised >= goal;
    }

    /**
     * @dev Checks whether the period in which the crowdsale is open has already elapsed.
     * @return Whether crowdsale period has elapsed
     */
    function hasClosed() public view returns (bool) {
        return block.timestamp > endTime;
    }

    // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
    // I'm trying to make it a habit to put external calls last (reentrancy)
    // You can put this in an internal function if you like.
    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = _token.call(
            // 0xa9059cbb = bytes4(keccak256("transfer(address,uint256)"))
            abi.encodeWithSelector(0xa9059cbb, _to, _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 Transfer failed 
    }


    function _safeTransferFrom(address _token, address _from, uint256 _amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = _token.call(
            // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0x23b872dd, _from, address(this), _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 TransferFrom failed 
    }
}