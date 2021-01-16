pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoAuction.sol";
import "../interfaces/IMisoCrowdsale.sol";
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

    /// @notice mapping from market template id to market template address
    mapping(uint256 => address) private auctionTemplates;

    /// @notice mapping from market template address to market template id
    mapping(address => uint256) private auctionTemplateToId;

    /// @notice mapping from auction created through this contract to Auction struct
    mapping(address => Auction) public auctionInfo;
    
    /// @notice Template id to track respective auction template
    uint256 public auctionTemplateId;

    /// @notice Auctions created using factory
    address[] public auctions;

    ///@notice event emitted when first initializing the Market factory
    event MisoInitMarket(address sender);

    /// @notice event emitted when template is added to factory 
    event AuctionTemplateAdded(address newAuction, uint256 templateId);

    /// @notice event emitted when auction template is removed
    event AuctionTemplateRemoved(address auction, uint256 templateId);

    /// @notice event emitted when auction is created using template id
    event AuctionCreated(address indexed owner, address indexed addr, address auctionTemplate);

    constructor() public {
    }

    /**
     * @dev Single gateway to initialize the MISO Market with proper address
     * @dev Can only be initialized once
     * @param _templates Initial array of templates that the Market can use
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


    /**
     * @dev Creates a Auction cooresponding to _templateId
     * @dev Initializes auction with the parameters passed
     * @param _token Address of token to be auctioned
     * @param _tokenSupply Total number of tokens to be auctioned
     * @param _startDate Start date for the auction
     * @param _endDate End date for the auction
     * @param _paymentCurrency The currency the Auction accepts for payment. Can be ETH or token address
     * @param _startPrice Price you want to start auction. This should be maximum price you want token to be valued at
     * @param _minimumPrice Minimum price that the token should be valued for successful Auction
     * @param _wallet Address where collected funds will be forwarded to
     * @param _templateId Id of the auction template to create
    */
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
    
    /**
     * @dev Creates a Crowdsale corresponding to _templateId
     * @dev Initializes Crowdsale with the parameter passed
     * @param _token Address of the token for crowdsale
     * @param _tokenSupply The total number of tokens to sell in crowdsale 
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address
     * @param _startDate Crowdsale start date
     * @param _endDate Crowdsale end date
     * @param _rate Number of token units a buyer gets per wei or token
     * @param _goal Minimum amount of funds to be raised in weis or tokens
     * @param _wallet Address where collected funds will be forwarded to
     * @param _templateId Id of the crowdsale template to create
    */
    function createCrowdsale(
        address _token, 
        uint256 _tokenSupply, 
        address _paymentCurrency,
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
        IMisoCrowdsale(newCrowdsale).initCrowdsale(address(this), _token, _paymentCurrency, _tokenSupply, _startDate, _endDate, _rate, _goal, _wallet);
        emit AuctionCreated(msg.sender, address(newCrowdsale), auctionTemplates[_templateId]);
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
        require(auctionTemplateToId[_template] == 0, "MISOMarket.addAuctionTemplate: Template already exists");
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
        auctionTemplateToId[template] = 0;
        emit AuctionTemplateRemoved(template, _templateId);
    }

    function _addAuctionTemplate(address _template) internal {
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
