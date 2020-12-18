pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoAuction.sol";
import "../interfaces/IMisoCrowdsale.sol";
import "../interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Access/MISOAccessControls.sol";

contract MISOMarket is CloneFactory {
    using SafeMath for uint256;

    MISOAccessControls public accessControls;

    bool private initialised;    

    struct Auction {
        bool exists;
        uint256 templateId;
        uint256 index;
    }

    mapping(uint256 => address) private auctionTemplates;
    mapping(address => Auction) public auctionInfo;
    uint256 public auctionTemplateId;
    address[] public auctions;

    event MisoInitMarket(address sender);

    // GP: Add more data to events
    event AuctionTemplateAdded(address newAuction, uint256 templateId);
    event AuctionTemplateRemoved(address auction, uint256 templateId);
    event AuctionCreated(address indexed owner, address indexed addr, address auctionTemplate);

    constructor() public {
    }

    function initMISOMarket(address _accessControls, address[] memory _templates) external {
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);

        auctionTemplateId = 0;
        for(uint i = 0; i < _templates.length; i++) {
            _addAuctionTemplate(_templates[i]);
        }
        initialised = true;
        emit MisoInitMarket(msg.sender);
    }

    function createAuction(
        address _token, 
        uint256 _tokenSupply, 
        uint256 _startDate, 
        uint256 _endDate, 
        address _paymentCurrency,
        uint256 _startPrice, 
        uint256 _minimumPrice, 
        address payable _wallet,
        uint256 _templateId
    ) external returns (address newAuction) {
        require(auctionTemplates[_templateId] != address(0));
        newAuction = createClone(auctionTemplates[_templateId]);
        auctionInfo[address(newAuction)] = Auction(true, _templateId, auctions.length - 1);
        auctions.push(address(newAuction));
        require(IERC20(_token).transferFrom(msg.sender, address(this), _tokenSupply)); 
        require(IERC20(_token).approve(newAuction, _tokenSupply));
        IMisoAuction(newAuction).initAuction(address(this), _token, _tokenSupply, _startDate, _endDate, _paymentCurrency, _startPrice, _minimumPrice, _wallet);
        emit AuctionCreated(msg.sender, address(newAuction), auctionTemplates[_templateId]);
    }
    
    function createCrowdsale(
        address _token, 
        uint256 _tokenSupply, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _rate, 
        uint256 _goal, 
        address payable _wallet,
        uint256 _templateId
    ) external returns (address newCrowdsale) {
        require(auctionTemplates[_templateId] != address(0));
        newCrowdsale = createClone(auctionTemplates[_templateId]);
        auctionInfo[address(newCrowdsale)] = Auction(true, _templateId, auctions.length - 1);
        auctions.push(address(newCrowdsale));
        require(IERC20(_token).transferFrom(msg.sender, address(this), _tokenSupply)); 
        require(IERC20(_token).approve(newCrowdsale, _tokenSupply));
        IMisoCrowdsale(newCrowdsale).initCrowdsale(address(this), _token, _tokenSupply, _startDate, _endDate, _rate, _goal, _wallet);
        emit AuctionCreated(msg.sender, address(newCrowdsale), auctionTemplates[_templateId]);
    }
    
    function addAuctionTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket.addAuctionTemplate: Sender must be operator"
        );
        _addAuctionTemplate(_template);    
    }
    
    function removeAuctionTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket.removeAuctionTemplate: Sender must be operator"
        );
        require(auctionTemplates[_templateId] != address(0));
        address template = auctionTemplates[_templateId];
        auctionTemplates[_templateId] = address(0);
        emit AuctionTemplateRemoved(template, _templateId);
    }

    function _addAuctionTemplate(address _template) internal {
        auctionTemplateId++;
        auctionTemplates[auctionTemplateId] = _template;
        emit AuctionTemplateAdded(_template, auctionTemplateId);
    }

    // getter functions
    function getAuctionTemplate(uint256 _templateId) public view returns (address tokenTemplate) {
        return auctionTemplates[_templateId];
    }
    
    function getTemplateId(address _auctionTemplate) public view returns (uint256) {
        for(uint i = 1; i <= auctionTemplateId; i++) {
            if(auctionTemplates[i] == _auctionTemplate) {
                return i;
            }
        }
    }

    function numberOfAuctions() public view returns (uint) {
        return auctions.length;
    }

}
