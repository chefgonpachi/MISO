pragma solidity ^0.6.9;



import "../Access/MISOAccessControls.sol";
import "../Utils/SafeMathPlus.sol";
import "../UniswapV2/UniswapV2Library.sol";

import "../UniswapV2/interfaces/IUniswapV2Pair.sol";
import "../UniswapV2/interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IWETH9.sol";
import "../../interfaces/IERC20.sol";


// GP: Have more than one depositor
// GP: Deposit from / track contributors
// GP: Send LP tokens to contributors 


contract PoolLiquidity  {

    using SafeMathPlus for uint256;

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

    IERC20 public token;
    IWETH public WETH;
    IUniswapV2Factory public factory;
    MISOAccessControls public accessControls;

    address public tokenWETHPair;
    address public wallet;
    bool private initialised;
    uint256 public deadline;
    uint256 public locktime;
    uint256 public unlock;
    uint256 public expiry;

    uint256 public liquidityAdded;
    
    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);
    event LiquidityAdded(uint256 liquidity);

    constructor() public {
    }

    function initPoolLiquidity(
            address _accessControls,
            address _token,
            address _WETH,
            address _factory,
            address _owner,
            address _wallet,
            uint256 _duration,
            uint256 _launchwindow,
            uint256 _deadline,
            uint256 _locktime
    )
        external
    {
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);
        token = IERC20(_token);
        WETH = IWETH(_WETH);
        factory = IUniswapV2Factory(_factory);
        wallet = _wallet;
        _setTokenPair();
        initialised = true;
        deadline = block.timestamp + _deadline;
        require(_launchwindow > 2 * SECONDS_PER_DAY);
        expiry = deadline + _launchwindow;
        locktime = _locktime;
        emit InitPoolLiquidity(address(_token), address(_WETH), address(_factory), _owner);
    }

    fallback() external payable {
        if(msg.sender != address(WETH)){
             depositETH();
        }
    }


    // Getters
    function getTokenBalance() public view returns (uint256) {
         return token.balanceOf(address(this));
    }

    function getWethBalance() public view returns (uint256) {
         return WETH.balanceOf(address(this));
    }
    // function getTokenPrice() external returns (uint256) {}


    function depositETH() public payable {
        require(block.timestamp < deadline, "Deadline has expired");
        require(liquidityAdded == 0, "Liquidity already added");
        if (msg.value > 0 ) {
            WETH.deposit{value : msg.value}();
        }
    }

    function depositTokens(uint256 amount) external returns (bool success) {
        require(amount > 0, "Token amount must be greater than 0");
        require(block.timestamp < deadline, "Deadline has expired");
        require(liquidityAdded == 0, "Liquidity already added");
        token.transferFrom(msg.sender, address(this), amount); 
    }

    function addLiquidityToPool() external returns (uint256 liquidity) {
        require(block.timestamp > deadline, "Deposits still active");
        /// GP: Check both tokens from the factory

        uint256 tokenAmount = getTokenBalance();
        uint256 wethAmount = getWethBalance();

        require(IERC20(tokenWETHPair).totalSupply() == 0, "Cannot add to a liquid pair");

        /// GP: Should we think about what happens if this is used to top up an exisiting pool?
        /// GP: and if pool already exists, could be able to zap either tokens or eth to LP
        if (tokenAmount == 0 || wethAmount == 0) {
            return 0;
        }
        assert(token.transfer(tokenWETHPair, tokenAmount));
        assert(WETH.transfer(tokenWETHPair, wethAmount));

        // GP: Check this will return number of LP tokens
        liquidity = IUniswapV2Pair(tokenWETHPair).mint(address(this));
        liquidityAdded = liquidityAdded.add(liquidity);
        unlock = block.timestamp + locktime;
        emit LiquidityAdded(liquidityAdded);
    }

    function sendLPTokens() external returns (uint256 amount) {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLaucher.sendLPTokens: Sender must be operator"
        );
        uint256 liquidity = IERC20(tokenWETHPair).balanceOf(address(this));
        require(liquidity > 0, "Token amount must be greater than 0");
        IERC20(tokenWETHPair).transfer(wallet, liquidity);
    }


    function withdrawTokens() external {
        require(block.timestamp > expiry, "Timer has not yet expired");
        uint256 tokenAmount = getTokenBalance();
        if (tokenAmount > 0 ) {
            assert(token.transfer(wallet, tokenAmount));
        }
        uint256 wethAmount = getWethBalance();
        if (tokenAmount > 0 ) {
            assert(WETH.transfer(wallet, wethAmount));
        }
    }


    /// @dev helper functions
    function _createPool() internal returns (address) {
        tokenWETHPair = factory.createPair(address(token), address(WETH));
        return tokenWETHPair;
    }

    function _setTokenPair() internal returns (address) {
        address pair = factory.getPair(address(token), address(WETH));
        if (pair == address(0)) {
            return _createPool();
        }
        tokenWETHPair = pair;
        return tokenWETHPair;
    }

    /// @dev getter functions
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
        // GP: Test the order of returned values token/weth
        (wethReserves, tokenReserves) = token0 == address(token) ? (reserve1, reserve0) : (reserve0, reserve1);
    }

    function getPairTokens() internal view returns (address token0, address token1) {
        (token0, token1) = UniswapV2Library.sortTokens(address(WETH), address(token));
    }

}
