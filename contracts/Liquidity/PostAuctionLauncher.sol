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


import "../Access/MISOAccessControls.sol";
import "../Utils/SafeMathPlus.sol";
import "../Utils/SafeTransfer.sol";
import "../UniswapV2/UniswapV2Library.sol";
import "../UniswapV2/interfaces/IUniswapV2Pair.sol";
import "../UniswapV2/interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IWETH9.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IMisoAuction.sol";


contract PostAuctionLauncher is MISOAccessControls, SafeTransfer {
    using SafeMathPlus for uint256;

    /// @notice Number of seconds per day.
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice First Token address.
    IERC20 public token1;
    /// @notice Second Token address.
    IERC20 public token2;
    /// @notice Uniswap V2 factory address.
    IUniswapV2Factory public factory;
    /// @notice WETH contract address.
    address private immutable weth;


    /// @notice LP pair address.
    address public tokenPair;
    /// @notice Withdraw wallet address.
    address public wallet;
    /// @notice Token market contract address.
    IMisoAuction public market;
    /// @notice How long the liquidity will be locked. Number of seconds.
    uint256 public locktime;
    /// @notice The time of unlock. Block timestamp number in seconds.
    uint256 public unlock;
    /// @notice Percentage of Tokens to be pooled.
    uint256 public liquidityPercent;
    /// @notice Number of LPs pooled after launch.
    uint256 public liquidityAdded;

    /// @notice Whether LP is launched or not.
    bool public launched;

    uint256 private constant LIQUIDITY_PRECISION = 10000;
    /// @notice MISOLiquidity template id.
    uint256 public constant liquidityTemplate = 3;

    /// @notice Emitted when LP contract is initialised.
    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);
    /// @notice Emitted when LP is launched.
    event LiquidityAdded(uint256 liquidity);


    constructor (address _weth) public {
        weth = _weth;
    }


    /**
     * @notice Initializes main contract variables (requires launchwindow to be more than 2 days.)
     * @param _market Auction address for launcher.
     * @param _factory Uniswap V2 factory address.
     * @param _admin Contract owner address.
     * @param _wallet Withdraw wallet address.
     * @param _liquidityPercent Percentage of payment currency sent to liquidity pool.
     * @param _locktime How long the liquidity will be locked. Number of seconds.
     */
    function initAuctionLauncher(
            address _market,
            address _factory,
            address _admin,
            address _wallet,
            uint256 _liquidityPercent,
            uint256 _locktime
    )
        external
    {
        require(_locktime < 10000000000, 'PoolLiquidity02: Enter an unix timestamp in seconds, not miliseconds');
        require(_liquidityPercent <= LIQUIDITY_PRECISION, 'PoolLiquidity02: Liquidity percentage greater than 100.00% (>10000)');
        require(_liquidityPercent > 0, 'PoolLiquidity02: Liquidity percentage equals zero');
        require(_admin != address(0), "PoolLiquidity02: admin is the zero address");

        initAccessControls(_admin);

        market = IMisoAuction(_market);
        token1 = IERC20(market.paymentCurrency());
        token2 = IERC20(market.auctionToken());
        
        if (address(token1) == ETH_ADDRESS) {
            token1 = IERC20(weth);
        }
        require(address(token2) != ETH_ADDRESS, "Launching ETH as the auction token not supported");

        require(token1.decimals() > 0, "PoolLiquidity02: Token1 is not ERC20");
        require(token2.decimals() > 0, "PoolLiquidity02: Token2 is not ERC20");

        factory = IUniswapV2Factory(_factory);
        bytes32 pairCodeHash = factory.pairCodeHash();
        tokenPair = UniswapV2Library.pairFor(_factory, address(token1), address(token2), pairCodeHash);
   
        wallet = _wallet;
        liquidityPercent = _liquidityPercent;
        locktime = _locktime;

        emit InitPoolLiquidity(address(token1), address(token2), address(_factory), _admin);
    }

    receive() external payable {
        if(msg.sender != address(token1) ){
             depositETH();
        }
    }

    /// @notice Deposits ETH to the contract.
    function depositETH() public payable {
        require(address(token1) == weth, "PoolLiquidity02: Launcher not accepting ETH");
        if (msg.value > 0 ) {
            IWETH(address(token1)).deposit{value : msg.value}();
        }
    }

    /**
     * @notice Deposits first Token to the contract.
     * @param _amount Number of tokens to deposit.
     */
    function depositToken1(uint256 _amount) external returns (bool success) {
        return _deposit( address(token1), msg.sender, _amount);
    }
    /**
     * @notice Deposits first Token to the contract.
     * @param _amount Number of tokens to deposit.
     * @param _from Where the tokens to deposit will come from.
     */
    function depositToken1From(uint256 _amount, address _from) external returns (bool success) {
        return _deposit( address(token1), _from, _amount);
    }

    /**
     * @notice Deposits second Token to the contract.
     * @param _amount Number of tokens to deposit.
     */
    function depositToken2(uint256 _amount) external returns (bool success) {
        return _deposit( address(token2), msg.sender, _amount);
    }
    /**
     * @notice Deposits second Token to the contract.
     * @param _amount Number of tokens to deposit.
     * @param _from Where the tokens to deposit will come from.
     */
    function depositToken2From(uint256 _amount, address _from) external returns (bool success) {
        return _deposit( address(token2), _from, _amount);
    }

    /**
     * @notice Deposits Tokens to the contract.
     * @param _amount Number of tokens to deposit.
     * @param _from Where the tokens to deposit will come from.
     * @param _token Token address.
     */
    function _deposit(address _token, address _from, uint _amount) private returns (bool success) {
        require(!launched, "PoolLiquidity02: Must first launch liquidity");
        require(liquidityAdded == 0, "PoolLiquidity02: Liquidity already added");

        require(_amount > 0, "PoolLiquidity02: Token amount must be greater than 0");
        _safeTransferFrom(_token, _from, _amount);
        return true;
    }


    /**
     * @notice Checks if market wallet is set to this launcher
     */
    function marketConnected() public view returns (bool)  {
        return market.wallet() == address(this);
    }

    /**
     * @notice Finalizes Token sale and launches LP.
     * @return liquidity Number of LPs.
     */

    function finalize() external payable returns (uint256 liquidity) {
        require(hasAdminRole(msg.sender) || hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(marketConnected(), "PoolLiquidity02: Auction must have this launcher address set as the destination wallet");
        if (!market.finalized()) {
            market.finalize();
        }

        /// @dev if the auction is settled in base currency 
        if (msg.value > 0 ) {
            IWETH(weth).deposit{value : msg.value}();
        }

        // if (address(this).balance > 0 ) {
        //     // GP: Add any remaining unwrapped ETH
        // }

        launched = true;
        
        (uint256 token1Amount, uint256 token2Amount) =  getTokenAmounts();
        
        // GP: Handle unsuccessful auctions, need to check edge cases

        if (token1Amount == 0 || token2Amount == 0) {
            return 0;
        }

        address pair = factory.getPair(address(token1), address(token2));
        if(pair == address(0)) {
            createPool();
        }

        _safeTransfer(address(token1), tokenPair, token1Amount);
        _safeTransfer(address(token2), tokenPair, token2Amount);

        liquidity = IUniswapV2Pair(tokenPair).mint(address(this));
        liquidityAdded = liquidityAdded.add(liquidity);
        unlock = block.timestamp + locktime;
        emit LiquidityAdded(liquidityAdded);
    }

    function getTokenAmounts() public view returns (uint256 token1Amount, uint256 token2Amount) {
        token1Amount = getToken1Balance().mul(liquidityPercent).div(LIQUIDITY_PRECISION);
        token2Amount = getToken2Balance();

        uint256 tokenPrice = market.tokenPrice();
        uint256 maxToken1Amount = token2Amount.mul(tokenPrice).div(1e18);
        uint256 maxToken2Amount = token1Amount.mul(1e18).div(tokenPrice);
        
        if (token2Amount > maxToken2Amount) {
            token2Amount =  maxToken2Amount;
        } 
        if (token1Amount > maxToken1Amount) {
            token1Amount =  maxToken1Amount;
        }
    }

    /**
     * @notice Withdraws LPs from the contract.
     * @return liquidity Number of LPs.
     */
    function withdrawLPTokens() external returns (uint256 liquidity) {
        require(hasAdminRole(msg.sender) || hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(launched, "PoolLiquidity02: Must first launch liquidity");
        require(block.timestamp >= unlock, "PoolLiquidity02: Liquidity is locked");
        liquidity = IERC20(tokenPair).balanceOf(address(this));
        require(liquidity > 0, "PoolLiquidity02: Liquidity must be greater than 0");
        _safeTransfer(tokenPair, wallet, liquidity);
    }

    /// @notice Withraws deposited tokens and ETH from the contract to wallet.
    function withdrawDeposits() external {
        require(hasAdminRole(msg.sender) || hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(launched, "PoolLiquidity02: Must first launch liquidity");

        uint256 token1Amount = getToken1Balance();
        if (token1Amount > 0 ) {
            _safeTransfer(address(token1), wallet, token1Amount);
        }
        uint256 token2Amount = getToken2Balance();
        if (token2Amount > 0 ) {
            _safeTransfer(address(token2), wallet, token2Amount);
        }
    }

    // TODO     
    // GP: Sweep non relevant ERC20s

    //--------------------------------------------------------
    // Helper functions
    //--------------------------------------------------------

    /**
     * @notice Creates new LP pair through Uniswap.
     */
    function createPool() public {
        factory.createPair(address(token1), address(token2));
    }

    //--------------------------------------------------------
    // Getter functions
    //--------------------------------------------------------

    /**
     * @notice Gets the number of first token deposited into this contract.
     * @return uint256 Number of WETH.
     */
    function getToken1Balance() public view returns (uint256) {
         return token1.balanceOf(address(this));
    }

    /**
     * @notice Gets the number of second token deposited into this contract.
     * @return uint256 Number of WETH.
     */
    function getToken2Balance() public view returns (uint256) {
         return token2.balanceOf(address(this));
    }

    /**
     * @notice Returns LP token address..
     * @return address LP address.
     */
    function getLPTokenAddress() public view returns (address) {
        return tokenPair;
    }
    /**
     * @notice Returns LP Token balance.
     * @return uint256 LP Token balance.
     */
    function getLPBalance() public view returns (uint256) {
         return IERC20(tokenPair).balanceOf(address(this));
    }
}
