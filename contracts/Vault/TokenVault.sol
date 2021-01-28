pragma solidity ^0.6.9;

import "../Utils/Owned.sol";
import "../../interfaces/IERC20.sol";
import "../Utils/SafeMathPlus.sol";

contract TokenVault is Owned {
    using SafeMathPlus for uint256;
   
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user,uint256 indexed pid,uint256 amount);

    struct UserInfo{
        uint256 amount; // How many  tokens the user has provided
    }

    struct PoolInfo{
        IERC20 token;
        bool withdrawable;
        uint256 endDate;
    }
    // Info of each user that stakes tokens. (poolId => (userAddress => userInfo))
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    mapping(address => uint256) tokenId;
    function initERC20Vault() public{
        _initOwned(msg.sender);
    }


    // Add a new token pool. Can only be called by the owner. 
    function add(IERC20 _token, bool _withdrawable, uint256 _duration) public{
        require(isOwner());
        uint256 endDate = block.timestamp.add(_duration);

        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token,"Error pool already added");
        }
        
        poolInfo.push(PoolInfo({
            token:_token,
            withdrawable: _withdrawable,
            endDate: endDate
        }));
        tokenId[address(_token)] = poolInfo.length - 1;
    }

    // Update the given pool's ability to withdraw tokens
    function setPoolWithdrawable(uint256 _pid, bool _withdrawable) public {
        require(isOwner());
        poolInfo[_pid].withdrawable = _withdrawable;
    }
    
    //Have to do more checks
    function updatePoolEndDate(uint256 _pid, uint256 _endDate) public {
        require(isOwner());
        PoolInfo storage pool = poolInfo[_pid];
        pool.endDate = _endDate;
    }

    // Deposit tokens to Vault.
    // GP: Replace pid with token address
    // GP: Have an index pointer from token address to pid
    function deposit(address _token, uint256 _amount, address _withdrawAddress) public {
        uint256 pid = tokenId[_token];
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][_withdrawAddress];

        pool.token.transferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        emit Deposit(msg.sender, pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.withdrawable, "Withdrawing from pool is disabled");
        require(now >= pool.endDate, "Timelock: Funds cannot be withdrawn yet");
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >=_amount,"withdraw: unsufficient funds in the pool");
        user.amount = user.amount.sub(_amount);
        pool.token.transfer(address(msg.sender),_amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }


}
