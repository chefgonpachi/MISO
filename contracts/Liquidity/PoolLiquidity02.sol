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

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

    IERC20 public token1;
    IERC20 public token2;
    IUniswapV2Factory public factory;
    MISOAccessControls public accessControls;

    address public tokenPair;
    address public wallet;
    address public market;
    uint256 public locktime;
    uint256 public unlock;
    uint256 public deadline;
    uint256 public launchwindow;
    uint256 public expiry;
    uint256 public liquidityPercent;
    uint256 public liquidityAdded;

    bool public isToken1WETH;
    bool public launched;
    bool private initialised;

    // MISOLiquidity template id
    uint256 public constant liquidityTemplate = 2;

    event InitPoolLiquidity(address indexed token1, address indexed token2, address factory, address sender);
    event LiquidityAdded(uint256 liquidity);

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

    function depositETH() public payable {
        require(isToken1WETH, "PoolLiquidity02: Launcher not accepting ETH");
        if (msg.value > 0 ) {
            IWETH(address(token1)).deposit{value : msg.value}();
        }
    }

    function depositToken1(uint256 amount) external returns (bool success) {
        _deposit(amount, address(token1));
    }

    function depositToken2(uint256 amount) external returns (bool success) {
        _deposit(amount, address(token2));
    }

    function _deposit(uint amount, address token) private returns (bool success){
        require(block.timestamp < expiry, "PoolLiquidity02: Contract has expired");
        require(amount > 0, "PoolLiquidity02: Token amount must be greater than 0");
        require(liquidityAdded == 0, "PoolLiquidity02: Liquidity already added");
        _safeTransferFrom(token, msg.sender, amount);
    }


    function launchLiquidityPool() external  returns (uint256) {
        return _launchLiquidityPool();
    }
    
    function finalizeMarketAndLaunchLiquidityPool() external  returns (uint256) {
        IMisoAuction(market).finalize();
        return _launchLiquidityPool();
    }

    function withdrawLPTokens() external returns (uint256 liquidity) {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity02: Sender must be operator"
        ); 
        require(block.timestamp >= unlock, "PoolLiquidity02: Liquidity is locked");

        liquidity = IERC20(tokenPair).balanceOf(address(this));
        require(liquidity > 0, "PoolLiquidity02: Liquidity must be greater than 0");
        _safeTransfer(tokenPair, wallet, liquidity);

    }

    function withdrawDeposits() external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity02: Sender must be operator"
        );
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

    function setMarket(address _market) external {
        require(market == address(0), "PoolLiquidity02: Market is already set");
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity02: Sender must be operator"
        );
        market = _market;
    }

    function _launchLiquidityPool() internal returns (uint256 liquidity) {
        /// GP: Could add a flag to give the option for a trustless launch
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity02: Sender must be operator"
        );
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

    /// @dev helper functions
    function _createPool() internal returns (address) {
        tokenPair = factory.createPair(address(token1), address(token2));
        return tokenPair;
    }

    function _setTokenPair() private returns (address) {
        address pair = factory.getPair(address(token1), address(token2));
        if (pair == address(0)) {
            return _createPool();
        }
        tokenPair = pair;
        return tokenPair;
    }


    /// @dev getter functions
    function getToken1Balance() public view returns (uint256) {
         return token1.balanceOf(address(this));
    }

    function getToken2Balance() public view returns (uint256) {
         return token2.balanceOf(address(this));
    }

    function getLPTokenAddress() public view returns (address) {
        return tokenPair;
    }

    
}
