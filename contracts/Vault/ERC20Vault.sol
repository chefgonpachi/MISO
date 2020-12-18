pragma solidity ^0.6.9;

import "../Tokens/BokkyPooBahsFixedSupplyTokenFactory.sol";
import "../Utils/Owned.sol";
import "../../interfaces/IERC20.sol";
import "../Utils/SafeMathPlus.sol";
contract ERC20Vault is Owned{
    using SafeMathPlus for uint256;

    uint256 public unlockDate;
   
    //add super admin that can have authority to approve the token to transfer to any contractAddress?
    //Refer to CORE vault for more superadmin stuff
   
    //address private _superAdmin;
   
    // Does it need to be indexed?
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
    // Info of each user that stakes  tokens. (poolId => (userAddress => userInfo))
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    function initERC20Vault() public{
        _initOwned((msg.sender));
        /* unlockDate = _unlockDate; */
    }

  /*   function updateUnlockDate(uint256 _newDate) public {
        require(isOwner());
        require(_newDate > unlockDate, "Date specified is less than current unlock date");
        unlockDate = _newDate;
    } */
    
    
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
    }
    

    // Update the given pool's ability to withdraw tokens
    function setPoolWithdrawable(uint256 _pid, bool _withdrawable
    ) public  {
        require(isOwner());
        poolInfo[_pid].withdrawable = _withdrawable;
    }
    
    //Have to do more checks
    function updatePoolEndDate(uint256 _pid, uint256 _duration) public{
        require(isOwner());
        PoolInfo storage pool = poolInfo[_pid];
        pool.endDate = block.timestamp.add(_duration);
    }
    // Deposit  tokens to Vault.
    function deposit(uint256 _pid, uint256 _amount) public{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        pool.token.transferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public{
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.withdrawable, "Withdrawing from pool is disabled");
        require(now >= pool.endDate, "Timelock: Funds cannot be withdrawn yet");
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >=_amount,"withdraw: unsufficient funds in the pool");
        user.amount = user.amount.sub(_amount);
        pool.token.transfer(address(msg.sender),_amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    //No Timelock implemented
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.withdrawable,"Withdrawing from pool disabled");
        UserInfo storage user = userInfo[_pid][msg.sender];
        user.amount = 0;
        pool.token.transfer(msg.sender,user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    //To set allowance of ERC20 to a particular contractAddress. Good or not? Only owner can call. May add superadmin too.
    function setContractAllowance(address tokenAddress, uint256 _amount,address contractAddress) public{
        
        // Can be superadmin
        require(isOwner());
        require(isContract(contractAddress));
        IERC20(tokenAddress).approve(contractAddress, _amount);
    }

    function isContract(address addr) public returns (bool){
        uint size;
        assembly { size:= extcodesize(addr) }
        return size > 0;
    }

}
