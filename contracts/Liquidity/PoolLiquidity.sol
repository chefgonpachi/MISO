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

contract PoolLiquidity is SafeTransfer {
    using SafeMathPlus for uint256;

    /// @notice Number of seconds per day.
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

    /// @notice Token address.
    IERC20 public token;

    /// @notice WETH address.
    IWETH public WETH;

    /// @notice Uniswap V2 factory address.
    IUniswapV2Factory public factory;

    /// @notice Access controls contract address.
    MISOAccessControls public accessControls;

    /// @notice LP pair address.
    address public tokenWETHPair;

    /// @notice Withdraw wallet address.
    address public wallet;

    /// @notice Token auction contract address.
    address public auction;

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

    /// @notice Number of LPs pooled after launch.
    uint256 public liquidityAdded;

    /// @notice Whether LP is launched or not.
    bool public launched;

    /// @notice Whether contract is initialised or not.
    bool private initialised;

    /// @notice MISOLiquidity template id.
    uint256 public constant liquidityTemplate = 1;

    /// @notice Emitted when LP contract is initialised.
    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);

    /// @notice Emitted when LP is launched.
    event LiquidityAdded(uint256 liquidity);

    /**
     * @notice Initializes main contract variables (requires launchwindow to be more than 2 days.)
     * @param _accessControls Access controls contract address.
     * @param _token Token address.
     * @param _WETH WETH address.
     * @param _factory Uniswap V2 factory address.
     * @param _owner Contract owner address.
     * @param _wallet Withdraw wallet address.
     * @param _deadline Deadline for liquidity deposits. Block timestamp number in seconds.
     * @param _launchwindow The time window in which LP pool can be launched. Begining from deadline. Number of seconds.
     * @param _locktime How long the liquidity will be locked. Number of seconds.
     */
    function initPoolLiquidity(
            address _accessControls,
            address _token,
            address _WETH,
            address _factory,
            address _owner,
            address _wallet,
            uint256 _deadline,
            uint256 _launchwindow,
            uint256 _locktime
    )
        external
    {
        require(_locktime < 10000000000, 'PoolLiquidity: Enter an unix timestamp in seconds, not miliseconds');
        require(_launchwindow > 2 * SECONDS_PER_DAY, "PoolLiquidity: The launch window must be longer than 2 days.");
        require(!initialised, "PoolLiquidity: Pool liquidity already initialized");
        accessControls = MISOAccessControls(_accessControls);
        token = IERC20(_token);
        WETH = IWETH(_WETH);
        factory = IUniswapV2Factory(_factory);
        wallet = _wallet;
        deadline = _deadline;
        launchwindow = _launchwindow;
        expiry = _deadline + _launchwindow;
        locktime = _locktime;
        _setTokenPair();
        initialised = true;
        emit InitPoolLiquidity(address(_token), address(_WETH), address(_factory), _owner);
    }

    receive() external payable {
        if(msg.sender != address(WETH)){
             depositETH();
        }
    }

    /// @notice Deposits ETH to the contract.
    function depositETH() public payable {
        require(block.timestamp < deadline, "PoolLiquidity: Contract has expired");
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity already added");
        if (msg.value > 0 ) {
            WETH.deposit{value : msg.value}();
        }
    }

    /**
     * @notice Deposits Tokens to the contract.
     * @param amount Number of tokens to deposit.
     */
    function depositTokens(uint256 amount) external returns (bool success) {
        require(block.timestamp < deadline, "PoolLiquidity: Contract has expired");
        require(amount > 0, "PoolLiquidity: Token amount must be greater than 0");
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity already added");
        _safeTransferFrom(address(token), msg.sender, amount);
    }

    /**
     * @notice Launches LP.
     * @return Number of LPs.
     */
    function launchLiquidityPool() external returns (uint256) {
        return _launchLiquidityPool();
    }

    /**
     * @notice Finalizes Token sale and launches LP.
     * @return uint256 Number of LPs.
     */
    function finalizeMarketAndLaunchLiquidityPool() external payable returns (uint256) {
        IMisoAuction(auction).finalize();
        return _launchLiquidityPool();
    }

    /**
     * @notice Withdraws LPs from the contract.
     * @return liquidity Number of LPs.
     */
    function withdrawLPTokens() external returns (uint256 liquidity) {
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity: Sender must be operator");
        require(block.timestamp >= unlock, "PoolLiquidity: Liquidity is locked");
        liquidity = IERC20(tokenWETHPair).balanceOf(address(this));
        require(liquidity > 0, "PoolLiquidity: Liquidity must be greater than 0");
        _safeTransfer(tokenWETHPair, wallet, liquidity);
    }

    /// @notice Withraws deposited tokens and ETH from the contract to wallet.
    function withdrawDeposits() external {
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity: Sender must be operator");
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity is locked");
        require(block.timestamp > expiry, "PoolLiquidity: Timer has not yet expired");
        uint256 tokenAmount = getTokenBalance();
        if (tokenAmount > 0) {
            _safeTransfer(address(token), wallet, tokenAmount);
        }
        uint256 wethAmount = getWethBalance();
        if (wethAmount > 0) {
            assert(WETH.transfer(wallet, wethAmount));
        }
    }

    /**
     * @notice Sets Token auction address.
     * @param _auction Auction address.
     */
    function setAuction(address _auction) external {
        require(auction == address(0), "PoolLiquidity: Auction is already set");
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity: Sender must be operator");
        auction = _auction;
    }

    /**
     * @notice Mints LP tokens to this contract.
     * @return liquidity Number of LPs.
     */
    function _launchLiquidityPool() internal returns (uint256 liquidity) {
        /// GP: Could add a flag to give the option for a trustless launch
        require(accessControls.hasOperatorRole(msg.sender), "PoolLiquidity: Sender must be operator");
        require(block.timestamp > deadline, "PoolLiquidity: Deposit deadline has not passed");
        require(block.timestamp < expiry, "PoolLiquidity: Contract has expired");

        address token0 = IUniswapV2Pair(tokenWETHPair).token0();
        address token1 = IUniswapV2Pair(tokenWETHPair).token1();
        address pair = factory.getPair(token0, token1);

        require(pair != address(0), "PoolLiquidity: pair doesn't exist");
        require(token0 == address(token) || token0 == address(WETH),
                "PoolLiquidity: Token is not part of the pair");
        require(token1 == address(token) || token1 == address(WETH),
                "PoolLiquidity: Token is not part of the pair");

        uint256 tokenAmount = getTokenBalance();
        uint256 wethAmount = getWethBalance();

        require(IERC20(tokenWETHPair).totalSupply() == 0, "PoolLiquidity: Cannot add to a liquid pair");

        /// GP: Should we think about what happens if this is used to top up an exisiting pool?
        /// GP: and if pool already exists, could be able to zap either tokens or eth to LP

        // GP: Uniswap might already check
        if (tokenAmount == 0 || wethAmount == 0) {
            return 0;
        }

        _safeTransfer(address(token), tokenWETHPair, tokenAmount);
        assert(WETH.transfer(tokenWETHPair, wethAmount));

        liquidity = IUniswapV2Pair(tokenWETHPair).mint(address(this));
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
        tokenWETHPair = factory.createPair(address(token), address(WETH));
        return tokenWETHPair;
    }

    /**
     * @notice Gets LP pair address from Uniswap.
     * @return address LP pair address.
     */
    function _setTokenPair() private returns (address) {
        address pair = factory.getPair(address(token), address(WETH));
        if (pair == address(0)) {
            return _createPool();
        }
        tokenWETHPair = pair;
        return tokenWETHPair;
    }

    //--------------------------------------------------------
    // Getter functions
    //--------------------------------------------------------

    /**
     * @notice Gets the number of tokens deposited into this contract.
     * @return uint256 Number of tokens.
     */
    function getTokenBalance() public view returns (uint256) {
         return token.balanceOf(address(this));
    }

    /**
     * @notice Gets the number of WETH deposited into this contract.
     * @return uint256 Number of WETH.
     */
    function getWethBalance() public view returns (uint256) {
         return WETH.balanceOf(address(this));
    }

    /**
     * @notice Gets the LP Token address
     * @return address of LP token.
     */
    function getLPTokenAddress() public view returns (address) {
        return tokenWETHPair;
    }
}
