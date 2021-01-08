pragma solidity ^0.6.9;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IWETH9.sol";
import "../../interfaces/IMisoCrowdsale.sol";
import "../../interfaces/ISushiToken.sol";

// MVP for preparing a MISO set menu

interface IMISOTokenFactory {
    function createToken(
        string memory _name,
        string memory _symbol,
        uint256 _templateId
    ) external returns (address token);
}

interface IMISOMarket {
    function createCrowdsale(
        address _token, 
        uint256 _tokenSupply, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _rate, 
        uint256 _goal, 
        address payable _wallet,
        uint256 _templateId
    ) external returns (address newCrowdsale);
}

interface IMISOLiquidity {
   function createLiquidityLauncher(
            uint256 _templateId
    ) external returns (address launcher);
}


interface IPoolLiquidity {
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
        returns (address launcher);
    function getLPTokenAddress() external view returns (address);
}

interface IMISOFarmFactory {
    function createFarm(
            address _rewards,
            uint256 _rewardsPerBlock,
            uint256 _startBlock,
            address _devaddr,
            address _accessControls,
            uint256 _templateId
    ) external returns (address farm);
}

interface IMasterChef {
    function initFarm(
        address _rewards,
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        address _devaddr,
        address _accessControls
    ) external; 
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) external;
}

contract MISORecipe01 {

    using SafeMath for uint256;

    IMISOTokenFactory public tokenFactory;
    IMISOMarket public misoMarket;
    IWETH public weth;
    IMISOLiquidity public misoLauncher; 
    IMISOFarmFactory public farmFactory;

    address public uniswapFactory;

    constructor(
        address _tokenFactory,
        address _weth,
        address _misoMarket,
        address _misoLauncher,
        address _uniswapFactory,
        address _farmFactory
    ) public {
        tokenFactory = IMISOTokenFactory(_tokenFactory);
        weth = IWETH(_weth);
        misoMarket = IMISOMarket(_misoMarket);
        misoLauncher = IMISOLiquidity(_misoLauncher);
        uniswapFactory = _uniswapFactory;
        farmFactory = IMISOFarmFactory(_farmFactory);

    }

    function prepareMiso(
        string calldata _name,
        string calldata _symbol,
        address accessControl
    )
        external 
    {
        uint256 tokensToMint = 1000;
        uint256 tokensToMarket = 300;
        // Mintable token
        ISushiToken token = ISushiToken(tokenFactory.createToken(_name, _symbol, 1));
        // transfer ownership to msg.sender
        token.mint(address(this), tokensToMint);
        token.approve(address(misoMarket), tokensToMarket);

        // Scope for creating crowdsale
        {
        uint256 startTime = block.timestamp +5;
        uint256 endTime = block.timestamp +100;
        uint256 marketRate = 100;
        uint256 marketGoal = 200;
        address payable wallet = msg.sender;

        IMisoCrowdsale crowdsale = IMisoCrowdsale(misoMarket.createCrowdsale(
            address(token), 
            tokensToMarket, 
            startTime, 
            endTime, 
            marketRate, 
            marketGoal, 
            wallet, 
            2
        ));
        }

        // Scope for adding liquidity
        IPoolLiquidity poolLiquidity = IPoolLiquidity(misoLauncher.createLiquidityLauncher(1));

        {
        address operator = msg.sender;
        address payable wallet = msg.sender;

        uint256 duration = 1000;
        uint256 launchwindow = 100;
        uint256 deadline = 200;
        uint256 locktime = 60;
        uint256 tokensToLiquidity = 1000;

        poolLiquidity.initPoolLiquidity(accessControl,
            address(token),
            address(weth),
            uniswapFactory,
            operator,
            wallet,
            duration,
            launchwindow,
            deadline,
            locktime); 
        
        token.transfer(address(poolLiquidity),tokensToLiquidity);

        }

        // Scope for creating farm
        {
        uint256 rewardsPerBlock = 1e18;
        uint256 startBlock =  block.number + 10;
        address payable devAddr = msg.sender;
        uint256 tokensToFarm = 10;
        IMasterChef farm = IMasterChef(farmFactory.createFarm(
                address(token),
                rewardsPerBlock,
                startBlock,
                devAddr,
                accessControl,
                1));

        
        token.transfer(address(farm),tokensToFarm);
        uint256 allocPoint = 10;
        address lpToken = poolLiquidity.getLPTokenAddress();
        farm.add(allocPoint, IERC20(lpToken), false);

        }

    }


}