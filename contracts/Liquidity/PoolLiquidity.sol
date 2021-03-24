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

    function depositETH() public payable {
        require(block.timestamp < expiry, "PoolLiquidity: Contract has expired");
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity already added");
        if (msg.value > 0 ) {
            WETH.deposit{value : msg.value}();
        }
    }

    function depositTokens(uint256 amount) external returns (bool success) {
        require(block.timestamp < expiry, "PoolLiquidity: Contract has expired");
        require(amount > 0, "PoolLiquidity: Token amount must be greater than 0");
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity already added");
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
            "PoolLiquidity: Sender must be operator"
        ); 
        require(block.timestamp >= unlock, "PoolLiquidity: Liquidity is locked");

        liquidity = IERC20(tokenWETHPair).balanceOf(address(this));
        require(liquidity > 0, "PoolLiquidity: Liquidity must be greater than 0");
        _safeTransfer(tokenWETHPair, wallet, liquidity);

    }

    function withdrawDeposits() external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity: Sender must be operator"
        );
        require(liquidityAdded == 0, "PoolLiquidity: Liquidity is locked");
        require(block.timestamp > expiry, "PoolLiquidity: Timer has not yet expired");
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
        require(auction == address(0), "PoolLiquidity: Auction is already set");
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity: Sender must be operator"
        );
        auction = _auction;
    }

    function _launchLiquidityPool() internal returns (uint256 liquidity) {
        /// GP: Could add a flag to give the option for a trustless launch
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PoolLiquidity: Sender must be operator"
        );
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


}
