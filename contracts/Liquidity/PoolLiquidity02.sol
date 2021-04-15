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


// GP: Have more than one depositor
// GP: Deposit from / track contributors
// GP: Send LP tokens to contributors

contract PoolLiquidity02 is SafeTransfer {
    using SafeMathPlus for uint256;

    /// @notice Number of seconds per day.
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

    /// @notice First Token address.
    IERC20 public token1;

    /// @notice Second Token address.
    IERC20 public token2;

    /// @notice Uniswap V2 factory address.
    IUniswapV2Factory public factory;

    /// @notice Access controls contract address.
    MISOAccessControls public accessControls;

    /// @notice LP pair address.
    address public tokenPair;

    /// @notice Withdraw wallet address.
    address public wallet;

    /// @notice Token market contract address.
    address public market;

    /// @notice How long the liquidity will be locked. Number of seconds.
    uint256 public locktime;

    /// @notice The time of unlock. Block timestamp number in seconds.
    uint256 public unlock;

    /// @notice Deadline for liquidity deposits. Block timestamp number in seconds.
    uint256 public deadline;

    /// @notice The time window in which LP pool can be launched. Begining from deadline. Number of seconds.
    uint256 public launchwindow;

    /// @notice Expiration time of the LP contract. After the expiry liquidity cannot be launched anymore. Block timestamp number in seconds.
    uint256 public expiry;

    /// @notice Percentage of Tokens to be pooled.
    uint256 public liquidityPercent;

    /// @notice Number of LPs pooled after launch.
    uint256 public liquidityAdded;

    /// @notice Whether is the first token WETH or not.
    bool public isToken1WETH;

    /// @notice Whether LP is launched or not.
    bool public launched;

    /// @notice Whether contract is initialised or not.
    bool private initialised;

    /// @notice MISOLiquidity template id.
    uint256 public constant liquidityTemplate = 2;

    /// @notice Emitted when LP contract is initialised.
    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);

    /// @notice Emitted when LP is launched.
    event LiquidityAdded(uint256 liquidity);

    /**
     * @notice Initializes main contract variables (requires launchwindow to be more than 2 days.)
     * @param _accessControls Access controls contract address.
     * @param _token1 First Token address.
     * @param _token2 Second Token address.
     * @param _factory Uniswap V2 factory address.
     * @param _owner Contract owner address.
     * @param _wallet Withdraw wallet address.
     * @param _liquidityPercent Percentage of Tokens to be pooled.
     * @param _deadline Deadline for liquidity deposits. Block timestamp number in seconds.
     * @param _launchwindow The time window in which LP pool can be launched. Begining from deadline. Number of seconds.
     * @param _locktime How long the liquidity will be locked. Number of seconds.
     * @param _isToken1WETH Whether token is WETH or not.
     */
    function initPoolLiquidity(
            address _accessControls,
            address _token1,
            address _token2,
            address _factory,
            address _owner,
            address _wallet,
            uint256 _liquidityPercent,
            uint256 _deadline,
            uint256 _launchwindow,
            uint256 _locktime,
            bool _isToken1WETH
    )
        external
    {
        // CC: 2 same lines? mistake? purpose?
        require(_locktime < 10000000000, 'PoolLiquidity02: Enter an unix timestamp in seconds, not miliseconds');
        require(_locktime < 10000000000, 'PoolLiquidity02: Enter an unix timestamp in seconds, not miliseconds');
        require(_liquidityPercent <= 10000, 'PoolLiquidity02: Liquidity percentage greater than 100.00% (>10000)');
        require(_liquidityPercent > 0, 'PoolLiquidity02: Liquidity percentage equals zero');
        require(_launchwindow > 2 * SECONDS_PER_DAY, "PoolLiquidity02: The launch window must be longer than 2 days.");
        require(!initialised, "PoolLiquidity02: Pool liquidity already initialized");

        accessControls = MISOAccessControls(_accessControls);
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        factory = IUniswapV2Factory(_factory);
        wallet = _wallet;
        deadline = _deadline;
        liquidityPercent = _liquidityPercent;
        launchwindow = _launchwindow;
        expiry = _deadline + _launchwindow;
        locktime = _locktime;
        _setTokenPair();
        initialised = true;
        isToken1WETH = _isToken1WETH;
        emit InitPoolLiquidity(address(_token1), address(token2), address(_factory), _owner);
    }

    receive() external payable {
        if(msg.sender != address(token1)){
             depositETH();
        }
    }

    /// @notice Deposits ETH to the contract.
    // CC: No deposit deadline for WETH?
    function depositETH() public payable {
        require(isToken1WETH, "PoolLiquidity02: Launcher not accepting ETH");
        if (msg.value > 0 ) {
            IWETH(address(token1)).deposit{value : msg.value}();
        }
    }

    /**
     * @notice Deposits first Token to the contract.
     * @param amount Number of tokens to deposit.
     */
    function depositToken1(uint256 amount) external returns (bool success) {
        _deposit(amount, address(token1));
    }

    /**
     * @notice Deposits second Token to the contract.
     * @param amount Number of tokens to deposit.
     */
    function depositToken2(uint256 amount) external returns (bool success) {
        _deposit(amount, address(token2));
    }

    /**
     * @notice Deposits Tokens to the contract.
     * @param amount Number of tokens to deposit.
     * @param token Token address.
     */
    function _deposit(uint amount, address token) private returns (bool success) {
        // CC: shouldn't be require(block.timestamp < deadline, if deadline is deposit deadline?
        require(block.timestamp < expiry, "PoolLiquidity02: Contract has expired");
        require(amount > 0, "PoolLiquidity02: Token amount must be greater than 0");
        require(liquidityAdded == 0, "PoolLiquidity02: Liquidity already added");
        _safeTransferFrom(token, msg.sender, amount);
    }

    /**
     * @notice Launches LP.
     * @return uint256 Number of LPs.
     */
    function launchLiquidityPool() external returns (uint256) {
        return _launchLiquidityPool();
    }

    /**
     * @notice Finalizes Token sale and launches LP.
     * @return uint256 Number of LPs.
     */
    function finalizeMarketAndLaunchLiquidityPool() external payable returns (uint256) {
        IMisoAuction(market).finalize();
        return _launchLiquidityPool();
    }

    /**
     * @notice Withdraws LPs from the contract.
     * @return liquidity Number of LPs.
     */
    function withdrawLPTokens() external returns (uint256 liquidity) {
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(block.timestamp >= unlock, "PoolLiquidity02: Liquidity is locked");
        liquidity = IERC20(tokenPair).balanceOf(address(this));
        require(liquidity > 0, "PoolLiquidity02: Liquidity must be greater than 0");
        _safeTransfer(tokenPair, wallet, liquidity);
    }

    /// @notice Withraws deposited tokens and ETH from the contract to wallet.
    function withdrawDeposits() external {
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(block.timestamp > expiry, "PoolLiquidity02: Timer has not yet expired");
        uint256 token1Amount = getToken1Balance();
        if (token1Amount > 0 ) {
            _safeTransfer(address(token1), wallet, token1Amount);
        }
        uint256 token2Amount = getToken2Balance();
        if (token2Amount > 0 ) {
            _safeTransfer(address(token2), wallet, token2Amount);
        }
    }

    /**
     * @notice Sets Token market address.
     * @param _market Market address.
     */
    function setMarket(address _market) external {
        require(market == address(0), "PoolLiquidity02: Market is already set");
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        market = _market;
    }

    /**
     * @notice Mints LP tokens to this contract.
     * @return liquidity Number of LPs.
     */
    function _launchLiquidityPool() internal returns (uint256 liquidity) {
        /// GP: Could add a flag to give the option for a trustless launch
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity02: Sender must be operator");
        require(block.timestamp > deadline, "PoolLiquidity02: Deposit deadline has not passed");
        require(block.timestamp < expiry, "PoolLiquidity02: Contract has expired");

        address _token0 = IUniswapV2Pair(tokenPair).token0();
        address _token1 = IUniswapV2Pair(tokenPair).token1();
        address pair = factory.getPair(_token0, _token1);

        require(pair != address(0), "PoolLiquidity02: pair doesn't exist");
        require(_token0 == address(token1) || _token0 == address(token2),
                "PoolLiquidity02: Token is not part of the pair");
        require(_token1 == address(token1) || _token1 == address(token2),
                "PoolLiquidity02: Token is not part of the pair");

        uint256 token1Amount = getToken1Balance().mul(liquidityPercent).div(10000);
        // CC: Missing liquidityPercent multiplication?
        uint256 token2Amount = getToken2Balance();

        require(IERC20(tokenPair).totalSupply() == 0, "PoolLiquidity02: Cannot add to a liquid pair");

        /// GP: Should we think about what happens if this is used to top up an exisiting pool?
        /// GP: and if pool already exists, could be able to zap either tokens or eth to LP

        // GP: Uniswap might already check
        if (token1Amount == 0 || token2Amount == 0) {
            return 0;
        }

        _safeTransfer(address(token1), tokenPair, token1Amount);
        _safeTransfer(address(token2), tokenPair, token2Amount);

        liquidity = IUniswapV2Pair(tokenPair).mint(address(this));
        liquidityAdded = liquidityAdded.add(liquidity);
        unlock = block.timestamp + locktime;
        emit LiquidityAdded(liquidityAdded);
    }

    // GP: Claim / Bail

    //--------------------------------------------------------
    // Helper functions
    //--------------------------------------------------------

    /**
     * @notice Creates new LP pair through Uniswap.
     * @return address LP pair address.
     */
    function _createPool() internal returns (address) {
        tokenPair = factory.createPair(address(token1), address(token2));
        return tokenPair;
    }

    /**
     * @notice Gets LP pair address from Uniswap.
     * @return LP pair address.
     */
    function _setTokenPair() private returns (address) {
        address pair = factory.getPair(address(token1), address(token2));
        if (pair == address(0)) {
            return _createPool();
        }
        tokenPair = pair;
        return tokenPair;
    }

    //--------------------------------------------------------
    // Getter functions
    //--------------------------------------------------------

    /**
     * @notice Gets the number of first token deposited into this contract.
     * @return Number of WETH.
     */
    function getToken1Balance() public view returns (uint256) {
         return token1.balanceOf(address(this));
    }

    /**
     * @notice Gets the number of second token deposited into this contract.
     * @return Number of WETH.
     */
    function getToken2Balance() public view returns (uint256) {
         return token2.balanceOf(address(this));
    }

    /**
     * @notice Returns LP token address..
     * @return LP address.
     */
    function getLPTokenAddress() public view returns (address) {
        return tokenPair;
    }
}
