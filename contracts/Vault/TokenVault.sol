pragma solidity 0.6.12;

import "../../interfaces/IERC20.sol";
import "../Utils/SafeMathPlus.sol";
import "../Utils/SafeTransfer.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract TokenVault is SafeTransfer {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    struct Item{
        uint256 amount;
        uint256 unlockTime;
        address owner;
        uint256 userIndex;
    }

    struct UserInfo{
        mapping(address => uint256[]) lockToItems;
        EnumerableSet.AddressSet lockedItemsWithUser;
    }   

    mapping (address => UserInfo) users;

    uint256 public depositId;
    uint256[] public allDepositIds;
    mapping (uint256 => Item) public lockedItem;
    
    event onLock(address tokenAddress, address user, uint256 amount);
    event onUnlock(address tokenAddress,uint256 amount);

    function lockTokens(
            address _tokenAddress, 
            uint256 _amount, 
            uint256 _unlockTime,
            address payable _withdrawer) public returns (uint256 _id){
        
        require(_amount > 0, 'token amount is Zero');
        require(_unlockTime < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
        _safeTransferFrom(_tokenAddress, msg.sender, _amount);

        _id = ++depositId;

        
        lockedItem[_id].amount = _amount;
        lockedItem[_id].unlockTime = _unlockTime;
        lockedItem[_id].owner = _withdrawer;

        allDepositIds.push(_id);
        /* UserInfo storage user_token = users[_withdrawer];
        user_token.lockToItems[_tokenAddress].push(item.nonce); */

        UserInfo storage userItem = users[_withdrawer];
        
        userItem.lockedItemsWithUser.add(_tokenAddress);

        userItem.lockToItems[_tokenAddress].push(_id);
        uint256  userIndex = userItem.lockToItems[_tokenAddress].length - 1;
        lockedItem[_id].userIndex = userIndex;
        emit  onLock(_tokenAddress, msg.sender,lockedItem[_id].amount);
    }

    function withdrawTokens(
                    address _tokenAddress, 
                    uint256 _index, 
                    uint256 _id, 
                    uint256 _amount) external{
                        
        require(_amount > 0, 'token amount is Zero');
        uint256 id = users[msg.sender].lockToItems[_tokenAddress][_index];
        Item storage userItem = lockedItem[id];
        require(id == _id && userItem.owner == msg.sender, 'LOCK MISMATCH');
        require(userItem.unlockTime < block.timestamp, 'Not unlocked yet');
        userItem.amount = userItem.amount.sub(_amount);

        if(userItem.amount == 0){
            uint256[] storage userItems = users[msg.sender].lockToItems[_tokenAddress];
            userItems[_index] = userItems[userItems.length -1];
            userItems.pop();
        }

        _safeTransfer(_tokenAddress, msg.sender, _amount);

        emit onUnlock(_tokenAddress, _amount);
    }

    function getItemAtUserIndex(uint256 _index,
                                address _tokenAddress,
                                 address _user)
                                external view
                                returns(uint256, uint256, address, uint256)
    {   
        uint256 id = users[_user].lockToItems[_tokenAddress][_index];
        Item storage item =  lockedItem[id];
        return (item.amount, item.unlockTime, item.owner, id);
        
    }

    function getUserLockedItemAtIndex(address _user, uint256 _index) external view returns (address) {
        UserInfo storage user = users[_user];
        return user.lockedItemsWithUser.at(_index);
    }

    function getLockedItemAtId(uint256 _id) external view returns (uint256, uint256, address, uint256){
        Item storage item =  lockedItem[_id];
        return (item.amount, item.unlockTime, item.owner,item.userIndex);
    }    
    
}