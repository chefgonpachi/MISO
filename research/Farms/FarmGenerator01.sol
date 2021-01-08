// SPDX-License-Identifier: UNLICENSED

// Ideally this contract should not be interacted with directly. Use our front end Dapp to create a farm
// to ensure the most effeicient amount of tokens are sent to the contract

pragma solidity 0.6.12;

import "./Farm01.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";

interface IERCBurn {
    function burn(uint256 _amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external returns (uint256);
}

interface FarmFactory {
    function registerFarm (address _farmAddress) external;
}

interface IUniFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

contract FarmGenerator01 is Ownable {
    using SafeMath for uint256;
    
    FarmFactory public factory;
    IUniFactory public uniswapFactory;
    
    address payable devaddr;
    
    struct FeeStruct {
        IERCBurn gasToken;
        bool useGasToken; // set to false to waive the gas fee
        uint256 gasFee; // the total amount of gas tokens to be burnt (if used)
        uint256 ethFee; // Small eth fee to prevent spam on the platform
        uint256 tokenFee; // Divided by 1000, fee on farm rewards
    }
    
    FeeStruct public gFees;
    
    struct FarmParameters {
        uint256 fee;
        uint256 amountMinusFee;
        uint256 bonusBlocks;
        uint256 totalBonusReward;
        uint256 numBlocks;
        uint256 endBlock;
        uint256 requiredAmount;
        uint256 amountFee;
    }
    
    constructor(FarmFactory _factory, IUniFactory _uniswapFactory) public {
        factory = _factory;
        devaddr = msg.sender;
        gFees.useGasToken = false;
        gFees.gasFee = 1 * (10 ** 18);
        gFees.ethFee = 2e17;
        gFees.tokenFee = 10; // 1%
        uniswapFactory = _uniswapFactory;
    }
    
    /**
     * @notice Below are self descriptive gas fee and general settings functions
     */
    function setGasToken (IERCBurn _gasToken) public onlyOwner {
        gFees.gasToken = _gasToken;
    }
    
    function setGasFee (uint256 _amount) public onlyOwner {
        gFees.gasFee = _amount;
    }
    
    function setEthFee (uint256 _amount) public onlyOwner {
        gFees.ethFee = _amount;
    }
    
    function setTokenFee (uint256 _amount) public onlyOwner {
        gFees.tokenFee = _amount;
    }
    
    function setRequireGasToken (bool _useGasToken) public onlyOwner {
        gFees.useGasToken = _useGasToken;
    }
    
    function setDev(address payable _devaddr) public onlyOwner {
        devaddr = _devaddr;
    }
    
    /**
     * @notice Determine the endBlock based on inputs. Used on the front end to show the exact settings the Farm contract will be deployed with
     */
    function determineEndBlock (uint256 _amount, uint256 _blockReward, uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus) public view returns (uint256, uint256, uint256) {
        FarmParameters memory params;
        params.fee = _amount.mul(gFees.tokenFee).div(1000);
        params.amountMinusFee = _amount.sub(params.fee);
        params.bonusBlocks = _bonusEndBlock.sub(_startBlock);
        params.totalBonusReward = params.bonusBlocks.mul(_bonus).mul(_blockReward);
        params.numBlocks = params.amountMinusFee.sub(params.totalBonusReward).div(_blockReward);
        params.endBlock = params.numBlocks.add(params.bonusBlocks).add(_startBlock);
        
        uint256 nonBonusBlocks = params.endBlock.sub(_bonusEndBlock);
        uint256 effectiveBlocks = params.bonusBlocks.mul(_bonus).add(nonBonusBlocks);
        uint256 requiredAmount = _blockReward.mul(effectiveBlocks);
        return (params.endBlock, requiredAmount, requiredAmount.mul(gFees.tokenFee).div(1000));
    }
    
    /**
     * @notice Determine the blockReward based on inputs specifying an end date. Used on the front end to show the exact settings the Farm contract will be deployed with
     */
    function determineBlockReward (uint256 _amount, uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus, uint256 _endBlock) public view returns (uint256, uint256, uint256) {
        uint256 fee = _amount.mul(gFees.tokenFee).div(1000);
        uint256 amountMinusFee = _amount.sub(fee);
        uint256 bonusBlocks = _bonusEndBlock.sub(_startBlock);
        uint256 nonBonusBlocks = _endBlock.sub(_bonusEndBlock);
        uint256 effectiveBlocks = bonusBlocks.mul(_bonus).add(nonBonusBlocks);
        uint256 blockReward = amountMinusFee.div(effectiveBlocks);
        uint256 requiredAmount = blockReward.mul(effectiveBlocks);
        return (blockReward, requiredAmount, requiredAmount.mul(gFees.tokenFee).div(1000));
    }
    
    /**
     * @notice Creates a new Farm contract and registers it in the FarmFactory.sol. All farming rewards are locked in the Farm Contract
     */
    function createFarm (IERC20 _rewardToken, uint256 _amount,
                 IERC20 _lpToken, uint256 _blockReward,
                 uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus
    ) 
        public payable returns (address) 
    {
        require(_startBlock > block.number, 'START'); // ideally at least 24 hours more to give farmers time
        require(_bonus > 0, 'BONUS');
        require(address(_rewardToken) != address(0), 'TOKEN');
        require(_blockReward > 1000, 'BR'); // minimum 1000 divisibility per block reward
        
        // ensure this pair is on uniswap by querying the factory
        IUniswapV2Pair lpair = IUniswapV2Pair(address(_lpToken));
        address factoryPairAddress = uniswapFactory.getPair(lpair.token0(), lpair.token1());
        require(factoryPairAddress == address(_lpToken), 'This pair is not on uniswap');
        
        FarmParameters memory params;
        (params.endBlock, params.requiredAmount, params.amountFee) = determineEndBlock(_amount, _blockReward, _startBlock, _bonusEndBlock, _bonus);
        
        require(msg.value == gFees.ethFee, 'Fee not met');
        devaddr.transfer(msg.value);
        
        if (gFees.useGasToken) {
            TransferHelper.safeTransferFrom(address(gFees.gasToken), address(msg.sender), address(this), gFees.gasFee);
            gFees.gasToken.burn(gFees.gasFee);
        }
        
        TransferHelper.safeTransferFrom(address(_rewardToken), address(msg.sender), address(this), params.requiredAmount.add(params.amountFee));
        Farm01 newFarm = new Farm01(address(factory), address(this));
        TransferHelper.safeApprove(address(_rewardToken), address(newFarm), params.requiredAmount);
        newFarm.init(_rewardToken, params.requiredAmount, _lpToken, _blockReward, _startBlock, params.endBlock, _bonusEndBlock, _bonus);
        
        TransferHelper.safeTransfer(address(_rewardToken), devaddr, params.amountFee);
        factory.registerFarm(address(newFarm));
        return (address(newFarm));
    }
    
}