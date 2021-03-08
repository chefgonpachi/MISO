pragma solidity ^0.6.12;


//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// LiquidityZAP takes ETH and converts to  liquidity tokens. 
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// Attribution: CORE / cvault.finance
//  https://github.com/cVault-finance/CORE-periphery/blob/master/contracts/COREv1Router.sol
//
//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
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


import "../UniswapV2/interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IWETH9.sol";
import "../../interfaces/IERC20.sol";
import "../Utils/SafeMathPlus.sol";
import "../UniswapV2/UniswapV2Library.sol";
import "../Utils/SafeTransfer.sol";

contract LiquidityZAP is SafeTransfer{

    using SafeMathPlus for uint256;

    address public _token;
    address public _tokenWETHPair;
    IWETH public _WETH;
    bool private initialized;

    function initUniswapZAP(address token, address WETH, address tokenWethPair) public  {
        require(!initialized);
        _token = token;
        _WETH = IWETH(WETH);
        _tokenWETHPair = tokenWethPair;
        initialized = true;
    }

    fallback() external payable {
        if(msg.sender != address(_WETH)){
             addLiquidityETHOnly(msg.sender);
        }
    }


    function zapETH() external payable returns (uint256 liquidity) {
        require(msg.value > 0, "LiquidityZAP: ETH amount must be greater than 0");
        return addLiquidityETHOnly(msg.sender);
    }

    function zapTokens(uint amount) external returns (uint256 liquidity) {
        require(amount > 0, "LiquidityZAP: Token amount must be greater than 0");
        return addLiquidityTokensOnly(msg.sender, msg.sender, amount);
    }

    function unzap() external returns  (uint amountToken, uint amountETH) {
        uint256 liquidity = IERC20(_tokenWETHPair).balanceOf(msg.sender);
        (amountToken, amountETH) = removeLiquidity( _token,address(_WETH),liquidity,msg.sender);
    }

    function unzapToETH() external returns (uint amount) {
        uint256 liquidity = IERC20(_tokenWETHPair).balanceOf(msg.sender);
        amount = removeLiquidityETHOnly(msg.sender, liquidity);
    }

    function unzapToTokens() external returns (uint amount) {
        uint256 liquidity = IERC20(_tokenWETHPair).balanceOf(msg.sender);
        amount = removeLiquidityTokenOnly(msg.sender, liquidity);
    }


    /// @dev Add liquidity functions
    function addLiquidityTokensOnly(address from, address payable to, uint amount) public returns (uint256 liquidity) {
        require(to != address(0), "LiquidityZAP: Invalid address");

        uint256 buyAmount = amount.div(2);
        require(buyAmount > 0, "LiquidityZAP: Insufficient Token amount");

        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outETH = UniswapV2Library.getAmountOut(buyAmount, reserveTokens, reserveWeth);
        
        _safeTransferFrom(_token, from, address(this), amount);
        _safeTransfer(_token, _tokenWETHPair, buyAmount);

        (address token0, address token1) = UniswapV2Library.sortTokens(address(_WETH), _token);
        IUniswapV2Pair(_tokenWETHPair).swap(address(_WETH) == token0 ? outETH : 0, address(_WETH) == token1 ? outETH : 0, address(this), "");

        return _addLiquidity( buyAmount, outETH, to);

    }

    function addLiquidityETHOnly(address payable to) public payable returns (uint256 liquidity ) {
        require(to != address(0), "LiquidityZAP: Invalid address");

        uint256 buyAmount = msg.value.div(2);
        require(buyAmount > 0, "LiquidityZAP: Insufficient ETH amount");
        _WETH.deposit{value : msg.value}();

        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outTokens = UniswapV2Library.getAmountOut(buyAmount, reserveWeth, reserveTokens);
        
        _WETH.transfer(_tokenWETHPair, buyAmount);

        (address token0, address token1) = UniswapV2Library.sortTokens(address(_WETH), _token);
        IUniswapV2Pair(_tokenWETHPair).swap(_token == token0 ? outTokens : 0, _token == token1 ? outTokens : 0, address(this), "");

        return _addLiquidity(outTokens, buyAmount, to);

    }

    function _addLiquidity(uint256 tokenAmount, uint256 wethAmount, address payable to) internal returns (uint256 liquidity){
        (uint256 wethReserve, uint256 tokenReserve) = getPairReserves();

        uint256 optimalTokenAmount = UniswapV2Library.quote(wethAmount, wethReserve, tokenReserve);

        uint256 optimalWETHAmount;
        if (optimalTokenAmount > tokenAmount) {
            optimalWETHAmount = UniswapV2Library.quote(tokenAmount, tokenReserve, wethReserve);
            optimalTokenAmount = tokenAmount;
        }
        else
            optimalWETHAmount = wethAmount;

        assert(_WETH.transfer(_tokenWETHPair, optimalWETHAmount));
        _safeTransfer(_token, _tokenWETHPair, optimalTokenAmount);

        liquidity = IUniswapV2Pair(_tokenWETHPair).mint(to);
        
        //refund dust
        if (tokenAmount > optimalTokenAmount)
            _safeTransfer(_token, to, tokenAmount.sub(optimalTokenAmount));
        if (wethAmount > optimalWETHAmount) {
            uint256 withdrawAmount = wethAmount.sub(optimalWETHAmount);
            _WETH.withdraw(withdrawAmount);
            to.transfer(withdrawAmount);
        }
    }


    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        address to
    ) public returns (uint amountA, uint amountB) {
        IUniswapV2Pair(_tokenWETHPair).transferFrom(msg.sender, _tokenWETHPair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IUniswapV2Pair(_tokenWETHPair).burn(to);
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    }


    function removeLiquidityETHOnly(address payable to, uint256 liquidity) public returns (uint amountOut){
        require(to != address(0), "LiquidityZAP: Invalid address");
        (uint amountToken, uint amountETH) = removeLiquidity( _token,address(_WETH),liquidity,address(this));

        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outETH = UniswapV2Library.getAmountOut(amountToken, reserveTokens, reserveWeth);

        _safeTransfer(_token, _tokenWETHPair, amountToken);

        (address token0, address token1) = UniswapV2Library.sortTokens(address(_WETH), _token);
        IUniswapV2Pair(_tokenWETHPair).swap(address(_WETH) == token0 ? outETH : 0, address(_WETH) == token1 ? outETH : 0, address(this), "");

        amountOut = IERC20(address(_WETH)).balanceOf(address(this));
        _WETH.withdraw(amountOut);
        _safeTransferETH(to, amountOut);   
    }

    function removeAllLiquidityETHOnly(address payable to) public returns (uint amount) {
        uint256 liquidity = IERC20(_tokenWETHPair).balanceOf(msg.sender);
        amount = removeLiquidityETHOnly(to, liquidity);
    }

    function removeLiquidityTokenOnly(address to, uint256 liquidity) public returns (uint amount){
        require(to != address(0), "LiquidityZAP: Invalid address");
        (uint amountToken, uint amountETH) = removeLiquidity( _token,address(_WETH),liquidity,address(this));

        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outTokens = UniswapV2Library.getAmountOut(amountETH, reserveWeth, reserveTokens);
        
        _WETH.transfer(_tokenWETHPair, amountETH);

        (address token0, address token1) = UniswapV2Library.sortTokens(address(_WETH), _token);
        IUniswapV2Pair(_tokenWETHPair).swap(_token == token0 ? outTokens : 0, _token == token1 ? outTokens : 0, address(this), "");
        amount = IERC20(_token).balanceOf(address(this));
        _safeTransfer(_token, to, amount);
    }

    function removeAllLiquidityTokenOnly(address payable to) public returns (uint amount) {
        uint256 liquidity = IERC20(_tokenWETHPair).balanceOf(msg.sender);
        amount = removeLiquidityTokenOnly(to, liquidity);
    }



    function getLPTokenPerEthUnit(uint ethAmt) public view  returns (uint liquidity){
        (uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
        uint256 outTokens = UniswapV2Library.getAmountOut(ethAmt.div(2), reserveWeth, reserveTokens);
        uint _totalSupply =  IUniswapV2Pair(_tokenWETHPair).totalSupply();

        (address token0, ) = UniswapV2Library.sortTokens(address(_WETH), _token);
        (uint256 amount0, uint256 amount1) = token0 == _token ? (outTokens, ethAmt.div(2)) : (ethAmt.div(2), outTokens);
        (uint256 _reserve0, uint256 _reserve1) = token0 == _token ? (reserveTokens, reserveWeth) : (reserveWeth, reserveTokens);
        liquidity = SafeMathPlus.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }

    function getPairReserves() internal view returns (uint256 wethReserves, uint256 tokenReserves) {
        (address token0,) = UniswapV2Library.sortTokens(address(_WETH), _token);
        (uint256 reserve0, uint reserve1,) = IUniswapV2Pair(_tokenWETHPair).getReserves();
        (wethReserves, tokenReserves) = token0 == _token ? (reserve1, reserve0) : (reserve0, reserve1);
    }


}

