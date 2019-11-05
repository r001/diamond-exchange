pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/Dpass.sol";

/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract TrustedDsToken {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function totalSupply() external view returns (uint);
    function balanceOf(address src) external view returns (uint);
    function allowance(address src, address guy) external view returns (uint);
}


contract TrustedErc721 {
    function transferFrom(address src, address to, uint256 amt) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}


contract TrustedErc20 {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function totalSupply() external view returns (uint);
    function balanceOf(address src) external view returns (uint);
    function allowance(address src, address guy) external view returns (uint);
}

contract TrustedCustodianLike {
    function removeAddress(address src) external; // removes address that could control Custodian contract
    function addAddress(address src) external; // adds address that could control Custodian contract
}
/**
 * @title Cdc
 * @dev Cdc Exchange contract.
 */
contract AssetManagementEvents {
    //TODO: set what indexed after testing
    event LogAllowDeposit(address assetMgr, address custodian, address token, uint256 amt);
    event LogAssetManager(address assetManager,bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogAssetManagerRemove(address assetManager, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogAssetManagerVisMajor(address assetMgr, address custodian, uint8 flag_, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogAudit(address auditorOrAssetMgr, address custodian, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogAuditorVisMajor(address auditor, address custodian, uint8 flag_, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogConfigChange(address sender, bytes32 what, bytes32 value, bytes32 value1);
    event LogCustodianBan(address assetMgr, address custodian, bool ban);
    event LogCustodianKeyCompromised(address assetMgr, address custodian, address oldAddress, address newAddress, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogCustodianKeyCompromisedAssetMgr(
        address assetMgr,
        address custodian,
        address oldAddress,
        address newAddress,
        bytes32 descriptionHash,
        bytes32 descriptionUrl);
    event LogCustodianKeyCompromisedRequest(address custodian, address compromised, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogCustodianKeyCompromisedRequestAssetMgr(address assetMgr, address compromised, bytes32 descriptionHash, bytes32 descriptionUrl);
    event LogDeposited(address custodian, address token, uint256 amt);
    event LogFlag(address sender, address auditCustodian, uint8 newFlag);
    event LogInfo(bytes32 issueHash, bytes32 issueUrl);
    event LogMoveCustodianAssetManager(address sender, address newCustodian, bytes32 reasonHash, bytes32 reasonUrl);
    event LogMoveDiamondRequest(address srcCustodian, address dstCustodian, address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl);
    event LogMoveDiamond(address sender, address srcCustodian, address dstCustodian, address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl);
    event LogMoveCustodian(address oldCustodian, address newCustodian, bytes32 reasonHash, bytes32 reasonUrl);
    event LogMoveCustodianAccept(address oldCustodian, address newCustodian, bytes32 reasonHash, bytes32 reasonUrl);
    event LogPriceMultiplierBase(address assetMgr, uint256 priceMultiplierRa);
    event LogPriceMultiplierMarketplace(address assetMgk, uint256 priceMultiplierMp);
    event LogRedeem(address token, address sender, uint256 tokenId);
    event LogRedeemState(address token, uint256 tokenId, bytes32 state);
    event LogRemoveCustodian(address custodianOrAuditor, address custodian, bool accept, bytes32 reasonHash, bytes32 reasonUrl);
    event LogRemoveCustodianRequest(address assetMgr, address custodian, bytes32 reasonHash, bytes32 reasonUrl);
    event LogSystemFlag(uint8 newFlag);
    event LogTransferEth(address src, address dst, uint256 val);
    event LogVisMajorRequest(address custodian, bool request, bytes32 descriptionHash, bytes32 descriptionUrl);
}

// TODO: wallet functionality, proxy Contracts
contract AssetManagement is DSAuth, DSStop, DSMath, AssetManagementEvents {
    mapping(address => bool) assetManagers;                 // returns true for asset managers
    mapping(address => bool) custodianCandidates;           // returns true for asset managers
    mapping(address => bool) custodians;                    // returns true for custodians
    mapping(address => bool) oracles;                       // returns true for oracles
    mapping(address => bool) auditors;                       // returns true for auditors
    mapping(address => bool) dpasses;                       // returns true for dpass tokens allowed in this contract
    mapping(address => bool) cdcs;                          // returns true for cdc tokens allowed in this contract
    mapping(address => bool) payTokens;                     // returns true for tokens allowed to make payment to custodians with
    mapping(bytes32 => bool) issuers;                       // returns true for valid issuers for dpass
    mapping(bytes32 => bool) states;                        // returns true for valid dpass states
    mapping(bytes32 => bool) redeemStates;                  // returns true for valid redeem states
    mapping(
        bool => mapping(
            uint24 => mapping(
                bytes1 => mapping(
                    bytes4 => uint)))) basePrice;               // price based on cut, clarity, color
    mapping(
        address => mapping(
            bool => mapping(
                uint24 => mapping(
                    bytes1 => mapping(
                        bytes4 => uint))))) priceCust;          // price based on cut, clarity, color
    mapping(
        bool => mapping(
            uint24 => mapping(
                bytes1 => mapping(
                    bytes4 => uint)))) totalWeight;         // total weight of all diamonds in our storage belonging to this cut,clarity,color
    mapping(
        address => mapping(
            bool => mapping(
                uint24 => mapping(
                    bytes1 => mapping(
                        bytes4 => uint))))) weightCust;     // total weight of all diamonds in our storage belonging to this customer, cut,clarity,color
    mapping(bytes32 => bool) shapes;                        // returns true for valid shapes
    mapping(bytes1 => bool) colors;                        // returns true for valid colors
    mapping(bytes4 => bool) clarities;                     // returns true for valid clarities
    mapping(uint24 => uint24) weightEnds;                    // returns the end of weight range with 2 decimals precision when calculating price
    mapping(address => bool) removed;                      // returns true if custodian exited the system.
    mapping(
        address => mapping(
            address => mapping(
                uint => Redeem)))  redeem;                  // redeem[custodian][token][tokenID] stores the redeem parameters when user wants to redeem diamonds
    mapping(
        address => mapping(
            uint => Redeem)) redeemRequest;                 // redeemRequest[token][tokenId] is the redeem parameters for token and tokenId
    mapping(
        address => mapping(
            address => uint)) redeemRequestLastId;          // redeemRequestLastId[custodian][token] the last id of redeem request

    mapping(address => uint) public decimals;               // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores decimals for each ERC20 token
    mapping(address => uint8) public flag;                  // flag[custodian] stores flags for custodians green is everything ok...
                                                            // ... , yellow non-critical problem, red critical problem
    mapping(address => bool) visMajorReqest;                // visMajor request created by custodian, when something ...
                                                            // ... that puts collaterals at his place in critical danger
    mapping(address => bool) keyCompromisedRequest;         // if custodian key gets compromised this is set to true


    mapping(address => bool) custodianToRemove;             // when asset manager initiates removal of custodian then this value is true
    mapping(address => bool) keyCompromisedRequestAssetMgr; // if asset manager has notified key compromised request
    mapping(address => address) next;                       // stores a round robin ring of custodians that helps to ...
                                                            // ... check if they went into red flag.
    mapping(address => address) public priceFeed;           // price feed address for token
    mapping(address => uint) public cdcValues;              // base currency value of cdc token

    mapping(address => uint)                                // total base currency value of custodians collaterals
        public totalCollateralCustV;

    mapping(address => uint) public totalDpassSoldV;        // the total value of dpass tokens sold by custodian

    mapping(address => mapping(address => uint))            // dpassSoldV[custodian][token] the value of dpass token sold by custodian
        public dpassSoldV;

    mapping(address => uint) public totalPaidV;             // total amount that has been paid to custodian for dpasses and cdc in base currency
    mapping(address => uint) public tokenPurchaseRate;      // the average purchase rate of a token. This is the ...
                                                            // ... price of token at which we send it to custodian
    mapping(
        address => mapping(
            address => mapping(
                uint => bool))) public allowDeposit;        // allowDeposit[custodian][token][amt] asset manager can allow certain custodians to pay ...
                                                            // ...deposits to decrease their totalPaidV value

    mapping(address => uint) private rate;                  // current rate of a token in base currency
    mapping(address => bool) public manualRate;             // if manual rate is enabled then owner can update rates if feed not available
    mapping(
        address => mapping(
            address => uint)) public moveDiamondLastId;     // moveDiamondLastId[custodian][token] the last id of diamond that was moved from a custodian. 

    mapping(
        address => mapping(
            uint => MoveDiamond)) public moveDiamd;         // moveDiamd[token][tokenId] id of diamond that was moved from a custodian. 
    mapping(address => bool) public visMajorRequest;        // if custodian notifies system of a vis major event
    mapping(address => bool) public banReport;              // if custodian is not allowed to do reporting with ...
                                                            // ... reportInfo() fn then true is stored here
    mapping(address => address) public srcCustodianMove;    // when custodian initiates moving all his diamonds
    mapping(address => address) public asMgrCustodianMove;  // when asset manager initiates moving all custodian's diamonds
    mapping(address => address) public move;                // move[custodian] = dstCustodian means that all belongings ...
                                                            // ... of custodian is moved to dstCustodian
    mapping(address => uint) public audit;                  // audit[custodian] = timestamp means that audit of custodian was done at timestamp seconds
    mapping(address => address) public lastAuditor;         // lastAuditor[custodian] = auditor means that last audit was ...
                                                            // ... done by auditor

    struct Redeem {
        address owner;
        uint next;
        uint prev;
        uint maxFee;
        address payToken;
        bytes32 state;
        uint blockNum;
    }

    struct MoveDiamond {
        address moveBy;
        address  moveTo;
        uint prev;
        uint next;
    }

    uint24 public weightRangeStart;                     // the smallest weight value we have price data for
    uint public minimumValid = 7 * 24 * 60 * 60;        // minimum this many seconds the redeem fee offer must be valid, default is one week
    uint8 public systemFlag;                                   // if system is overcollaterized than systemFlag is green, if ...
                                                        // ... total cdc value is more than free collateral than red, ...
                                                        // ... if cdc value is more than collateral * overCollRatio then yellow

    uint8 public green = 0;                             // used with 'flag' denotes everything okay
    uint8 public yellow = 1;                            // used with 'flag' denotes non-critical problem with custodian
    uint8 public red = 2;                               // used with 'flag' denotes critical problem with custodian ...
                                                        // ... collaterals are subtracted from system, transfers disabled

    bool public locked;                                 // used to make sure that functions are non reentrant
    address public auditCustodian;                      // last checked custodian for audit
    uint public priceMultiplierMp = 1 ether;            // the marketplace price is multiplied with this value to get final price
    uint public priceMultiplierRa = 1 ether;            // the default marketplace price is base price times priceMultiplierRa
    uint public insaneChangeRateMin = 0.5 ether;        // the minimum rate of change in marketprice multiplier
    uint public insaneChangeRateMax = 1.5 ether;        // the maximum rate of change in marketprice multiplier
    address public currCdc;                             // the current cdc token to update the price for
    uint public overCollRatio = 1.1 ether;              // the totalCollateralV >= overCollRatio * totalCdcV
    uint public totalCdcV;                              // total value of all cdc tokens
    uint public allowedCdcMintValueCalc;                // calculated approximate value of total cdc tokens that can be minted
    uint public totalCollateralV;                       // total value of collaterals in base currency
    bool public assetMgrCanSetCollateralValue;          // config parameter if true asset manager can call the ...
                                                        // ... updateCustodianValue(custodian, value) ...
                                                        // ... function, meaning he can update manually what ...
                                                        // ... proportion each custodian gets from selling a CDC token

    uint public dust = 1000;                            // dust value is the largest value we still consider 0 ...
                                                        // ... because of round-off errors, only to be used with 18 digit precision numbers
    uint yellowFlagInterval = 3 * 30 * 24 * 60 * 60;    // 3 months max must be between audits, if more, custodian gets yellow flag.
    uint redFlagInterval = 6 * 30 * 24 * 60 * 60;       // if even after 6 months there was no audit, custodian gets red flag, his diamonds can not be transfered, and his collateral is discounted from system.
    address eth = address(0xee);                        // address of imaginary eth token we use to handle ...
                                                        // ... eth the same way as erc20 tokens
//declarations----------------------------------------------------------------

    constructor() public {
        issuers["GIA"] = true;
        states["inCustody"] = true;
        shapes["BR"] = true;
        shapes["PS"] = true;
        colors["D"] = true;
        colors["E"] = true;
        colors["F"] = true;
        colors["G"] = true;
        colors["H"] = true;
        colors["I"] = true;
        colors["J"] = true;
        colors["K"] = true;
        colors["L"] = true;
        colors["M"] = true;
        colors["N"] = true;
        clarities["I1"] = true;
        clarities["I2"] = true;
        clarities["I3"] = true;
        clarities["IF"] = true;
        clarities["SI1"] = true;
        clarities["SI2"] = true;
        clarities["SI3"] = true;
        clarities["VS1"] = true;
        clarities["VS2"] = true;
        clarities["VVS1"] = true;
        clarities["VVS2"] = true;
        weightEnds[1] = 3;
        weightEnds[3] = 7;
        weightEnds[7] = 14;
        weightEnds[14] = 17;
        weightEnds[17] = 22;
        weightEnds[22] = 29;
        weightEnds[29] = 39;
        weightEnds[39] = 49;
        weightEnds[49] = 69;
        weightEnds[69] = 89;
        weightEnds[89] = 99;
        weightEnds[99] = 149;
        weightEnds[149] = 199;
        weightEnds[199] = 299;
        weightEnds[299] = 399;
        weightEnds[399] = 499;
        weightEnds[499] = 599;
        weightEnds[599] = 1099;
    }

    modifier maint {
        _maintenance();
        _;
    }

    modifier nonReentrant {
        require(!locked, "asm-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    modifier assetMgr {
        require(assetManagers[msg.sender], "asm-asset-managers-only");
        _;
    }

    modifier custodn {
        require(custodians[msg.sender], "asm-custodians-only");
        _;
    }

    modifier auditor {
        require(auditors[msg.sender], "asm-auditors-only");
        _;
    }

    modifier oracle {
        require(oracles[msg.sender], "asm-oracles-only");
        _;
    }

    modifier assetMgrOrCustdn {
        require(
            assetManagers[msg.sender] ||
            custodians[msg.sender],
            "asm-asset-mgr-or-custodian-only");
        _;
    }

    function isAssetManager(address assetManager) public view returns(bool) {
        return assetManagers[assetManager];
    }

    function isCustodianCandidate(address candidate) public view returns(bool) {
        return custodianCandidates[candidate];
    }

    function isCustodian(address custodian) public view returns(bool) {
        return custodians[custodian];
    }

    function isOracle(address oracle_) public view returns(bool) {
        return oracles[oracle_];
    }

    function isDpass(address dpass) public view returns(bool) {
        return dpasses[dpass];
    }

    function isCdc(address cdc) public view returns(bool) {
        return cdcs[cdc];
    }

    function isPayToken(address payToken) public view returns(bool) {
        return payTokens[payToken];
    }

    function isIssuer(bytes32 issuer) public view returns(bool) {
        return issuers[issuer];
    }

    function isState(bytes32 state) public view returns(bool) {
        return states[state];
    }

    function isRedeemState(bytes32 state) public view returns(bool) {
        return redeemStates[state];
    }

    function getBasePrice(bool roundOrPear, uint24 caratRange, bytes1 color, bytes4 clarity) public view returns(uint) {
        return basePrice[roundOrPear][caratRange][color][clarity];
    }

    function getPriceCust(address custodian, bool roundOrPear, uint24 caratRange, bytes1 color, bytes4 clarity) public view returns(uint) {
        require(custodians[custodian], "asm-not-a-custodian");
        return priceCust[custodian][roundOrPear][caratRange][color][clarity];
    }

    function getPrice(TrustedErc721 erc721, uint256 id721, bool sell) public view returns (uint256 price) {
        require(dpasses[address(erc721)], "asm-not-a-dpass-token");

        (,,
         uint ownerPrice,
         uint marketplacePrice,
         bytes32 state,
         ,
         bytes32[] memory attributeValues,
        ) = Dpass(address(erc721)).getDiamond(id721);

        require(state != "invalid", "asm-token-should-be-valid");

        if(ownerPrice == 0 || sell) {
            if(marketplacePrice == 0) {
                (,,,,,price) = getAttributes(attributeValues);
                price = wmul(price, priceMultiplierRa);
            } else {
                price = wmul(marketplacePrice, priceMultiplierMp);
            }
        } else {
            price = ownerPrice;
        }
    }

    function getTotalWeight(bool roundOrPear, uint24 caratRange, bytes1 color, bytes4 clarity) public view returns(uint) {
        return totalWeight[roundOrPear][caratRange][color][clarity];
    }

    function getWeightCust(address custodian, bool roundOrPear, uint24 caratRange, bytes1 color, bytes4 clarity) public view returns(uint) {
        return weightCust[custodian][roundOrPear][caratRange][color][clarity];
    }

    function isShape(bytes32 shape) public view returns(bool) {
        return shapes[shape];
    }

    function isColor(bytes1 color) public view returns(bool) {
        return colors[color];
    }

    function isClarity(bytes4 clarity) public view returns(bool) {
        return clarities[clarity];
    }

    function isWeightEnd(uint24 weightEnd) public view returns(uint24) {
        return weightEnds[weightEnd];
    }

    function isRemoved(address custodian) public view returns(bool) {
        require(custodians[custodian], "asm-not-a-custodian");
        return removed[custodian];
    }

    function getRedeem(
        address custodian,
        address token,
        uint tokenId)
    public view returns (
        address,
        uint256,
        uint256,
        uint256,
        address,
        bytes32)
    {
        require(custodians[custodian] , "asm-not-a-custodian");
        require(dpasses[token], "asm-token-not-listed");
        uint tokId = tokenId == 0 ? redeemRequestLastId[msg.sender][token] : tokenId;
        require(tokId != 0, "asm-token-id-zero");
        Redeem storage r = redeem[custodian][token][tokId];
        return (r.owner, r.next, r.prev, r.maxFee, r.payToken, r.state);
    }

    function getRedeemRequest(
        address token,
        uint tokenId)
    public view returns (address, uint256, uint256, uint256, address, bytes32)
    {
        require(dpasses[token], "asm-not-a-valid-token");
        require(tokenId != 0, "asm-token-id-zero");
        Redeem storage r = redeemRequest[token][tokenId];
        return (r.owner, r.next, r.prev, r.maxFee, r.payToken, r.state);
    }

    function getRedeemRequestLastId(address custodian, address token) public view returns(uint256) {
        require(dpasses[token], "asm-not-a-valid-token");
        require(custodians[custodian], "asm-not-a-custodian");
        return redeemRequestLastId[custodian][token];
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public view returns (uint8 dec) {
        require(cdcs[token_], "asm-token-not-listed");
        require(decimalsSet[token_], "asm-token-with-unset-decimals");
        while(dec <= 77 && decimals[token_] % uint(10) ** dec == 0){
            dec++;
        }
    }

    function getFlag(address custodian) public view returns(uint8) {
        require(custodians[custodian], "asm-not-a-custodian");
        return flag[custodian];
    }

    function isVisMajorRequest(address custodian) public view returns(bool) {
        require(custodians[custodian], "asm-not-a-custodian");
        return visMajorReqest[custodian];
    }

    function isKeyCompromisedRequest(address custodian) public view returns(bool) {
        require(custodians[custodian], "asm-not-a-custodian");
        return keyCompromisedRequest[custodian];
    }

    function isCustodianToRemove(address custodian) public view returns(bool) {
        require(custodians[custodian], "asm-not-a-custodian");
        return custodianToRemove[custodian];
    }

    function isKeyCompromisedRequestAssetMgr(address custodian) public view returns(bool) {
        require(custodians[custodian], "asm-not-a-custodian");
        return keyCompromisedRequestAssetMgr[custodian];
    }

    function getNext(address custodian) public view returns(address) {
        require(custodians[custodian], "asm-not-a-custodian");
        return next[custodian];
    }

    function getPriceFeed(address token) public view returns(address) {
        require(dpasses[token], "asm-token-not-listed");
        return priceFeed[token];
    }

    function getCdcValues(address cdc) public view returns(uint256) {
        require(cdcs[cdc], "asm-token-not-listed");
        return cdcValues[cdc];
    }

    function getTotalCollateralCustV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalCollateralCustV[custodian];
    }

    function getDpassSoldV(address custodian, address token) public view returns(uint256) {
        require(dpasses[token], "asm-token-not-listed");
        require(custodians[custodian], "asm-not-a-custodian");
        return dpassSoldV[custodian][token];
    }

    function getTotalPaidV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalPaidV[custodian];
    }

    function getTokenPurchaseRate(address token) public view returns(uint256) {
        require(payTokens[token], "asm-token-not-listed");
        return tokenPurchaseRate[token];
    }

    function getAllowDeposit(address custodian, address token, uint256 amt) public view returns(bool) {
        require(payTokens[token], "asm-token-not-listed");
        require(custodians[custodian], "asm-not-a-custodian");
        return allowDeposit[custodian][token][amt];
    }

    function getRate(address token) public view auth returns (uint) {
        return _getNewRate(token);
    }

    function isManualRate(address token) public view returns(bool) {
        require(payTokens[token] || cdcs[token], "asm-token-not-listed");
        return manualRate[token];
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    function getMoveDiamondLastID(address custodian, address token) public view returns(uint256) {
        require(dpasses[token], "asm-token-not-listed");
        require(custodians[custodian], "asm-not-a-custodian");
        return moveDiamondLastId[custodian][token];
    }


    function getMoveDiamd(address custodian, address token, uint256 tokenId) public view returns(address, address, uint256, uint256){
        require(custodians[custodian], "asm-not-a-custodian");
        uint tokId = tokenId == 0 ? moveDiamondLastId[custodian][token] : tokenId;
        require(tokId != 0, "asm-token-id-can-not-be-0");
        MoveDiamond storage m = moveDiamd[token][tokenId];
        return (m.moveBy, m.moveTo, m.prev, m.next);
    }

    function getSrcCustodianMove(address custodian) public view returns(address) {
        require(custodian != address(0), "asm-address-zero");
        return srcCustodianMove[custodian];
    }

    function getAsMgrCustodianMove(address custodian) public view returns(address) {
        require(custodian != address(0), "asm-address-zero");
        return asMgrCustodianMove[custodian];
    }

    function getMove(address custodian) public view returns(address) {
        require(custodians[custodian], "asm-not-a-custodian");
        return move[custodian];
    }

    function getAudit(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return audit[custodian];
    }

    function getLastAuditor(address custodian) public view returns(address) {
        require(custodians[custodian], "asm-not-a-custodian");
        return lastAuditor[custodian];
    }

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public maint nonReentrant auth {
        if (what_ == "dpasses") {
            require(addr(value_) != address(0), "asm-dpass-address-zero");
            dpasses[addr(value_)] = uint(value1_) > 0;
        } else if (what_ == "cdcs") {
            address newCdc = addr(value_);
            require(newCdc != address(0), "asm-cdc-address-zero");
            require(newCdc != currCdc, "asm-cdc-address-no-zero");
            cdcs[newCdc] = uint(value1_) > 0;
            if(currCdc == address(0)) {
                currCdc = newCdc;
                next[currCdc] = currCdc;
            } else {
                next[newCdc] = next[currCdc];
                next[currCdc] = newCdc;
            }
            _updateCdcValue(newCdc);
        } else if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);

            require(payTokens[token] || cdcs[token], "Token not allowed rate");

            require(value > 0, "Rate must be greater than 0");

            rate[token] = value;

        } else if (what_ == "registerOracle") {
            address oracle_ = addr(value_);
            require(oracle_ != address(0), "asm-oracle-no-zero-address");
            oracles[oracle_] = true;
        } else if (what_ == "removeOracle") {
            address oracle_ = addr(value_);
            require(oracles[oracle_], "asm-not-an-oracle");
            oracles[oracle_] = false;
        } else if (what_ == "registerAuditor") {
            address auditor_ = addr(value_);
            require(auditor_ != address(0), "asm-auditor-no-zero-address");
            auditors[auditor_] = true;
        } else if (what_ == "removeAuditor") {
            address auditor_ = addr(value_);
            require(auditors[auditor_], "asm-not-an-auditor");
            auditors[auditor_] = false;
        }  else if (what_ == "payTokens") {
            require(addr(value_) != address(0), "asm-pay-token-address-no-zero");
            payTokens[addr(value_)] = uint(value1_) > 0;
        } else if (what_ == "issuers") {
            require(value_ != "", "asm-issuer-should-not-be-empty");
            issuers[value_] = uint(value1_) > 0;
        } else if (what_ == "states") {
            require(value_ != "", "asm-state-should-not-be-empty");
            states[value_] = uint(value1_) > 0;
        } else if (what_ == "redeemStates") {
            require(value_ != "", "asm-state-should-not-be-empty");
            redeemStates[value_] = uint(value1_) > 0;
        } else if (what_ == "dust") {

            dust = uint256(value_);

        } else if (what_ == "priceFeed") {

            require(cdcs[addr(value_)] || payTokens[addr(value_)], "asm-token-not-allowed-pricefeed");

            require(addr(value1_) != address(address(0x0)), "asm-wrong-pricefeed-address");

            priceFeed[addr(value_)] = addr(value1_);

        } else if (what_ == "manualRate") {

            address token = addr(value_);

            require(payTokens[token] || cdcs[token], "Token not allowed manualRate");

            manualRate[token] = uint256(value1_) > 0;

        } else if (what_ == "shapes") {
            require(value_ != "", "asm-shape-should-not-be-empty");
            shapes[value_] = uint(value1_) > 0;
        } else if (what_ == "colors") {
            require(value_ != "", "asm-color-should-not-be-empty");
            colors[bytes1(value_)] = uint(value1_) > 0;
        } else if (what_ == "clarities") {
            require(value_ != "", "asm-clarities-should-not-be-empty");
            clarities[bytes4(value_)] = uint(value1_) > 0;
        } else if (what_ == "weightRangeStart") {
            require(value_ != "", "asm-weightRangeStart-noempty");
            weightRangeStart = uint24(uint256(value_));
        } else if (what_ == "weightEnds") {
            require(uint(value_) <= uint24(-1), "asm-weightend-out-of-range");
            require(uint(value1_) <= uint24(-1), "asm-weightend-out-of-range");
            weightEnds[uint24(uint256(value_))] = uint24(uint256(value1_));
        } else if (what_ == "yelloFlagInterval") {
            yellowFlagInterval = uint(value_);
            require(yellowFlagInterval != 0, "asm-yellow-flag-interval-0");
        } else if (what_ == "overCollRatio") {
            overCollRatio = uint(value_);
            require(overCollRatio >= 1 ether, "asm-system-must-be-overcollaterized");
            require(totalCollateralV >= wmul(overCollRatio, totalCdcV), "asm-can-not-introduce-new-ratio");
        }  else if (what_ == "redFlagInterval") {
            redFlagInterval = uint(value_);
            require(redFlagInterval != 0, "asm-red-flag-interval-0");
        } else if (what_ == "minimumValid") {
            minimumValid = uint(value_);
        } else if (what_ == "insaneChangeRateMax") {
            insaneChangeRateMax = uint(value_);
            require(insaneChangeRateMax > 1 ether, "asm-too-small-max-rate");
            require(insaneChangeRateMax <= 2 ether, "asm-too-large-max-rate");
        } else if (what_ == "assetMgrCanSetCollateralValue") {
            assetMgrCanSetCollateralValue = uint(value_) > 0;
        } else if (what_ == "insaneChangeRateMin") {
            insaneChangeRateMin = uint(value_);
            require(insaneChangeRateMin > 0.5 ether, "asm-too-small-max-rate");
            require(insaneChangeRateMin <= 1 ether, "asm-too-large-max-rate");
        } else if (what_ == "decimals") {
            require(addr(value_) != address(0x0), "asm-wrong-address");

            uint decimal = uint256(value1_);

            if(decimal >= 18) {

                decimals[addr(value_)] = mul(10 ** 18, 10 ** (uint256(value1_) - 18));

            } else {

                decimals[addr(value_)] = 10 ** 18 / 10 ** (18 - uint256(value1_));

            }

            decimalsSet[addr(value_)] = true;
        }
        emit LogConfigChange(msg.sender, what_, value_, value1_);
    }

    function assetManagerRegisterCustodian(
        address custodian,
        bool enable,
        bytes32 introHash,
        bytes32 introUrl)
    public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "asm-address-zero");
        custodianCandidates[custodian] = enable;
        emit LogConfigChange(custodian, bytes32(uint(enable?1:0)), introHash, introUrl);
    }

    function custodianAcceptRegistration(
        bool accept,
        bytes32 introHash,
        bytes32 introUrl)
    public maint nonReentrant auth {
        require(custodianCandidates[msg.sender], "asm-you-should-be-enabled-custodian");
        custodians[msg.sender] = accept;
        if(!accept) {
            custodianCandidates[msg.sender] = false;
        } else {
            if(auditCustodian == address(0)) {
                auditCustodian = msg.sender;
                next[auditCustodian] = auditCustodian;
            } else {
                next[msg.sender] = next[auditCustodian];
                next[auditCustodian] = msg.sender;
            }
        }
        emit LogConfigChange(msg.sender, bytes32(uint(accept?1:0)), introHash, introUrl);
    }

    function custodianRegisterDiamond(
        address token,
        // removed "address to," as custodians can only create diamonds for themselves
        bytes32 issuer,
        bytes32 report,
        uint256 ownerPrice,
        bytes32[] memory attributes,
        bytes32 attributesHash,
        bytes8 hashingAlgorithm)
    public maint nonReentrant auth custodn {
        uint tokenId;
        require(dpasses[token], "asm-token-not-allowed");
        require(issuers[issuer], "asm-issuer-not-allowed");
        tokenId = Dpass(token).mintDiamondTo(msg.sender, msg.sender, issuer, report, ownerPrice, 0, "created", attributes, attributesHash, hashingAlgorithm);
        (uint24 weightRange, bool shape, uint24 weight, bytes1 color, bytes4 clarity, uint256 price) = getAttributes(attributes);
        totalCollateralV = add(totalCollateralV, price);

        totalWeight[shape][weightRange][color][clarity] = add(
            totalWeight[shape][weightRange][color][clarity],
            weight);
    }

    function getAttributes(bytes32[] memory attributes)
    internal view returns(
        uint24 weightRange,
        bool shape,
        uint24 weight,
        bytes1 color,
        bytes4 clarity,
        uint256 price)
    {
        weightRange = weightRangeStart;
        shape = uint(attributes[0]) > 0;
        weight = uint24(uint256(attributes[1]));
        color = bytes1(attributes[2]);
        clarity = bytes4(attributes[3]);

        // require(shapes[shape?bytes32("BR"):bytes32("PS")], "asm-invalid-shape");
        require(colors[color], "asm-invalid-color");
        require(clarities[clarity], "asm-invalid-clarity");
        require(weight > 0, "asm-weight-can't-be-0");
        while(weight > weightRange && weightEnds[weightRange] > 0)
            weightRange = weightEnds[weightRange];
        require(weight <= weightRange, "asm-weight-is-too-large");
        price = mul(basePrice[shape][weightRange][color][clarity], weight) / 100;
    }


    function custodianMoveDiamond(
        address dstCustodian,
        address token,
        uint256 tokenId,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth custodn {
        moveDiamond(msg.sender, dstCustodian, token, tokenId, reasonHash, reasonUrl);
    }

    function moveDiamond(
        address srcCustodian,
        address dstCustodian,
        address token,
        uint256 tokenId,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    internal {
        bytes32 state;
        uint soldV;
        require(dpasses[token], "asm-token-not-allowed");
        require(custodians[srcCustodian], "asm-not-a-custodian");
        require(custodians[dstCustodian], "asm-not-a-custodian");
        require(Dpass(token).getCustodian(tokenId) == srcCustodian, "asm-not-custodian-of-token");
        state = Dpass(token).getState(tokenId);
        require(state != "invalid", "asm-token-invalid");
        require(state != "removed", "asm-token-removed");
        require(custodians[dstCustodian], "asm-new-custodian-not-allowed");
        moveDiamd[token][tokenId] = MoveDiamond({
            moveBy: msg.sender,
            moveTo: dstCustodian,
            prev: moveDiamondLastId[dstCustodian][token],
            next: 0});
        if(moveDiamondLastId[srcCustodian][token] > 0) moveDiamd[token][moveDiamondLastId[srcCustodian][token]].next = tokenId;
        moveDiamondLastId[srcCustodian][token] = tokenId;
        emit LogMoveDiamondRequest(srcCustodian, dstCustodian, token, tokenId, reasonHash, reasonUrl);
        soldV = dpassSoldV[dstCustodian][token];
        _updateCollateral(soldV, 0, dstCustodian);
        _updateCollateral(0, soldV, srcCustodian);
        delete dpassSoldV[srcCustodian][token];     // TODO: really delete this??? not only update????
        dpassSoldV[dstCustodian][token] = soldV;
        require(                                                        // custodian's total collateral value must be ...
                                                                        // more or equal than proportional cdc value and dpasses sold
            add(
                wmul(
                    totalCdcV,
                    wdiv(
                        allowedCdcMintValueCalc,
                        totalCollateralCustV[srcCustodian])),
                totalDpassSoldV[srcCustodian]
            ) <=
            add(totalCollateralCustV[srcCustodian], dust)
            , "asm-undercollaterized");
    }

    function assetManagerMoveDiamond(
        address srcCustodian,
        address dstCustodian,
        address token,
        uint256 tokenId,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth assetMgr {
        require(custodians[srcCustodian], "asm-src-not-a-custodian");
        require(custodians[dstCustodian], "asm-dst-not-a-custodian");
        require(flag[srcCustodian] == red, "asm-only-if-custodian-red-flagged");
        moveDiamond(msg.sender, dstCustodian, token, tokenId, reasonHash, reasonUrl);
    }

    function custodianAcceptMoveDiamond(
        address token,
        uint256 tokenId,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth custodn {
        MoveDiamond storage m = moveDiamd[token][tokenId];
        require(m.moveTo != msg.sender, "asm-nothing-to-accept");
        require(dpasses[token], "asm-token-not-allowed");
        require(Dpass(token).getState(tokenId) != "invalid", "asm-token-invalid");
        emit LogMoveDiamond(msg.sender, Dpass(token).ownerOf(tokenId), msg.sender, token, tokenId, reasonHash, reasonUrl);
        Dpass(token).setCustodian(tokenId, msg.sender);
        if(m.prev != 0) moveDiamd[token][m.prev].next = m.next;
        if(m.next != 0) moveDiamd[token][m.next].prev = m.prev;
        delete moveDiamd[token][tokenId];
    }

    function custodianRemoveDiamond(address token, uint256 tokenId) public maint nonReentrant auth custodn {
        uint price;
        require(dpasses[token], "asm-token-not-allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "asm-not-custodian-of-token");
        require(Dpass(token).getState(tokenId) != "invalid", "asm-token-invalid");
        require(Dpass(token).ownerOf(tokenId) == msg.sender, "asm-you-are-not-owner");
        Dpass(token).changeStateTo("removed", tokenId);

        price = _getTokenPrice(token, tokenId);

        _updateCollateral(0, price, msg.sender);

        require(                                                        // custodian's total collateral value must be ...
                                                                        // more or equal than proportional cdc value and dpasses sold
            add(
                wmul(
                    totalCdcV,
                    wdiv(
                        allowedCdcMintValueCalc,
                        totalCollateralCustV[msg.sender])),
                totalDpassSoldV[msg.sender]
            ) <=
            add(totalCollateralCustV[msg.sender], dust)
            , "asm-undercollaterized");

        // TODO: make sure we can readd removed diamond, how does invalid state work? Must make sure we can handle invalid if eg.: bad attributes were added, make sure we can recreate token with same issuer and reportId.
        // TODO: what to do if diamond is removed because of theft, accident, and diamond is already sold?
    }

    function userRedeem(
        address token,
        uint256 tokenId,
        uint maxFeeV,
        address payToken,
        bytes32 state)
    public {
        uint allowedToUs = min(
            DSToken(payToken).balanceOf(msg.sender),
            DSToken(payToken).allowance(msg.sender, address(this)));

        address custodian = Dpass(token).getCustodian(tokenId);
        Redeem storage usrRedeem = redeemRequest[token][tokenId];

        require(Dpass(token).ownerOf(tokenId) == msg.sender, "asm-you-are-not-owner");
        require(dpasses[token], "asm-token-not-allowed");
        require(payTokens[payToken], "asm-paytoken-not-allowed");
        require(Dpass(token).getApproved(tokenId) == address(this), "asm-we-are-not-approved");
        require(wdivT(maxFeeV, updateRate(token), token) > allowedToUs, "asm-paytoken-not-enough");
        if(usrRedeem.payToken == address(0)) {                              // if we create new redeem
            redeemRequest[token][tokenId] = Redeem({
                owner: msg.sender,
                next: 0,
                prev: redeemRequestLastId[custodian][token],
                maxFee: maxFeeV,
                payToken: payToken,
                state: "",
                blockNum: block.number
                });
        } else {                                            // if we update existing redeem
            usrRedeem.owner = msg.sender;
            usrRedeem.maxFee = maxFeeV;
            usrRedeem.payToken = payToken;
            usrRedeem.state = state;
            usrRedeem.blockNum = block.number;
        }

        redeem[custodian][token][tokenId] = redeemRequest[token][tokenId];
        if(redeemRequestLastId[custodian][token] > 0) redeemRequest[token][redeemRequestLastId[custodian][token]].next = tokenId;
        redeemRequestLastId[custodian][token] = tokenId;
        emit LogRedeem(token, msg.sender, tokenId);
    }

    function userDeleteRedeem(address token, uint256 tokenId) public maint nonReentrant {
        deleteRedeem(token, tokenId, true);
    }

    function deleteRedeem(address token, uint256 tokenId, bool userOrCustodian) internal {
        address custodian = Dpass(token).getCustodian(tokenId);
        Redeem storage delRedeem = redeemRequest[token][tokenId];
        require(delRedeem.payToken != address(0), "asm-delRedeem-never-existed");
        require(!userOrCustodian || delRedeem.owner == msg.sender, "asm-you-are-not-owner-of-token");
        require(userOrCustodian || custodian == msg.sender, "asm-you-are-not-custodian-of-token");
        if(delRedeem.prev != 0) redeemRequest[token][delRedeem.prev].next = delRedeem.next;
        if(delRedeem.next != 0) redeemRequest[token][delRedeem.next].prev = delRedeem.prev;
        delete redeemRequest[token][tokenId];
    }


    function custodianRedeemCharge(address token, uint256 tokenId, uint256 priceV) public maint nonReentrant auth custodn {
        address tokenOwner = Dpass(token).ownerOf(tokenId);
        Redeem storage chargeRedeem = redeemRequest[token][tokenId];
        uint priceT;
        require(chargeRedeem.owner == tokenOwner, "asm-owner-changed-since-chargeRedeem");
        require(dpasses[token], "asm-token-not-allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "asm-not-custodian-of-token");
        priceT = wdivT(priceV, updateRate(chargeRedeem.payToken), chargeRedeem.payToken);
        DSToken(chargeRedeem.payToken).transferFrom(chargeRedeem.owner, Dpass(token).getCustodian(tokenId), priceT);
        Dpass(token).redeem(tokenId);
        deleteRedeem(token, tokenId, false);
    }

    function custodianRedeemSetState(address token, uint256 tokenId, bytes32 state) public maint nonReentrant custodn auth {
        require(dpasses[token], "asm-token-not-allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "asm-not-custodian-of-token");
        require(redeemStates[state], "asm-not-allowed-redeem-state");
        redeem[msg.sender][token][tokenId].state = state;
        emit LogRedeemState(token, tokenId, state);
    }

    function custodianVisMajorNotify(bytes32 descriptionHash, bytes32 descriptionUrl, bool request) public maint nonReentrant auth custodn {
        uint8 newFlag;
        uint8 oldFlag = flag[msg.sender];

        if(request != visMajorRequest[msg.sender])
            emit LogVisMajorRequest(msg.sender, request, descriptionHash, descriptionUrl);

        visMajorRequest[msg.sender] = request;

        if (oldFlag != (newFlag = _setFlag(msg.sender, yellow)))
            emit LogFlag(msg.sender, msg.sender, newFlag);
    }

    function assetManagerVisMajorConsent(
        uint8 flag_,
        address custodian,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "asm-address-zero");
        require(visMajorReqest[custodian], "asm-only-if-custodian-requested");
        _setFlag(custodian, flag_);
        emit LogAssetManagerVisMajor(msg.sender, custodian, flag_, descriptionHash, descriptionUrl);
    }

    function auditorVisMajor(
        address custodian,
        bytes32 descriptionHash,
        bytes32 descriptionUrl,
        uint8 flag_)
    public maint nonReentrant auth auditor {
        require(custodian != address(0), "asm-address-zero");
        delete visMajorRequest[custodian];
        _setFlag(custodian, flag_);
        emit LogAuditorVisMajor(msg.sender, custodian, flag_, descriptionHash, descriptionUrl);
    }

    function custodianKeyCompromised(
        address compromised,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth custodn {
        require(compromised != address(0), "asm-address-zero");
        keyCompromisedRequest[msg.sender] = true;
        emit LogCustodianKeyCompromisedRequest(msg.sender, compromised, descriptionHash, descriptionUrl);
    }

    function assetManagerKeyCompromisedAccept(
        address custodian,
        address oldAddress,
        address newAddress,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth assetMgr {
        require(oldAddress != address(0), "asm-zero-old-address-not-allowed");
        require(newAddress != address(0), "asm-zero-new-address-not-allowed");
        require(keyCompromisedRequest[custodian], "asm-there-was-no-request");
        TrustedCustodianLike(custodian).removeAddress(oldAddress);
        TrustedCustodianLike(custodian).addAddress(newAddress);
        delete keyCompromisedRequest[custodian];
        emit LogCustodianKeyCompromised(msg.sender, custodian, oldAddress, newAddress, descriptionHash, descriptionUrl);
    }

    function assetManagerKeyCompromised(
        address custodian,
        address compromised,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "asm-address-zero");
        require(custodians[custodian], "asm-not-custodian");
        require(compromised != address(0), "asm-address-zero");
        keyCompromisedRequestAssetMgr[custodian] = true;
        emit LogCustodianKeyCompromisedRequestAssetMgr(msg.sender, compromised, descriptionHash, descriptionUrl);
    }

    function auditorKeyCompromisedAccept(
        address custodian,
        address oldAddress,
        address newAddress,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth auditor {
        require(custodian != address(0), "asm-custodian-address-zero");
        require(custodians[custodian], "asm-not-a-custodian");
        require(oldAddress != address(0), "asm-old-address-zero");
        require(newAddress != address(0), "asm-new-address-zero");
        require(keyCompromisedRequestAssetMgr[custodian], "asm-there-was-no-request");
        TrustedCustodianLike(custodian).removeAddress(oldAddress);
        TrustedCustodianLike(custodian).addAddress(newAddress);
        delete keyCompromisedRequest[custodian];
        emit LogCustodianKeyCompromisedAssetMgr(msg.sender, custodian, oldAddress, newAddress, descriptionHash, descriptionUrl);
    }

    function assetManagerRemoveCustodian(address custodian, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "asm-address-zero");
        require(custodians[custodian], "asm-not-a-custodian");
        custodianToRemove[custodian] = true;
        emit LogRemoveCustodianRequest(msg.sender, custodian, reasonHash, reasonUrl);
    }

    function custodianRemoveCustodianAccept(bool accept, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodn {
        _removeCustodian(msg.sender, accept, reasonHash, reasonUrl);
    }

    function _removeCustodian(address custodian, bool accept, bytes32 reasonHash, bytes32 reasonUrl) internal {
        require(custodian != address(0), "asm-custodian-address-zero");
        require(custodianToRemove[custodian], "asm-remove-was-not-requested");
        require(custodians[custodian], "asm-not-a-custodian");
        removed[custodian] = accept;
        if(accept) {
            custodianToRemove[custodian] = false;
            flag[custodian] = red;
            _updateCollateral(0, totalCollateralCustV[custodian], custodian);
            require(
                add(
                    add(
                        wmul(
                            totalCdcV,
                            wdiv(
                                allowedCdcMintValueCalc,
                                totalCollateralCustV[custodian])),
                        totalDpassSoldV[custodian]),
                    dust) >=
                    totalPaidV[custodian]
                , "asm-too-much-withdrawn");

            require(                                                        // custodian's total collateral value must be ...
                                                                            // more or equal than proportional cdc value and dpasses sold
                add(
                    wmul(
                        totalCdcV,
                        wdiv(
                            allowedCdcMintValueCalc,
                            totalCollateralCustV[custodian])),
                    totalDpassSoldV[custodian]
                ) <=
                add(totalCollateralCustV[custodian], dust)
                , "asm-not-enough-collateral");

            emit LogFlag(msg.sender, custodian, red);
        }
        emit LogRemoveCustodian(msg.sender, custodian, accept, reasonHash, reasonUrl);
    }

    function auditorRemoveCustodianAccept(
        address custodian,
        bool accept,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth auditor {
        _removeCustodian(custodian, accept, reasonHash, reasonUrl);
    }

    function reportInfo(
        bytes32 issueHash,
        bytes32 issueUrl)
    public maint nonReentrant auth { // custodians, asset managers, auditors can report issue
        if(!banReport[msg.sender])
            emit LogInfo(issueHash, issueUrl);
    }

    function assetManagerBanInfo(address reporter, bool ban) public maint nonReentrant auth assetMgr {
        require(reporter != address(0), "asm-address-zero");
        require(custodians[reporter], "asm-address-zero");
        banReport[reporter] = ban;
        _setFlag(reporter, yellow);
        emit LogCustodianBan(msg.sender, reporter, ban);
    }

    function _setFlag(address custodian, uint8 intendedFlag) internal returns(uint8){
        uint8 oldFlag = flag[custodian];
        uint8 newFlag;
        if( intendedFlag == green) {
            if(banReport[custodian] || visMajorRequest[custodian]) {
                newFlag = yellow;
            } else {
                newFlag = green;
            }
        } else {
            newFlag = intendedFlag;
        }

        if(oldFlag != newFlag)
            emit LogFlag(msg.sender, custodian, newFlag);

        flag[custodian] = newFlag;
        
        return newFlag;
    }

    function custodianMove(address newCustodian, bool enable, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodn {
        require(custodians[newCustodian], "asm-not-a-custodian");
        if(enable) {
            srcCustodianMove[newCustodian] = msg.sender;
        } else {
            delete srcCustodianMove[newCustodian];
        }

        emit LogMoveCustodian(enable ? msg.sender : address(0), newCustodian, reasonHash, reasonUrl);
    }

    function assetManagerMove(
        address srcCustodian,
        address dstCustodian,
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth assetMgr {
        require(removed[srcCustodian] || srcCustodianMove[dstCustodian] == srcCustodian, "asm-not-possible-to-move-yet");
        require(custodians[srcCustodian], "asm-src-not-a-custodian");
        require(custodians[dstCustodian], "asm-dst-not-a-custodian");
        asMgrCustodianMove[dstCustodian] = srcCustodian;
        move[srcCustodian] = msg.sender;
        emit LogMoveCustodianAssetManager(msg.sender, dstCustodian, reasonHash, reasonUrl);
    }

    function custodianMoveAccept(
        bytes32 reasonHash,
        bytes32 reasonUrl)
    public maint nonReentrant auth custodn {
        require(asMgrCustodianMove[msg.sender] != address(0) || srcCustodianMove[msg.sender] != address(0), "asm-move-not-initiated");
        address sourceCustodian = srcCustodianMove[msg.sender];
        require(sourceCustodian != address(0),"asm-move-is-not-possible");
        move[sourceCustodian] = msg.sender;
        emit LogMoveCustodianAccept(sourceCustodian, msg.sender, reasonHash, reasonUrl);
    }

    function auditorAuditCustodian(
        address custodian,
        uint8 newFlag,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth auditor {
        require(custodian != address(0), "asm-zero-custodian-not-allowed");
        require(custodians[custodian], "asm-not-a-custodian");
        audit[custodian] = now;
        lastAuditor[custodian] = msg.sender;
        newFlag = _setFlag(custodian, newFlag);
        emit LogFlag(msg.sender, custodian, newFlag);
        emit LogAudit(msg.sender, custodian, descriptionHash, descriptionUrl);
    }

    function assetManagerAuditCustodian(
        address custodian,
        uint8 newFlag,
        bytes32 descriptionHash,
        bytes32 descriptionUrl)
    public maint nonReentrant auth assetMgr {
        uint8 oldFlag = flag[custodian];
        require(custodians[custodian], "asm-not-a-custodian");
        require(newFlag != red, "asm-red-flag-not-allowed");
        newFlag = _setFlag(custodian, newFlag); 
        if(oldFlag != newFlag)
            emit LogFlag(msg.sender, custodian, newFlag);
        emit LogAudit(msg.sender, custodian, descriptionHash, descriptionUrl);
    }

    function registerAssetManager(address assetManager, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth {
        require(assetManager != address(0), "asm-address-zero");
        require(!assetManagers[assetManager], "asm-already-registered");
        assetManagers[assetManager] = true;
        emit LogAssetManager(assetManager, descriptionHash, descriptionUrl);
    }

    function updateMarketplacePrice(address token, uint256 id, uint256 marketPrice) public maint nonReentrant auth assetMgr {
        require(dpasses[token], "asm-token-not-valid");
        Dpass(token).setMarketplacePrice(id, marketPrice);
    }

    function updateMarketplacePriceMultiplier(uint256 newPriceMultiplier) public maint nonReentrant auth assetMgr {
        require(wdiv(newPriceMultiplier, priceMultiplierMp) < insaneChangeRateMax, "asm-pls-reduce-change");
        require(wdiv(newPriceMultiplier, priceMultiplierMp) > insaneChangeRateMin, "asm-pls-increase-change");
        priceMultiplierMp = newPriceMultiplier;
        emit LogPriceMultiplierMarketplace(msg.sender, priceMultiplierMp);
    }

    function updateBasePriceMultiplier(uint256 basePriceMultiplier) public maint nonReentrant auth assetMgr {
        require(wdiv(basePriceMultiplier, priceMultiplierRa) < insaneChangeRateMax, "asm-pls-reduce-change");
        require(wdiv(basePriceMultiplier, priceMultiplierRa) > insaneChangeRateMin, "asm-pls-increase-change");
        priceMultiplierRa = basePriceMultiplier;
        emit LogPriceMultiplierBase(msg.sender, priceMultiplierRa);
    }

    function removeAssetManager(address assetManager, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth {
        require(assetManagers[assetManager], "asm-not-an-asset-manager");
        assetManagers[assetManager] = false;
        emit LogAssetManagerRemove(assetManager, descriptionHash, descriptionUrl);
    }

    function oracleUpdatePrices(
        address token,
        bool[] memory shapeRoundOrPear,
        uint24[] memory weightClass,
        bytes4[] memory clarity,
        bytes1[] memory color,
        uint256[] memory price)
    public maint nonReentrant auth oracle {
        require(dpasses[token], "asm-not-a-valid-token");
        uint diamond;
        uint currentPrice;
        uint currentWeight;
        uint newPrice;

        while(weightClass.length > diamond) {
            newPrice = price[diamond];
            require(newPrice > 0, "asm-invalid-price-provided");

            currentPrice = basePrice[shapeRoundOrPear[diamond]]
                [weightClass[diamond]]
                [color[diamond]]
                [clarity[diamond]];

            currentWeight = totalWeight[shapeRoundOrPear[diamond]]
                [weightClass[diamond]]
                [color[diamond]]
                [clarity[diamond]];

            totalCollateralV = currentPrice >= newPrice ?
                sub(totalCollateralV, wmul(sub(currentPrice, newPrice), currentWeight)) :
                add(totalCollateralV, wmul(sub(newPrice, currentPrice), currentWeight));

            basePrice[shapeRoundOrPear[diamond]]
                [weightClass[diamond]]
                [color[diamond]]
                [clarity[diamond]] = newPrice;

            diamond ++;
        }
    }

    function custodianWithdraw(address token, uint256 amt) public maint nonReentrant auth custodn {
        require(payTokens[token], "asm-cant-withdraw-token");
        require(tokenPurchaseRate[token] > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(tokenPurchaseRate[token], amt, token);

        require(
            add(
                add(
                    wmul(
                        totalCdcV,
                        wdiv(
                            allowedCdcMintValueCalc,
                            totalCollateralCustV[msg.sender])),
                    totalDpassSoldV[msg.sender]),
                dust) >=
            add(
                totalPaidV[msg.sender],
                tokenV)
            , "asm-too-much-withdrawn");

        _sendToken(token, address(this), msg.sender, amt);
        totalPaidV[msg.sender] = add(totalPaidV[msg.sender], tokenV);
    }

    function custodianDeposit(address token, uint256 amt) public maint nonReentrant auth custodn {
        require(allowDeposit[msg.sender][token][amt], "asm-not-allowed-to-deposit");
        require(payTokens[token], "asm-not-a-valid-token");
        uint balance = DSToken(token).balanceOf(address(this)); // this assumes that first tokens are sent, than notifyTransferFrom is called, if it is the other way around then amtOrId must not be subrtacted from current balance
        totalPaidV[msg.sender] = sub(totalPaidV[msg.sender], wmulV(updateRate(token), amt, token));

        DSToken(token).transferFrom(msg.sender, address(this), amt);

        tokenPurchaseRate[token] = wdiv(
            add(
                wmulV(
                    tokenPurchaseRate[token],
                    balance,
                    token),
                wmulV(rate[token], amt, token)),
            add(balance, amt));
        delete allowDeposit[msg.sender][token][amt];
        emit LogDeposited(msg.sender, token, amt);
    }

    function assetManagerAllowDeposit(address custodian, address token, uint256 amt) public maint nonReentrant auth assetMgr {
        require(custodians[custodian], "asm-not-a-custodian");
        require(payTokens[token], "asm-not-a-paytoken");
        allowDeposit[custodian][token][amt] = true;
        emit LogAllowDeposit(msg.sender, custodian, token, amt);
    }

    // TODO: unify type of diamond attributes
    function updateCustodianValue(
        address custodian,
        address token,
        bool[] memory shapeRoundOrPear,
        uint24[] memory weightClass,
        bytes4[] memory clarity,
        bytes1[] memory color,
        uint256[] memory price)
    public maint nonReentrant auth assetMgrOrCustdn {
        require(dpasses[token], "asm-not-a-valid-token");
        require(custodians[custodian], "asm-not-a-custodian");
        uint diamond;
        uint currentWeight;
        uint currentPrice;
        uint newPrice;
        uint oldCustV;
        uint newCustV;

        while(weightClass.length > diamond) {
            newPrice = price[diamond];
            require(newPrice > 0, "asm-invalid-price-provided");

            currentPrice = priceCust[custodian]
            [shapeRoundOrPear[diamond]]
            [weightClass[diamond]]
            [color[diamond]]
            [clarity[diamond]];

            currentWeight = weightCust[custodian]
            [shapeRoundOrPear[diamond]]
            [weightClass[diamond]]
            [color[diamond]]
            [clarity[diamond]];

            oldCustV = totalCollateralCustV[custodian];

            newCustV = sub(
                add(
                    totalCollateralV,
                    wmul(newPrice, currentWeight)),
                wmul(currentPrice, currentWeight));

            _updateCollateral(newCustV, oldCustV, custodian);

            diamond ++;
        }
    }

    function updateCustodianValue(address custodian, uint256 value) public maint nonReentrant auth assetMgr {
        require(assetMgrCanSetCollateralValue, "asm-asset-manager-not-allowed");

        _updateCollateral(value, totalCollateralCustV[custodian], custodian);
    }

    function notifyTransferFrom(address token, address src, address dst, uint256 amtOrId) external nonReentrant auth {
        uint price;
        uint balance;
        require(dpasses[token] || cdcs[token] || payTokens[token], "asm-invalid-token");

        if(dpasses[token] && custodians[src]) {                             // custodian sells dpass to user

            price = _getTokenPrice(token, amtOrId);

            _updateCollateral(0, price, src);
            dpassSoldV[src][token] = price;

            require(                                                        // custodian's total collateral value must be ...
                                                                            // more or equal than proportional cdc value and dpasses sold
                add(
                    wmul(
                        totalCdcV,
                        wdiv(
                            allowedCdcMintValueCalc,
                            totalCollateralCustV[src])),
                    totalDpassSoldV[src]) <=
                add(totalCollateralCustV[src], dust)
                , "asm-token-cant-be-sent");

        } else if (dst == address(this)) {                                  // user sells ERC20 token to us

            require(payTokens[token], "asm-we-dont-accept-this-token");

            if (cdcs[token]) {
                burn(token, address(this), amtOrId);
            }

            balance = sub(DSToken(token).balanceOf(address(this)), amtOrId); // this assumes that first tokens are sent, than notifyTransferFrom is called, if it is the other way around then amtOrId must not be subrtacted from current balance

            tokenPurchaseRate[token] = wdiv(
                add(
                    wmulV(
                        tokenPurchaseRate[token],
                        balance,
                        token),
                    wmulV(updateRate(token), amtOrId, token)),
                add(balance, amtOrId));

        } else if (dpasses[token]) {                                        // user sells erc721 token to custodian

            require(payTokens[token], "asm-token-not-accepted");

            price = _getTokenPrice(token, amtOrId);

            _updateCollateral(price, 0, dst);

        } else {
            require(false, "asm-should-not-end-up-here");
        }
    }

    function _getTokenPrice(address token, uint256 tokenId) internal view returns(uint256 price) {

        (,,,,,,bytes32[] memory attributeValues,) = Dpass(token).getDiamond(tokenId);

        (,,,,,price) = getAttributes(attributeValues);
    }

    function _updateCollateral(uint positiveV, uint negativeV, address custodian) internal {
        require(custodians[custodian], "asm-not-a-custodian");

        totalCollateralCustV[custodian] = sub(
            add(
                totalCollateralCustV[custodian],
                positiveV),
            negativeV);

        allowedCdcMintValueCalc = sub(
            add(
                allowedCdcMintValueCalc,
                positiveV),
            negativeV);

        totalCollateralV = sub(
            add(
                totalCollateralV,
                positiveV),
            negativeV);

        if (add(totalCdcV, dust) >= wmul(totalCollateralV, overCollRatio)) {
            if (add(totalCdcV, dust) >= totalCollateralV) {
                systemFlag = red;
                emit LogSystemFlag(red);
            } else {
                systemFlag = yellow;
                emit LogSystemFlag(yellow);
            }
        } else if (systemFlag != green) {
            systemFlag = green;
            emit LogSystemFlag(green);
        }
    }

    function getAmtForSale(address token) external view returns(uint256) {
        return wdivT(
            sub(
                wdiv(totalCollateralV, overCollRatio),
                totalCdcV),
            _getNewRate(token),
            token);
    }

    function mint(address token, address dst, uint256 amt) public maint nonReentrant auth {
        require(cdcs[token], "asm-token-is-not-cdc");
        totalCdcV = add(totalCdcV, wmulV(updateRate(token), amt, token));
        require(add(totalCollateralV, dust) >= wmul(overCollRatio, totalCdcV), "asm-not-enough-collateral");
        DSToken(token).mint(dst, amt);
    }

    function burn(address token, address src, uint256 amt) public maint nonReentrant auth {
        require(cdcs[token], "asm-token-is-not-cdc");
        uint tokenRate = updateRate(token);

        totalCdcV = sub(
            totalCdcV,
            wmulV(amt, tokenRate, token));
        DSToken(token).burn(src, amt);
    }

    function isOwnerOf(address token) external view returns(bool) {
        return cdcs[token] || dpasses[token];
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wdiv(wmul(a, b), decimals[token]);
    }

    /*
    * @dev calculates division with decimals adjusted to match from 18 to tokens precision
    */
    function wdivT(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wmul(wdiv(a,b), decimals[token]);
    }

    /**
    * @dev Maintenance function to check custodians
    */
    function _maintenance() internal {
        auditCustodian = next[auditCustodian];
        if (audit[auditCustodian] < block.timestamp - yellowFlagInterval) {
            _setFlag(auditCustodian, yellow);
        } else if (audit[auditCustodian] < block.timestamp - redFlagInterval) {
            _setFlag(auditCustodian, red);
            _updateCollateral(0, totalCollateralCustV[auditCustodian], auditCustodian);
        }

        // update cdc values
        currCdc = next[currCdc];
        _updateCdcValue(currCdc);                                            // TODO: optimize gas, call it once a day, or call by oracles
    }

    function _updateCdcValue(address cdc) internal {
        uint newValue = wmulV(DSToken(cdc).totalSupply(), updateRate(cdc), cdc);

        totalCdcV = sub(add(totalCdcV, newValue), cdcValues[cdc]);

        cdcValues[cdc] = newValue;
    }

    /**
    * @dev Get exchange rate for a token
    */
    function updateRate(address token) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token)) > 0, "updateRate: rate must be > 0");
        rate[token] = rate_;
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function _getNewRate(address token_) private view returns (uint rate_) {
        bool feedValid;
        bytes32 usdRateBytes;

        require(
            address(0) != priceFeed[token_],                            // require token to have a price feed
            "No price feed for token");

        (usdRateBytes, feedValid) = 
            TrustedFeedLike(priceFeed[token_]).peek();                  // receive DPT/USD price

        if (feedValid) {                                                // if feed is valid, load DPT/USD rate from it

            rate_ = uint(usdRateBytes);

        } else {

            require(manualRate[token_], "Manual rate not allowed");     // if feed invalid revert if manualEthRate is NOT allowed

            rate_ = rate[token_];
        }
    }

    /**
     * &dev send token or ether to destination
     */
    function _sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns(bool) {
        TrustedErc20 erc20 = TrustedErc20(token);

        if (token == eth && amount > dust) {                        // if token is Ether and amount is higher than dust limit
            require(src == msg.sender || src == address(this), "asm-wrong-src-address-provided");
            dst.transfer(amount);

            emit LogTransferEth(src, dst, amount);

        } else {

            if (amount > 0) erc20.transferFrom(src, dst, amount);   // transfer all of token to dst
        }
        return true;
    }
}
// TODO: variables declarations
// TODO: setup getters for mappings
// TODO: systemFlag should be dependent on custodian flags.
// TODO: Check why custodian must be a smart contract
// TODO: handle collaterals when moving all diamonds (when updateing move[custodian]
// TODO: do something with system flag
// TODO: set a round robin set of red flags on all dpass tokens for custodian.
// TODO: handle collaterals when moving (update desstination total collateral value)
