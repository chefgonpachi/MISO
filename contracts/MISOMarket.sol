pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoMarket.sol";
import "../interfaces/IERC20.sol";
import "./Access/MISOAccessControls.sol";


contract MISOMarket is CloneFactory {

    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised;    

    /// @notice Struct to track Auction template
    struct Auction {
        bool exists;
        uint256 templateId;
        uint256 index;
    }

    /// @notice Auctions created using factory
    address[] public auctions;

    /// @notice Template id to track respective auction template
    uint256 public auctionTemplateId;

    /// @notice mapping from market template id to market template address
    mapping(uint256 => address) private auctionTemplates;

    /// @notice mapping from market template address to market template id
    mapping(address => uint256) private auctionTemplateToId;

    /// @notice mapping from auction created through this contract to Auction struct
    mapping(address => Auction) public auctionInfo;

    /// @notice Minimum fee to create a farm through the factory
    uint256 public minimumFee;
    uint256 public tokenFee;

    ///@notice Any donations if set are sent here
    address payable public misoDiv;

    ///@notice event emitted when first initializing the Market factory
    event MisoInitMarket(address sender);

    /// @notice event emitted when template is added to factory 
    event AuctionTemplateAdded(address newAuction, uint256 templateId);

    /// @notice event emitted when auction template is removed
    event AuctionTemplateRemoved(address auction, uint256 templateId);

    /// @notice event emitted when auction is created using template id
    event MarketCreated(address indexed owner, address indexed addr, address marketTemplate);

    constructor() public {
    }

    /**
     * @dev Can only be initialized once
     * @param _templates Initial array of MISOMarket templates 
     */
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

    function setMinimumFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setminimumFee: Sender must be operator"
        );
        minimumFee = _amount;
    }
    
    function setTokenFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setTokenFee: Sender must be operator"
        );
        tokenFee = _amount;
    }    
    
    function setDividends(address payable _divaddr) public  {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setDev: Sender must be operator"
        );
        misoDiv = _divaddr;
    }

    /**
     * @dev Creates a new MISOMarket from template _templateId
     * @param _templateId Id of the crowdsale template to create
    */

    // GP: Add fees like Token Factory
    function deployMarket(
        uint256 _templateId
    )
        public
        payable
        returns (address newMarket)
    {
        require(msg.value >= minimumFee, 'Failed to transfer minimumFee');
        require(auctionTemplates[_templateId] != address(0));
        newMarket = createClone(auctionTemplates[_templateId]);
        auctionInfo[address(newMarket)] = Auction(true, _templateId, auctions.length - 1);
        auctions.push(address(newMarket));
        emit MarketCreated(msg.sender, address(newMarket), auctionTemplates[_templateId]);
        if (msg.value > 0) {
            misoDiv.transfer(msg.value);
        }
    }

    /**
     * @dev Creates a new MISOMarket using _templateId
     * @dev Initializes auction with the parameters passed
     * @param _templateId Id of the auction template to create
     * @param _data - Data to be sent to template on Init
    */
    function createMarket(
        uint256 _templateId,
        address _token,
        uint256 _tokenSupply,
        bytes calldata _data
    ) external returns (address newMarket) {
        newMarket = deployMarket(_templateId);
        if (_tokenSupply > 0) {
            require(IERC20(_token).transferFrom(msg.sender, address(this), _tokenSupply)); 
            require(IERC20(_token).approve(newMarket, _tokenSupply));  
        }
        IMisoMarket(newMarket).initMarket(_data);
        return newMarket;
    }


    /**
     * @dev Function to add a action template to create through factory
     * @dev Should have operator access
     * @param _template Auction template to create a auction
     */
    function addAuctionTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket.addAuctionTemplate: Sender must be operator"
        );
        _addAuctionTemplate(_template);    
    }

     /**
     * @dev Function to remove a Launcher template
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
    function removeAuctionTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket.removeAuctionTemplate: Sender must be operator"
        );
        require(auctionTemplates[_templateId] != address(0));
        address template = auctionTemplates[_templateId];
        auctionTemplates[_templateId] = address(0);
        delete auctionTemplateToId[template];
        emit AuctionTemplateRemoved(template, _templateId);
    }

    function _addAuctionTemplate(address _template) internal {
        require(
            auctionTemplateToId[_template] == 0,
            "MISOMarket._addAuctionTemplate: Template already exists"
        );
        auctionTemplateId++;
        auctionTemplates[auctionTemplateId] = _template;
        auctionTemplateToId[_template] = auctionTemplateId;
        emit AuctionTemplateAdded(_template, auctionTemplateId);
    }

    /// @dev Get the address of the auction template
    function getAuctionTemplate(uint256 _templateId) public view returns (address tokenTemplate) {
        return auctionTemplates[_templateId];
    }
    
    /// @dev Get the template id of the auction template
    function getTemplateId(address _auctionTemplate) public view returns (uint256) {
        return auctionTemplateToId[_auctionTemplate];
    }

    /// @dev Get total number of auctions in the factory
    function numberOfAuctions() public view returns (uint) {
        return auctions.length;
    }

}
