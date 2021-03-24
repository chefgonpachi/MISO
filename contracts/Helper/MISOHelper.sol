pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/IERC20.sol";
import "../../interfaces/IMisoTokenFactory.sol";
import "../Access/MISOAccessControls.sol";


interface IBaseAuction {
    function getBaseInformation() external view returns (
            address auctionToken,
            uint64 startTime,
            uint64 endTime,
            bool finalized
        );
}

interface IMisoMarketFactory {
    function getMarketTemplateId(address _auction) external view returns(uint64);
    function getMarkets() external view returns(address[] memory);
}

interface IMisoMarket {
    function paymentCurrency() external view returns (address) ;
    function auctionToken() external view returns (address) ;
    function marketPrice() external view returns (uint128, uint128);
    function marketInfo()
        external
        view
        returns (
        uint64 startTime,
        uint64 endTime,
        uint128 totalTokens
        );

}

interface ICrowdsale is IMisoMarket {
    function marketStatus() external view returns(
        uint128 amountRaised,
        bool initialized, 
        bool finalized,
        bool hasPointList
    );
}

interface IDutchAuction is IMisoMarket {
    function marketStatus() external view returns(
        uint128 commitmentsTotal,
        bool initialized,
        bool finalized,
        bool hasPointList
    );
    // function totalTokensCommitted() external view returns (uint256);
    // function clearingPrice() external view returns (uint256);
}

interface IBatchAuction is IMisoMarket {
    function marketStatus() external view returns(
        uint256 commitmentsTotal,
        uint256 minimumCommitmentAmount,
        bool initialized,
        bool finalized,
        bool hasPointList
    );
}

interface IHyperbolicAuction is IMisoMarket {
    function marketStatus() external view returns(
        uint128 commitmentsTotal,
        bool initialized, 
        bool finalized,
        bool hasPointList
    );
}

interface IDocument {
    function getDocument(bytes32 _name) external view returns (string memory, bytes32, uint256);
    function getAllDocuments() external view returns (bytes32[] memory);
}

contract TokenHelper {
    struct TokenInfo {
        address addr;
        uint256 decimals;
        string name;
        string symbol;
    }

    function getTokensInfo(address[] memory addresses) public view returns (TokenInfo[] memory)
    {
        TokenInfo[] memory infos = new TokenInfo[](addresses.length);

        for (uint256 i = 0; i < addresses.length; i++) {
            infos[i] = getTokenInfo(addresses[i]);
        }

        return infos;
    }

    function getTokenInfo(address _address) public view returns (TokenInfo memory) {
        TokenInfo memory info;
        IERC20 token = IERC20(_address);

        info.addr = _address;
        info.name = token.name();
        info.symbol = token.symbol();
        // info.decimals = token.decimals();

        return info;
    }
}

contract DocumentHepler {
    struct Document {
        bytes32 docHash;
        uint256 lastModified;
        string uri;
    }

    function getDocuments(address _document) public view returns(Document[] memory) {
        IDocument document = IDocument(_document);
        bytes32[] memory documentNames = document.getAllDocuments();
        Document[] memory documents = new Document[](documentNames.length);

        for(uint256 i = 0; i < documentNames.length; i++) {
            (
                documents[i].uri,
                documents[i].docHash,
                documents[i].lastModified
            ) = document.getDocument(documentNames[i]);
        }

        return documents;
    }
}



contract MISOHelper is TokenHelper, DocumentHepler {
    IMisoMarketFactory public market;
    IMisoTokenFactory public tokenFactory;
    address public launcher;
    address public farmFactory;

    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    struct CrowdsaleInfo {
        address addr;
        address paymentCurrency;
        uint128 amountRaised;
        uint128 totalTokens;
        uint128 rate;
        uint128 goal;
        uint64 startTime;
        uint64 endTime;
        bool finalized;
        bool hasPointList;
        TokenInfo tokenInfo;
        Document[] documents;
    }

    struct DutchAuctionInfo {
        address addr;
        address paymentCurrency;
        uint64 startTime;
        uint64 endTime;
        uint128 totalTokens;
        uint128 startPrice;
        uint128 minimumPrice;
        uint128 commitmentsTotal;
        // uint256 totalTokensCommitted;
        bool finalized;
        bool hasPointList;
        TokenInfo tokenInfo;
        Document[] documents;
    }

    struct BatchAuctionInfo {
        address addr;
        address paymentCurrency;
        uint64 startTime;
        uint64 endTime;
        uint128 totalTokens;
        uint256 commitmentsTotal;
        uint256 minimumCommitmentAmount;
        bool finalized;
        bool hasPointList;
        TokenInfo tokenInfo;
        Document[] documents;
    }

    struct HyperbolicAuctionInfo {
        address addr;
        address paymentCurrency;
        uint64 startTime;
        uint64 endTime;
        uint128 totalTokens;
        uint128 minimumPrice;
        uint128 alpha;
        uint128 commitmentsTotal;
        bool finalized;
        bool hasPointList;
        TokenInfo tokenInfo;
        Document[] documents;
    }

    struct MarketBaseInfo {
        address addr;
        uint64 templateId;
        uint64 startTime;
        uint64 endTime;
        bool finalized;
        TokenInfo tokenInfo;
    }

    struct PLInfo {
        TokenInfo token0;
        TokenInfo token1;
        address pairToken;
        address operator;
        uint256 locktime;
        uint256 unlock;
        uint256 deadline;
        uint256 launchwindow;
        uint256 expiry;
        uint256 liquidityAdded;
        uint256 launched;
    }

    struct UserMarketInfo {
        uint256 commitments;
        uint256 claimed;
        bool isOperator;
    }

    constructor(
        address _accessControls,
        address _tokenFactory,
        address _market,
        address _launcher,
        address _farmFactory
    ) public { 
        require(_accessControls != address(0));
        accessControls = MISOAccessControls(_accessControls);
        tokenFactory = IMisoTokenFactory(_tokenFactory);
        market = IMisoMarketFactory(_market);
        launcher = _launcher;
        farmFactory = _farmFactory;
    }

    function setContracts( address _tokenFactory, address _market, address _launcher, address _farmFactory) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOHelper: Sender must be Admin"
        );
        if (_market != address(0)) {
            market = IMisoMarketFactory(_market);
        }
        if (_tokenFactory != address(0)) {
            tokenFactory = IMisoTokenFactory(_tokenFactory);
        }
        if (_launcher != address(0)) {
            launcher = _launcher;
        }
        if (_farmFactory != address(0)) {
            farmFactory = _farmFactory;
        }
    }

    function getTokens() public view returns(TokenInfo[] memory) {
        address[] memory tokens = tokenFactory.getTokens();
        TokenInfo[] memory infos = getTokensInfo(tokens);

        infos = getTokensInfo(tokens);

        return infos;
    }

    function getMarkets() public view returns (MarketBaseInfo[] memory) {
        address[] memory markets = market.getMarkets();
        MarketBaseInfo[] memory infos = new MarketBaseInfo[](markets.length);

        for (uint256 i = 0; i < markets.length; i++) {
            uint64 templateId = market.getMarketTemplateId(markets[i]);
            address auctionToken;
            uint64 startTime;
            uint64 endTime;
            bool finalized;
            (auctionToken, startTime, endTime, finalized) = IBaseAuction(markets[i])
                .getBaseInformation();
            TokenInfo memory tokenInfo = getTokenInfo(auctionToken);

            infos[i].addr = markets[i];
            infos[i].templateId = templateId;
            infos[i].startTime = startTime;
            infos[i].endTime = endTime;
            infos[i].finalized = finalized;
            infos[i].tokenInfo = tokenInfo;
        }

        return infos;
    }

    function getCrowdsaleInfo(address _crowdsale) public view returns (CrowdsaleInfo memory) {
        ICrowdsale crowdsale = ICrowdsale(_crowdsale);
        CrowdsaleInfo memory info;

        info.addr = address(crowdsale);
        info.paymentCurrency = crowdsale.paymentCurrency();
        (info.amountRaised, ,info.finalized, info.hasPointList) = crowdsale.marketStatus();
        (info.startTime, info.endTime, info.totalTokens) = crowdsale.marketInfo();
        (info.rate, info.goal) = crowdsale.marketPrice();
        info.tokenInfo = getTokenInfo(crowdsale.auctionToken());
        info.documents = getDocuments(_crowdsale);

        return info;
    }

    function getDutchAuctionInfo(address payable _dutchAuction) public view returns (DutchAuctionInfo memory)
    {
        IDutchAuction dutchAuction = IDutchAuction(_dutchAuction);
        DutchAuctionInfo memory info;

        info.addr = address(dutchAuction);
        info.paymentCurrency = dutchAuction.paymentCurrency();
        // info.totalTokensCommitted = dutchAuction.totalTokensCommitted();
        // info.totalTokensCommitted = dutchAuction.clearingPrice();
        (info.startTime, info.endTime, info.totalTokens) = dutchAuction.marketInfo();
        (info.startPrice, info.minimumPrice) = dutchAuction.marketPrice();
        (
            info.commitmentsTotal,
            ,
            info.finalized,
            info.hasPointList
        ) = dutchAuction.marketStatus();
        info.tokenInfo = getTokenInfo(dutchAuction.auctionToken());
        info.documents = getDocuments(_dutchAuction);

        return info;
    }

    function getBatchAuctionInfo(address payable _batchAuction) public view returns (BatchAuctionInfo memory) 
    {
        IBatchAuction batchAuction = IBatchAuction(_batchAuction);
        BatchAuctionInfo memory info;
        
        info.addr = address(batchAuction);
        info.paymentCurrency = batchAuction.paymentCurrency();
        (info.startTime, info.endTime, info.totalTokens) = batchAuction.marketInfo();
        (
            info.commitmentsTotal,
            info.minimumCommitmentAmount,
            ,
            info.finalized,
            info.hasPointList
        ) = batchAuction.marketStatus();
        info.tokenInfo = getTokenInfo(batchAuction.auctionToken());
        info.documents = getDocuments(_batchAuction);

        return info;
    }

    function getHyperbolicAuctionInfo(address payable _hyperbolicAuction) public view returns (HyperbolicAuctionInfo memory)
    {
        IHyperbolicAuction hyperbolicAuction = IHyperbolicAuction(_hyperbolicAuction);
        HyperbolicAuctionInfo memory info;

        info.addr = address(hyperbolicAuction);
        info.paymentCurrency = hyperbolicAuction.paymentCurrency();
        (info.startTime, info.endTime, info.totalTokens) = hyperbolicAuction.marketInfo();
        (info.minimumPrice, info.alpha) = hyperbolicAuction.marketPrice();
        (
            info.commitmentsTotal,
            ,
            info.finalized,
            info.hasPointList
        ) = hyperbolicAuction.marketStatus();
        info.tokenInfo = getTokenInfo(hyperbolicAuction.auctionToken());
        info.documents = getDocuments(_hyperbolicAuction);

        return info;
    }

}
