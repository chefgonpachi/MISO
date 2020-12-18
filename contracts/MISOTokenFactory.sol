pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoToken.sol";
import "./Access/MISOAccessControls.sol";


contract MISOTokenFactory is CloneFactory {

    MISOAccessControls public accessControls;

    bool private initialised;
    address[] public tokens;
    uint256 public tokenTemplateId;
    
    mapping(uint256 => address) private tokenTemplates;
    mapping(address => bool) public isChildToken;


    // GP: Add more data to events
    event MisoInitTokenFactory(address sender);
    event TokenCreated(address indexed owner, address indexed addr, string name, string symbol, address tokenTemplate);
    event TokenTemplateAdded(address newToken, uint256 templateId);
    event TokenTemplateRemoved(address token, uint256 templateId);

    constructor() public {
    }

    function initMISOTokenFactory(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitTokenFactory(msg.sender);
    }

    function createToken(string memory _name, string memory _symbol, uint256 _templateId) external returns (address token) {
        require(tokenTemplates[_templateId] != address(0));
        token = createClone(tokenTemplates[_templateId]);
        isChildToken[address(token)] = true;
        tokens.push(address(token));
        IMisoToken(token).initToken(_name, _symbol, msg.sender);
        emit TokenCreated(msg.sender, address(token), _name, _symbol, tokenTemplates[_templateId]);
    }

    function addTokenTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory.addTokenTemplate: Sender must be operator"
        );
        tokenTemplateId++;
        tokenTemplates[tokenTemplateId] = _template;
        emit TokenTemplateAdded(_template, tokenTemplateId);
    }

    function removeTokenTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory.removeTokenTemplate: Sender must be operator"
        );
        require(tokenTemplates[_templateId] != address(0));
        address template = tokenTemplates[_templateId];
        tokenTemplates[_templateId] = address(0);
        emit TokenTemplateRemoved(template, _templateId);
    }

    // getter functions
    function getTokenTemplate(uint256 templateId) public view returns (address tokenTemplate) {
        return tokenTemplates[templateId];
    }

    function numberOfTokens() public view returns (uint256) {
        return tokens.length;
    }

    function getTemplateId(address _tokenTemplate) public view returns (uint256) {
        for(uint i = 1; i <= tokenTemplateId; i++) {
            if(tokenTemplates[i] == _tokenTemplate) {
                return i;
            }
        }
    }

}
