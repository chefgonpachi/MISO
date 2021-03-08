pragma solidity 0.6.12;


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

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

    IERC20 public token;
    IWETH public WETH;
    IUniswapV2Factory public factory;
    MISOAccessControls public accessControls;

    address public tokenWETHPair;
    address public wallet;
    address public auction;
    uint256 public locktime;
    uint256 public unlock;
    uint256 public deadline;
    uint256 public launchwindow;
    uint256 public expiry;
    uint256 public liquidityAdded;
    bool public launched;
    bool private initialised;

    // MISOLiquidity template id
    uint256 public constant liquidityTemplate = 1;

    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);
    event LiquidityAdded(uint256 liquidity);

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
        require(_locktime < 10000000000, 'MISOLaucher: Enter an unix timestamp in seconds, not miliseconds');
        require(_launchwindow > 2 * SECONDS_PER_DAY, "MISOLaucher: The launch window must be longer than 2 days.");
        require(!initialised, "MISOLaucher: Pool liquidity already initialized");
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

    function depositETH() public payable {
        require(block.timestamp < expiry, "MISOLaucher: Contract has expired");
        require(liquidityAdded == 0, "MISOLaucher: Liquidity already added");
        if (msg.value > 0 ) {
            WETH.deposit{value : msg.value}();
        }
    }

    function depositTokens(uint256 amount) external returns (bool success) {
        require(block.timestamp < expiry, "MISOLaucher: Contract has expired");
        require(amount > 0, "MISOLaucher: Token amount must be greater than 0");
        require(liquidityAdded == 0, "MISOLaucher: Liquidity already added");
        _safeTransferFrom(address(token), msg.sender, amount);
 
    }

    function launchLiquidityPool() external  returns (uint256) {
        return _launchLiquidityPool();
    }
    
    function finalizeMarketAndLaunchLiquidityPool() external  returns (uint256) {
        IMisoAuction(auction).finalize();
        return _launchLiquidityPool();
    }

    function withdrawLPTokens() external returns (uint256 liquidity) {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLaucher: Sender must be operator"
        ); 
        require(block.timestamp >= unlock, "MISOLaucher: Liquidity is locked");

        liquidity = IERC20(tokenWETHPair).balanceOf(address(this));
        require(liquidity > 0, "MISOLaucher: Liquidity must be greater than 0");
        _safeTransfer(tokenWETHPair, wallet, liquidity);

    }

    function withdrawDeposits() external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLaucher: Sender must be operator"
        );
        require(liquidityAdded == 0, "MISOLaucher: Liquidity is locked");
        require(block.timestamp > expiry, "MISOLaucher: Timer has not yet expired");
        uint256 tokenAmount = getTokenBalance();
        if (tokenAmount > 0 ) {
            _safeTransfer(address(token), wallet, tokenAmount);
        }
        uint256 wethAmount = getWethBalance();
        if (tokenAmount > 0 ) {
            assert(WETH.transfer(wallet, wethAmount));
        }
    }

    function setAuction(address _auction) external {
        require(auction == address(0), "MISOLaucher: Auction is already set");
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLaucher: Sender must be operator"
        );
        auction = _auction;
    }

    function _launchLiquidityPool() internal returns (uint256 liquidity) {
        /// GP: Could add a flag to give the option for a trustless launch
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLaucher: Sender must be operator"
        );
        require(block.timestamp > deadline, "MISOLaucher: Deposit deadline has not passed");
        require(block.timestamp < expiry, "MISOLaucher: Contract has expired");

        address token0 = IUniswapV2Pair(tokenWETHPair).token0();
        address token1 = IUniswapV2Pair(tokenWETHPair).token1();
        address pair = factory.getPair(token0, token1);

        require(pair != address(0), "MISOLauncher: pair doesn't exist");
        require(token0 == address(token) || token0 == address(WETH),
                "MISOLauncher: Token is not part of the pair");
        require(token1 == address(token) || token1 == address(WETH),
                "MISOLauncher: Token is not part of the pair");
                
        uint256 tokenAmount = getTokenBalance();
        uint256 wethAmount = getWethBalance();

        require(IERC20(tokenWETHPair).totalSupply() == 0, "MISOLaucher: Cannot add to a liquid pair");

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

    /// @dev helper functions
    function _createPool() internal returns (address) {
        tokenWETHPair = factory.createPair(address(token), address(WETH));
        return tokenWETHPair;
    }

    function _setTokenPair() private returns (address) {
        address pair = factory.getPair(address(token), address(WETH));
        if (pair == address(0)) {
            return _createPool();
        }
        tokenWETHPair = pair;
        return tokenWETHPair;
    }

    /// @dev getter functions
    function getTokenBalance() public view returns (uint256) {
         return token.balanceOf(address(this));
    }

    function getWethBalance() public view returns (uint256) {
         return WETH.balanceOf(address(this));
    }

    function getLPTokenAddress() public view returns (address) {
        return tokenWETHPair;
    }

    function getLPTokenPerEthUnit(uint ethAmt) public view  returns (uint liquidity) {
        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outTokens = UniswapV2Library.getAmountOut(ethAmt.div(2), reserveWeth, reserveTokens);
        uint _totalSupply =  IUniswapV2Pair(tokenWETHPair).totalSupply();

        (address token0, ) = UniswapV2Library.sortTokens(address(WETH), address(token));
        (uint256 amount0, uint256 amount1) = token0 == address(token) ? (outTokens, ethAmt.div(2)) : (ethAmt.div(2), outTokens);
        (uint256 _reserve0, uint256 _reserve1) = token0 == address(token) ? (reserveTokens, reserveWeth) : (reserveWeth, reserveTokens);
        liquidity = SafeMathPlus.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }

    function getPairReserves() internal view returns (uint256 wethReserves, uint256 tokenReserves) {
        (address token0,) = UniswapV2Library.sortTokens(address(WETH), address(token));
        (uint256 reserve0, uint reserve1,) = IUniswapV2Pair(tokenWETHPair).getReserves();
        (wethReserves, tokenReserves) = token0 == address(token) ? (reserve1, reserve0) : (reserve0, reserve1);
    }

    function getPairTokens() internal view returns (address token0, address token1) {
        (token0, token1) = UniswapV2Library.sortTokens(address(WETH), address(token));
    }

}
