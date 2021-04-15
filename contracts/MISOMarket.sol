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


import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoMarket.sol";
import "../interfaces/IERC20.sol";
import "./Access/MISOAccessControls.sol";
import "./Utils/SafeTransfer.sol";

import "../../interfaces/IBentoBoxFactory.sol";


contract MISOMarket is CloneFactory, SafeTransfer {

    /// @notice Responsible for access rights to the contract.
    MISOAccessControls public accessControls;

    /// @notice Whether market has been initialized or not.
    bool private initialised;

    /// @notice Struct to track Auction template.
    struct Auction {
        bool exists;
        uint64 templateId;
        uint128 index;
    }

    /// @notice Auctions created using factory.
    address[] public auctions;

    /// @notice Template id to track respective auction template.
    uint256 public auctionTemplateId;

    IBentoBoxFactory public bentoBox;

    /// @notice Mapping from market template id to market template address.
    mapping(uint256 => address) private auctionTemplates;

    /// @notice Mapping from market template address to market template id.
    mapping(address => uint256) private auctionTemplateToId;

    /// @notice Mapping from auction created through this contract to Auction struct.
    mapping(address => Auction) public auctionInfo;

    /// @notice Struct to define fees.
    struct MarketFees {
        uint128 minimumFee;
        uint32 integratorFeePct;
    }

    /// @notice Minimum fee to create a farm through the factory.
    MarketFees public marketFees;

    ///@notice Any donations if set are sent here.
    address payable public misoDiv;

    ///@notice Event emitted when first initializing the Market factory.
    event MisoInitMarket(address sender);

    /// @notice Event emitted when template is added to factory.
    event AuctionTemplateAdded(address newAuction, uint256 templateId);

    /// @notice Event emitted when auction template is removed.
    event AuctionTemplateRemoved(address auction, uint256 templateId);

    /// @notice Event emitted when auction is created using template id.
    event MarketCreated(address indexed owner, address indexed addr, address marketTemplate);

    /// @notice event emitted when auction is created using template id
    event MarketInitialized(address indexed addr, uint256 templateId, bytes data);

    constructor() public {
    }

    /**
     * @notice Initializes the market with a list of auction templates.
     * @dev Can only be initialized once.
     * @param _accessControls Sets address to get the access controls from.
     * @param _templates Initial array of MISOMarket templates.
     */
    function initMISOMarket(address _accessControls, address _bentoBox, address[] memory _templates) external {
        /// @dev Maybe missing require message?
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);

        bentoBox = IBentoBoxFactory(_bentoBox);

        auctionTemplateId = 0;
        for(uint i = 0; i < _templates.length; i++) {
            _addAuctionTemplate(_templates[i]);
        }

        initialised = true;
        emit MisoInitMarket(msg.sender);
    }

    /**
     * @notice Sets the minimum fee.
     * @param _amount Fee amount.
     */
    function setMinimumFee(uint256 _amount) external {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOMarket: Sender must be operator"
        );
        marketFees.minimumFee = uint128(_amount);
    }

    /**
     * @notice Sets the BentoBox address.
     * @param _bentoBox BentoBox address.
     */
    function setBentoBox(address _bentoBox) external {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOMarket: Sender must be operator"
        );
        bentoBox = IBentoBoxFactory(_bentoBox);
    }

    /**
     * @notice Sets integrator fee percentage.
     * @param _amount Percentage amount.
     */
    function setIntegratorFeePct(uint256 _amount) external {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOMarket: Sender must be operator"
        );
        /// @dev this is out of 1000, ie 25% = 250
        require(_amount <= 1000, "MISOMarket: Percentage is out of 1000");
        marketFees.integratorFeePct = uint32(_amount);
    }

    /**
     * @notice Sets dividend address.
     * @param _divaddr Dividend address.
     */
    function setDividends(address payable _divaddr) external {
        require(accessControls.hasAdminRole(msg.sender), "MISOFarmFactory.setDev: Sender must be operator");
        require(_divaddr != address(0));
        misoDiv = _divaddr;
    }

    /**
     * @notice Creates a new MISOMarket from template _templateId and transfers fees.
     * @param _templateId Id of the crowdsale template to create.
     * @param _integratorFeeAccount Address to pay the fee to.
     * @return newMarket Market address.
     */
    /// @dev GP: Add fees like Token Factory
    function deployMarket(
        uint256 _templateId,
        address payable _integratorFeeAccount
    )
        public payable returns (address newMarket)
    {
        MarketFees memory _marketFees = marketFees;
        address auctionTemplate = auctionTemplates[_templateId];
        require(msg.value >= uint256(_marketFees.minimumFee), "MISOMarket: Failed to transfer minimumFee");
        require(auctionTemplate != address(0), "MISOMarket: Auction template doesn't exist");
        uint256 integratorFee = 0;
        uint256 misoFee = msg.value;
        if (_integratorFeeAccount != address(0) && _integratorFeeAccount != misoDiv) {
            integratorFee = misoFee * uint256(_marketFees.integratorFeePct) / 1000;
            misoFee = misoFee - integratorFee;
        }
        newMarket = bentoBox.deploy(auctionTemplate, "", false);
        auctionInfo[address(newMarket)] = Auction(true, uint64(_templateId), uint128(auctions.length));
        auctions.push(address(newMarket));
        emit MarketCreated(msg.sender, address(newMarket), auctionTemplate);
        if (misoFee > 0) {
            misoDiv.transfer(misoFee);
        }
        if (integratorFee > 0) {
            _integratorFeeAccount.transfer(integratorFee);
        }
    }

    /**
     * @notice Creates a new MISOMarket using _templateId.
     * @dev Initializes auction with the parameters passed.
     * @param _templateId Id of the auction template to create.
     * @param _token The token address to be sold.
     * @param _tokenSupply Amount of tokens to be sold at market.
     * @param _integratorFeeAccount Address to send refferal bonus, if set.
     * @param _data Data to be sent to template on Init.
     * @return newMarket Market address.
     */
    function createMarket(
        uint256 _templateId,
        address _token,
        uint256 _tokenSupply,
        address payable _integratorFeeAccount,
        bytes calldata _data
    )
        external payable returns (address newMarket)
    {
        emit MarketInitialized(address(newMarket), _templateId, _data);
        newMarket = deployMarket(_templateId, _integratorFeeAccount);
        if (_tokenSupply > 0) {
            _safeTransferFrom(_token, msg.sender, _tokenSupply);
            require(IERC20(_token).approve(newMarket, _tokenSupply), "1");
        }
        IMisoMarket(newMarket).initMarket(_data);

        if (_tokenSupply > 0) {
            uint256 remainingBalance = IERC20(_token).balanceOf(address(this));
            if (remainingBalance > 0) {
                _safeTransfer(_token, msg.sender, remainingBalance);
            }
        }
        return newMarket;
    }

    /**
     * @notice Function to add an auction template to create through factory.
     * @dev Should have operator access.
     * @param _template Auction template to create an auction.
     */
    function addAuctionTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket: Sender must be operator"
        );
        _addAuctionTemplate(_template);    
    }

    /**
     * @dev Function to remove an auction template.
     * @dev Should have operator access.
     * @param _templateId Refers to template that is to be deleted.
     */
    function removeAuctionTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOMarket: Sender must be operator"
        );
        // require(auctionTemplates[_templateId] != address(0), "MISOMarket: Auction template doesn't exist");
        address template = auctionTemplates[_templateId];
        auctionTemplates[_templateId] = address(0);
        delete auctionTemplateToId[template];
        emit AuctionTemplateRemoved(template, _templateId);
    }

    /**
     * @notice Function to add an auction template to create through factory.
     * @param _template Auction template address to create an auction.
     */
    function _addAuctionTemplate(address _template) internal {
        require(
            auctionTemplateToId[_template] == 0,
            "MISOMarket: Template already exists"
        );
        auctionTemplateId++;
        auctionTemplates[auctionTemplateId] = _template;
        auctionTemplateToId[_template] = auctionTemplateId;
        emit AuctionTemplateAdded(_template, auctionTemplateId);
    }

    /**
     * @notice Get the address based on template ID.
     * @param _templateId Auction template ID.
     * @return Address of the required template ID.
     */
    function getAuctionTemplate(uint256 _templateId) external view returns (address) {
        return auctionTemplates[_templateId];
    }

    /**
     * @notice Get the ID based on template address.
     * @param _auctionTemplate Auction template address.
     * @return ID of the required template address.
     */
    function getTemplateId(address _auctionTemplate) external view returns (uint256) {
        return auctionTemplateToId[_auctionTemplate];
    }

    /**
     * @notice Get the total number of auctions in the factory.
     * @return Auction count.
     */
    function numberOfAuctions() external view returns (uint) {
        return auctions.length;
    }

    function minimumFee() external view returns(uint128) {
        return marketFees.minimumFee;
    }

    function getMarkets() external view returns(address[] memory) {
        return auctions;
    }

    function getMarketTemplateId(address _auction) external view returns(uint64) {
        return auctionInfo[_auction].templateId;
    }
}
