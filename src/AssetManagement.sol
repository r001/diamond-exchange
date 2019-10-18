pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/dpass.sol";
import "./DiamondExchange.sol";

/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract TrustedDSAuthority is DSAuthority {
    function stub() external;
}


contract TrustedDsToken {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function totalSupply() external view returns (uint);
    function balanceOf(address src) external view returns (uint);
    function allowance(address src, address guy) external view returns (uint);
}


contract TrustedAssetManagement {
    function notifyTransferFrom(address token, address src, address dst, uint256 id721) external;
    function getPrice(TrustedErc721 erc721, uint256 id721) external view returns(uint256);
    function getAmtForSale(address token) external view returns(uint256);
    function sendToken(address token, address dst, uint256 value) external;
    function isOwnerOf(address buyToken) external view returns(bool);

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
    event LogBuyTokenWithFee(
        uint256 indexed txId,
        address indexed sender,
        address custodian20,
        address sellToken,
        uint256 sellAmountT,
        address buyToken,
        uint256 buyAmountT,
        uint256 feeValue
    );

    //TODO: set what indexed after testing
    event LogConfigChange(bytes32 what, bytes32 value, bytes32 value1);

    event LogTransferEth(address src, address dst, uint256 val);
    event LogRedeem(address token, address msg.sender, uint256 tokenId);

}

// TODO: wallet functionality, proxy Contracts
contract DiamondExchange is DSAuth, DSStop, DSMath, DiamondExchangeEvents {
    TrustedErc721 public dpass;                             // DPASS default token address
    mapping(address => bool) assetManagers;                 // returns true for asset managers
    mapping(address => bool) custodianCandidates;           // returns true for asset managers
    mapping(address => bool) custodians;                    // returns true for custodians
    mapping(address => bool) oracles;                       // returns true for oracles
    mapping(address => bool) dpasses;                       // returns true for dpass tokens allowed in this contract
    mapping(address => bool) cdcs;                          // returns true for cdc tokens allowed in this contract
    mapping(address => bool) payTokens;                     // returns true for tokens allowed to make payment to custodians with
    mapping(bytes32 => bool) issuers;                       // returns true for valid issuers for dpass
    mapping(bytes32 => bool) states;                        // returns true for valid dpass states
    mapping(bool =>
            mapping(uint24 =>
            mapping(bytes1 =>
            mapping(bytes4 => uint)))) price;
    mapping(bool =>
            mapping(uint24 =>
            mapping(bytes1 =>
            mapping(bytes4 => uint)))) totalWeight;
    mapping(bytes32 => bool) shapes;                   // returns true for valid shapes
    mapping(bytes32 => bool) colors;                   // returns true for valid colors
    mapping(bytes32 => bool) clarities;                // returns true for valid clarities
    mapping(uint24 => uint24) weightEnd;               // returns the end of weight range with 2 decimals precision when calculating price 
    mapping(uint24 => uint24) removed;         // returns true if custodian exited the system.
    mapping(address => Redeem[])) redeem;
    mapping(address => uint) public decimals;               // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;               // stores decimals for each ERC20 token
    mapping(address => uint8) public flag;               // stores flags for custodians green is everything ok, yellow non-critical problem, red critical problem

    struct Redeem {
        address owner;
        uint next;
        uint prev;
        uint maxFee;
        address payToken;
        bytes32 state;
        uint blockNum
    }

    mapping(address => bool) payTokens;                 // address of tokens that are allowed to pay redeem fees with
    mapping(address => bool) visMajorReqest;            // visMajor request created by custodian, when something that puts collaterals at his place in critical danger 
    mapping(address => address) next;                   // stores a round robin ring of custodians that helps to check if they went into red flag.
    mapping(address => TrustedFeedLike) public priceFeed;   // price feed address for token
    
    int public totalCollateralV;                     // value of total excess collateral ( the total value of CDC that still can be sold)
    uint24 public weightRangeStart;                     // the smallest weight value we have price data for
    uint public minimumValid = 7 * 24 * 60 * 60;        // minimum this many seconds the redeem fee offer must be valid, default is one week
    uint green = 0;                                     // used with 'flag' denotes everything okay
    uint yellow = 1;                                    // used with 'flag' denotes non-critical problem with custodian
    uint red = 2;                                       // used with 'flag' denotes critical problem with custodian collaterals are subtracted from system, transfers disabled
    bool locked;                                        // used to make sure that functions are non reentrant
    address auditCustodian;                             // last checked custodian for audit
    uint priceMultiplierMp = 1 ether;                     // the default price is multiplied with this value to get 
    uint insaneChangeRateMin = 0.5 ether;               // the minimum rate of change in marketprice multiplier
    uint insaneChangeRateMax = 1.5 ether;               // the maximum rate of change in marketprice multiplier
    address cdc;                                    // the current cdc token to update the price for
    uint overCollRatio = 1.1 ether;                   // the totalCollateralV >= overCollRatio * totalCdcV 
//declarations----------------------------------------------------------------
    
    
    
    constructor() {
        issuers["GIA"] = true;
        states["inCustody"] = true;    
        shapes["BR"] = true;
        shapes["PS"] = true;
        colors["D"] = true; colors["E"] = true; colors["F"] = true; colors["G"] = true; colors["H"] = true; colors["I"] = true; colors["J"] = true; colors["K"] = true; colors["L"] = true; colors["M"] = true; colors["N"] = true;
        clarities["I1"] = true; clarities["I2"] = true; clarities["I3"] = true; clarities["IF"] = true; clarities["SI1"] = true; clarities["SI2"] = true; clarities["SI3"] = true; clarities["VS1"] = true; clarities["VS2"] = true; clarities["VVS1"] = true; clarities["VVS2"] = true;
        weightEnd[1] = 3; weightEnd[3] = 7; weightEnd[7] = 14; weightEnd[14] = 17; weightEnd[17] = 22; weightEnd[22] = 29; weightEnd[29] = 39; weightEnd[39] = 49; weightEnd[49] = 69; weightEnd[69] = 89; weightEnd[89] = 99; weightEnd[99] = 149; weightEnd[149] = 199; weightEnd[199] = 299; weightEnd[299] = 399; weightEnd[399] = 499; weightEnd[499] = 599; weightEnd[599] = 1099;
    }

    modifier maint {
        _maintenance();
        _;
    }
    
    modifier nonReentrant {
        require(!locked, "Reentrancy detected.");
        locked = true;
        _;
        locked = false;
    }

    modifier assetMgr {
        require(assetManagers[msg.sender], "You should be asset manager.");
        _;
    }

    modifier custodian {
        require(custodians[msg.sender], "You should be asset manager.");
        _;
    }
    
    modifier assetMgrOrCustdn {
        require(
            assetManagers[msg.sender] ||
            custodians[msg.sender],
            "Only asset manager or custodian");
        _;
    }

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public maint nonReentrant auth {
        if (what_ == "dpasses") {
            require(address(value_) != address(0), "Dpass address should be no zero.");
            dpasses[address(value_)] = uint(value1_) > 0;
        } else if (what_ == "cdcs") {
            address newCdc = address(value_);
            require(newCdc != address(0), "Cdc address should be no zero.");
            require(newCdc != cdc, "Cdc address should be no zero.");
            cdcs[newCdc] = uint(value1_) > 0;
            if(cdc == address(0)) {
                cdc = newCdc;
                next[cdc] = cdc;
            } else {
                next[newCdc] = next[cdc];
                next[cdc] = newCdc;
            }
            _updateCdcValue(newCdc);
        } else if (what_ == "payTokens") {
            require(address(value_) != address(0), "Pay token address should be no zero.");
            payTokens[value_] = uint(value1_) > 0;
        } else if (what_ == "issuers") {
            require(value_ != "", "Issuer should not be empty");
            issuers[value_] = uint(value1_) > 0;
        } else if (what_ == "states") {
            require(value_ != "", "State should not be empty");
            states[value_] = uint(value1_) > 0;
        } else if (what_ == "priceFeed") {

            require(cdcs[addr(value_)] || canBuyErc20[addr(value_)], "Token not allowed priceFeed");

            require(addr(value1_) != address(address(0x0)), "Wrong PriceFeed address");

            priceFeed[addr(value_)] = TrustedFeedLike(addr(value1_));

        } else if (what_ == "shapes") {
            require(value_ != "", "Shape should not be empty");
            states[value_] = uint(value1_) > 0;
        } else if (what_ == "colors") {
            require(value_ != "", "Color should not be empty");
            states[value_] = uint(value1_) > 0;
        } else if (what_ == "clarities") {
            require(value_ != "", "Clarities should not be empty");
            states[value_] = uint(value1_) > 0;
        } else if (what_ == "weightRangeStart") {
            weightRangeStart = uint24(value_);
        } else if (what_ == "weightEnd") {
            require( uint(value_) <= uint24(-1), "weightEnd out of range");
            require( uint(value1_) <= uint24(-1), "weightEnd out of range");
            weightEnd[uint24(value_)] = uint24(value1_);
        } else if (what_ == "yelloFlagInterval") {
            yellowFlagInterval = uint(value_);
            require(yellowFlagInterval != 0, "Yellow flag interval 0");
        } else if (what_ == "overCollRatio") {
            overCollRatio = uint(value_);
            require(overCollRatio >= 1 ether, "System must be overcollaterized");
            require(totalCollateralV >= wmul(overCollRatio, totalCdcV), "Can not introduce new ratio");
        }  else if (what_ == "redFlagInterval") {
            redFlagInterval = uint(value_);
            require(redFlagInterval != 0, "Red flag interval 0");
        } else if (what_ == "minimumValid") {
            minimumValid = uint(value_);
        } else if (what_ == "insaneChangeRateMax") {
            insaneChangeRateMax = uint(value_);
            require(insaneChangeRateMax > 1 ether, "Too small max rate");
            require(insaneChangeRateMax <= 2 ether, "Too large max rate");
        } else if (what_ == "insaneChangeRateMin") {
            insaneChangeRateMin = uint(value_);
            require(insaneChangeRateMin > 0.5 ether, "Too small max rate");
            require(insaneChangeRateMin <= 1 ether, "Too large max rate");
        } else if (what_ == "decimals") {
            require(addr(value_) != address(0x0), "Wrong address");

            uint decimal = uint256(value1_);

            if(decimal >= 18) {
            
                decimals[addr(value_)] = mul(10 ** 18, 10 ** (uint256(value1_) - 18));

            } else {

                decimals[addr(value_)] = div(10 ** 18, 10 ** (18 - uint256(value1_)));

            }

            decimalsSet[addr(value_)] = true;
        }
        emit LogConfigChange(what_, value_, value1_);
    }

    function assetManagerRegisterCustodian(address custodian, bool enable, bytes32 introHash, bytes32 introUrl) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "Zero address not allowed.");
        custodianCandidates[custodian] = enable; 
        LogConfigChange(custodian, bytes32(uint(enable?1:0)), introHash, introUrl); 
    }

    function custodianAcceptRegistration(bool accept, bytes32 introHash, bytes32 introUrl) public maint nonReentrant auth {
        require(custodianCandidates[msg.sender], "You should be enabled custodian.");
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
        LogConfigChange(msg.sender, bytes32(uint(accept?1:0)), introHash, introUrl); 
    }

    function custodianRegisterDiamond(address token, address to, bytes32 issuer, bytes32 report, uint256 ownerPrice, bytes32[] memory attributes, bytes32 attributesHash) public maint nonReentrant auth custodian {
        uint tokenId;
        require(dpasses[token], "Token not allowed");
        require(issuers[issuer], "Issuer not allowed");
        tokenId = Dpass(token).mintDiamondTo(msg.sender, msg.sender, issuer, report, ownerPrice, 0, "created", attributes, attributesHash);
        (uint24 weightRange, bool shape, uint24 weight, bytes1 color, bytes4 clarity, uint256 price) = getAttributes(attributes);
        totalCollateralV = add(totalCollateralV, price);

        totalWeight[shape][weightRange][color][clarity] = add(
            totalWeight[shape][weightRange][color][clarity], 
            weight);
    }

    function getAttributes(bytes32[] attributes) internal returns(uint24 weightRange, bool shape, uint24 weight, bytes1 color, bytes4 clarity, uint256 price) {
        weightRange = weightRangeStart;
        shape = uint(attributes[0]) > 0;
        weight = uint24(attributes[1]);
        color = attributes[2];
        clarity = attributes[3];

        require(shapes[shape], "Invalid shape");
        require(colors[color], "Invalid color");
        require(clarities[clarity], "Invalid clarity");
        require(weight > 0, "Weight can't be 0");
        while(weight > weightRange && weightEnd[weightRange] > 0) 
            weightRange = weightEnd[weightRange];
        require(weight <= weightRange, "Weight is too large");
        price = mul(price[shape][weightRange][color][clarity], weight) / 100; 
    }

    
    function custodianMoveDiamond(address dstCustodian, address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodian {
        moveDiamond(msg.sender, dstCustodian, token, tokenId, reasonHash, reasonUrl);
    }
    
    function getMove(address custodian, address token, uint256 tokenId) public nonReentrant view returns(address, address, uint256, uint256){
        require(custodians[custodian] != address(0), "Not a custodian");
        uint tokId = tokenId == 0 ? moveDiamondLastId[custodian][token] : tokenId;
        require(tokId != 0, "Token id can not be 0");
        MoveDiamond m = moveDiamond[token][tokenId]
        return (m.moveBy, m.moveTo, m.prev, m.next);
    } 

    function moveDiamond(address srcCustodian, address dstCustodian, address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl) internal {
        require(dpasses[token], "Token not allowed");
        require(custodians[srcCustodian] != address(0), "Not a custodian");
        require(custodians[dstCustodian] != address(0), "Not a custodian");
        require(Dpass(token).getCustodian(tokenId) == srcCustodian, "Not custodian of token");
        require(Dpass(token).getState(tokenId) != "invalid", "Token invalid");
        require(custodians[dstCustodian], "New custodian not allowed");
        moveDiamond[token][tokenId] = { moveBy: msg.sender, moveTo: dstCustodian, prev: moveDiamondLastId[dstCustodian][token], next: 0};
        if(moveDiamondLastId[custodian][token] > 0) moveDiamond[token][moveDiamondLastId[custodian][token]].next = tokenId;
        moveDiamondLastId[custodian][token] = tokenId;
        emit LogMoveDiamondRequest(srcCustodian, dstCustodian, token, tokenId, reasonHash, reasonUrl);
    }

    function assetManagerMoveDiamond(address srcCustodian, address dstCustodian, address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl) {
        require(custodians[srcCustodian] != address(0), "Not a custodian");
        require(custodians[dstCustodian] != address(0), "Not a custodian");
        require(flag[srcCustodian] == red, "Only if custodian red flagged"); 
        moveDiamond(msg.sender, dstCustodian, token, tokenId, reasonHash, reasonUrl);
    }

    function custodianAcceptMoveDiamond(address token, uint256 tokenId, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodian {
        MoveDiamond storage m = moveDiamond[token][tokenId];
        require(m.moveTo != msg.sender, "Nothing to accept");                
        require(dpasses[token], "Token not allowed");
        require(Dpass(token).getState(tokenId) != "invalid", "Token invalid");
        Dpass(token).setCustodian(tokenId, msg.sender);
        if(m.prev != 0) moveDiamond[token][m.prev].next = m.next;
        if(m.next != 0) moveDiamond[token][m.next].prev = m.prev
        delete m;
    }

    // TODO:
    function custodianRemoveDiamond(address token, uint256 tokenId) {
        require(dpasses[token], "Token not allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "Not custodian of token");
        require(Dpass(token).getState(tokenId) != "invalid", "Token invalid");
        require(Dpass(token).ownerOf(tokenId) == msg.sender, "You are not owner");
        Dpass(token).changeStateTo("removed", tokenId); 
        // TODO: make sure we can readd removed diamond, how does invalid state work? Must make sure we can handle invalid if eg.: bad attributes were added, make sure we can recreate token with same issuer and reportId.
        // TODO: what to do if diamond is removed because of theft, accident, and diamond is already sold?
    }

    function userRedeem(address token, uint256 tokenId, uint maxFeeV, address payToken, bytes32 state) {
        uint allowedToUs = min(
            DSToken(payToken).balanceOf(msg.sender),
            DSToken(payToken).allowance(msg.sender, address(this)));

        address custodian = Dpass(token).getCustodian(tokenId);
        Redeem storage redeem = redeemRequest[token][tokenId];

        require(Dpass(token).ownerOf(tokenId) == msg.sender, "You are not owner");
        require(dpasses[token], "Token not allowed");
        require(payTokens[payToken], "payToken not allowed");
        require(Dpasss(token).getApproved(tokenId) == address(this), "We are not approved");
        require(wdivT(maxFeeV, getRate(token), token) > allowedToUs, "payToken not enough");
        if(redeem.payToken == address(0)) {                              // if we create new redeem
            redeem = {
                owner: msg.sender,
                next: 0,
                prev: redeemRequestLastId[token],
                maxFee: maxFeeV,
                payToken: payToken,
                state: "",
                blockNum: block.number
                }
        } else {                                            // if we update existing redeem
            redeem.owner = msg.sender;
            redeem.maxFee = maxFeeV;
            redeem.payToken = payToken;
            redeem.state = state;
            redeem.blockNum = block.number;
        }

        if(redeemRequestLastId[custodian][token] > 0) redeemRequest[token][redeemRequestLastId[custodian][token]].next = tokenId;
        redeemRequestLastId[custodian][token] = tokenId;
        emit LogRedeem(token, msg.sender, tokenId);
    }

    function userDeleteRedeem(address token, uint256 tokenId) public maint nonReentrant {
       deleteRedeem(token, tokenId, userOrCustodian); 
    }

    function deleteRedeem(address token, uint256 tokenId, bool userOrCustodian) internal {
        address custodian = Dpass(token).getCustodian(tokenId);
        Redeem storage redeem = redeemRequest[token][tokenId];
        require(redeem.payToken != address(0), "Redeem never existed");
        require(!userOrCustodian || redeem.owner == msg.sender, "You are not owner of token");
        require(userOrCustodian || custodian == msg.sender, "You are not custodian of token");
        if(redeem.prev != 0) redeemRequest[token][redeem.prev].next = redeem.next;
        if(redeem.next != 0) redeemRequest[token][redeem.next].prev = redeem.prev
        delete redeem;
    }

    function getRedeemRequest(address custodian, address token, uint tokenId) public nonReentrant view returns (address,uint256, uint256, uint, address){
        require(custodians[custodian] != address(0), "Not a custodian");
        uint tokId = tokenId == 0 ? redeemRequestLastId[msg.sender][token] : tokenId;
        require(tokId != 0, "Token id can not be 0");
        Redeem r = redeemRequestLastId[custodian][token][tokId];
        return (r.owner, r.next, r.prev, r.maxFee, r.payToken, r.state);
    }

    function custodianRedeemCharge(address token, uint256 tokenId, uint256 priceV) public maint nonReentrant auth custodian {
        address tokenOwner = Dpass(token).ownerOf(tokenId);
        Redeem redeem = redeemRequest[token][tokenId];
        uint priceT;
        require(redeem.owner == tokenOwner, "Owner changed since redeem.");
        require(dpasses[token], "Token not allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "Not custodian of token");
        priceT = wdivT(priceV, getRate(redeem.payToken), redeem.payToken);
        DSToken(redeem.payToken).transferFrom(redeem.owner, Dpass(token).getCustodian(tokenId), priceT);
        Dpass(token).redeem(tokenId);
        deleteRedeem(token, tokenId, false);
    }

    function custodianRedeemSetState(address token, uint256 tokenId, bytes32 state) public maint nonReentrant custodian auth {
        require(dpasses[token], "Token not allowed");
        require(Dpass(token).getCustodian(tokenId) == msg.sender, "Not custodian of token");
        require(redeemStates[state], "Not allowed redeem state");
        redeem[msg.sender][token][tokenID].state = state;
        emit LogRedeemState(token, tokenId, state);
    }

    function custodianVisMajorNotify(bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth custodian {
        visMajorReqest[msg.sender] = true;
        emit LogVisMajorRequest(msg.sender, descriptionHash, descriptionUrl);
    }

    function assetManagerVisMajorConsent(uint8 flag, address custodian, bytes32 descriptionHash, bytes32 descriptionURL) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "Zero address not allowed.");
        require(visMajorReqest[custodian], "Only if custodian requested"); 
        flag[custodian] = flag;
        emit LogAssetManagerVisMajor(msg.sender, custodian, flag, descriptionHash, descriptionUrl);
    }

    function auditorVisMajor(address custodian, bytes32 descriptionHash, bytes32 descriptionURL, uint8 flag) public maint nonReentrant auth auditor {
        require(custodian != address(0), "Zero address not allowed.");
        require(flag[custodian] == red, "Custodian should be red flagged");
        flag[custodian] = flag;
        delete visMajorRequest[custodian];
        emit LogAuditorVisMajor(msg.sender, custodian, flag, descriptionHash, descriptionUrl);
    }


    function custodianKeyCompromised(address compromised, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth custodian {
        require(compromised != address(0), "Zero address not allowed.");
        keyCompromisedRequest[msg.sender] = true;
        emit LogCustodianKeyCompromisedRequest(msg.sender, compromised, descriptionHash, descriptionUrl);
    }

    function assetManagerKeyCompromisedAccept(address custodian, address oldAddress, address newAddress, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth assetMgr {
        require(oldAddress != address(0), "Zero old address not allowed.");
        require(newAddress != address(0), "Zero new address not allowed.");
        require(keyCompromisedRequest[custodian], "There was no request");
        CustodianLike(custodian).removeAddress(oldAddress);
        CustodianLike(custodian).addAddress(newAddress);
        delete keyCompromisedRequest[custodian];
        emit LogCustodianKeyCompromised(msg.sender, custodian, oldAddress, newAddress, descriptionHash, descriptionUrl);
    }

    function assetManagerKeyCompromised(address custodian, address compromised, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "Zero address not allowed.");
        require(custodians[custodian] != address(0), "Not a custodian");
        require(compromised != address(0), "Zero address not allowed.");
        keyCompromisedRequestAssetMgr[custodian] = true;
        emit LogCustodianKeyCompromisedRequestAssetMgr(msg.sender, compromised, descriptionHash, descriptionUrl);
    }

    function auditorKeyCompromisedAccept(address custodian, address oldAddress, address newAddress, bytes32 descriptionHash, bytes32 descriptionUrl) public maint nonReentrant auth auditor {
        require(custodian != address(0), "Zero address not allowed.");
        require(custodians[custodian] != address(0), "Not a custodian");
        require(oldAddress != address(0), "Zero address not allowed.");
        require(newAddress != address(0), "Zero address not allowed.");
        require(keyCompromisedRequestAssetMgr[custodian], "There was no request");
        CustodianLike(custodian).removeAddress(oldAddress);
        CustodianLike(custodian).addAddress(newAddress);
        delete keyCompromisedRequest[custodian];
        emit LogCustodianKeyCompromisedAssetMgr(msg.sender, custodian, oldAddress, newAddress, descriptionHash, descriptionUrl);
    }

    function assetManagerRemoveCustodian(address custodian, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "Zero address not allowed.");
        require(custodians[custodian] != address(0), "Not a custodian");
        custodianToRemove[custodian] = true;
        emit RemoveCustodianRequest(msg.sender, custodian, reasonHash, reasonUrl);
    }

    function custodianRemoveCustodianAccept(bool accept, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodian {
        _removeCustodian(msg.sender, accept, reasonHash, reasonUrl);
    }

    function _removeCustodian(address custodian, bool accept, bytes32 reasonHash, bytes32 reasonUrl) internal {
        require(custodian != address(0), "Zero address not allowed.");
        require(custodianToRemove[custodian], "Remove was not requested");
        require(custodians[custodian] != address(0), "Not a custodian");
        removed[custodian] = accept;
        if(accept) {
            custodianToRemove[msg.sender] = false;
            flag[msg.sender] = red;
            emit Flag(msg.sender, red);
        }
        emit LogRemoveCustodian(msg.sender, custodian, accept, reasonHash, reasonUrl);
    }

    function auditorRemoveCustodianAccept(address custodian, bool accept, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth auditor {
        _removeCustodian(custodian, accept, reasonHash, reasonUrl);
    }

    function reportInfo(bytes32 issueHash, bytes32 issueUrl) public maint nonReentrant auth { // custodians, asset managers, auditors can report issue
        if(!banReport[msg.sender])
            emit Info(issueHash, issueUrl);
    }

    function assetManagerBanInfo(address reporter, bool ban) public maint nonReentrant auth assetMgr {
        require(reporter != address(0), "Zero address not allowed.");
        require(custodians[reporter], "Zero address not allowed.");
        banReport[custodian] = ban;
        emit LogCustodianBan(msg.sender, reporter, ban);
    }
    
    function custodianMove(address newCustodian, bool enable, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodian {
        require(custodians[newCustodian] != address(0), "Src not a custodian");
        if(enable) {
            srcCustodianMove[newCustodian] = msg.sender;    
        } else {
            delete srcCustodianMove[newCustodian];
        }

        emit LogMoveDiamonds(enable ? msg.sender : address(0), newCustodian, reasonHash, reasonUrl);
    }
    
    function assetManagerMove(address srcCustodian, address dstCustodian, bytes32 reasonHash, bytes32 reasonUrl) {
        require(removed[srcCustodian] || srcCustodianMove[dstCustodian], "Not possible to move yet"); 
        require(custodians[srcCustodian] != address(0), "Src not a custodian");
        require(custodians[dstCustodian] != address(0), "Dst not a custodian");
        asMgrCustodianMove[dstCustodian] = srcCustodian;
        move[sourceCustodian] = msg.sender;
    }

    function custodianMoveAccept(address dstCustodian, bytes32 reasonHash, bytes32 reasonUrl) public maint nonReentrant auth custodian {
        require(asMgrCustodianMove[msg.sender] != address(0) || srcCustodianMove[msg.sender] != address(0), "Move not initiated");
        address sourceCustodian = srcCustodianMove[msg.sender];
        require(sourceCustodian != address(0),"Move is not possible"); 
        move[sourceCustodian] = msg.sender;
        emit LogMoveDiamonds(sourceCustodian, msg.sender, reasonHash, reasonUrl);
    }

    
    function auditorAuditCustodian(address custodian, uint8 newFlag, bytes32 descriptionHash, bytes32 descriptionURL) public maint nonReentrant auth auditor {
        require(custodian != address(0), "Zero custodian not allowed");
        require(custodians[custodian] != address(0), "Not a custodian");
        audit[custodian] = now;
        lastAuditor[custodian] = msg.sender;
        flag[custodian] = newFlag;
        emit Flag(msg.sender, custodian, newFlag);
        emit Audit(msg.sender, custodian, descriptionHash, descriptionUrl);
    }

    function assetManagerAuditCustodian(address custodian, uint8 newFlag, bytes32 descriptionHash, bytes32 descriptionURL) public maint nonReentrant auth assetMgr {
        require(custodian != address(0), "Zero custodian not allowed");
        require(custodians[custodian] != address(0), "Not a custodian");
        require(newFlag != red, "Red flag not possible");
        flag[custodian] = newFlag;
        emit Flag(msg.sender, custodian, newFlag);
        emit Audit(msg.sender, custodian, descriptionHash, descriptionUrl);
    }

    function registerAssetManager(address assetManager, bytes32 descriptionHash, bytes32 descriptionURL) public maint nonReentrant auth {
        require(assetManager != address(0), "Zero address not allowed");
        require(!assetManagers[assetManager], "Already registered");
        assetManagers[assetManager] = true;
        emit LogAssetManager(assetManager, descriptionHash, descriptionUrl);
    }

    function updateMarketplacePrice(address token, uint256 id, uint256 marketPrice) public maint nonReentrant auth assetMgr {
        require(dpasses[token], "Token not valid"); 
        Dpass(token).setMarketPlacePrice(id, marketPrice);
    }

    function updateMarketplacePriceMultiplier(uint256 newPriceMultiplier) public maint nonReentrant auth assetMgr { // update marketplaceprice multiplier, make change safe: if too much change then price update not possible.
        require(wdiv(newPriceMultiplier, priceMultiplierMp) < insaneChangeRateMax, "Pls reduce change");
        require(wdiv(newPriceMultiplier, priceMultiplierMp) > insaneChangeRateMin, "Pls increase change");
        priceMultiplierMp = newPriceMultiplier;
        emit LogPriceMultiplierMarketplace(msg.sender, priceMultiplierMp);
    }

    function updateRapaportPriceMultiplier(uint256 rapaportPriceMultiplier) public maint nonReentrant auth assetMgr { // update marketplaceprice multiplier, make change safe: if too much change then price update not possible.
        require(wdiv(rapaportPriceMultiplier, priceMultiplierRa) < insaneChangeRateMax, "Pls reduce change");
        require(wdiv(rapaportPriceMultiplier, priceMultiplierRa) > insaneChangeRateMin, "Pls increase change");
        priceMultiplierRa = rapaportPriceMultiplier;
        emit LogPriceMultiplierRapaport(msg.sender, priceMultiplierRa);
    }

    function removeAssetManager(address assetManager, bytes32 descriptionHash, bytes32 descriptionURL) public maint nonReentrant auth {
        require(assetManagers[assetManager], "Not an asset manager");
        assetManagers[assetManager] = false;
        emit LogAssetManagerRemove(assetManager, descriptionHash, descriptionUrl);
    }

    function registerOracle(address oracle) public maint nonReentrant auth {
        retuire(oracle != address(0), "Zero address not allowed");
        oracles[oracle] = true;
        emit LogOracleRegistered(msg.sender, oracle);
    }

    function removeOracle(address oracle) public maint nonReentrant auth {
        retuire(oracles[oracle], "Not an oracle");
        oracles[oracle] = false;
        emit LogOracleRemoved(msg.sender, oracle);
    }

    function oracleUpdatePrices(address token, bool[] shapeRoundOrPear, uint24[] weightClass, uint8[] clarity, uint8[] color, uint256[] price) public maint nonReentrant auth oracle {
        require(dpasses[token], "Not a valid token");
        uint diamond;
        uint currentPrice;
        uint newPrice;
        while(weight.length > diamond) {
            newPrice = price[diamond];
            require(price > 0, "invalid price provided");
            currentPrice = price[shapeRoundOrPear[diamond]][weightClass[diamond]][color[diamond]][clarity[diamond]];
            currentWeight = weight[shapeRoundOrPear[diamond]][weightClass[diamond]][color[diamond]][clarity[diamond]];
            totalCollateralV = currentPrice >= newPrice ?
                sub(totalCollateralV, wmul(sub(currentPrice, newPrice), currentWeight) :
                add(totalCollateralV, wmul(sub(newPrice, currentPrice), currentWeight);
            diamond ++;
        }
    }
    
    function custodianWithdraw(addres token, uint256 amt) {
    
    }

    // TODO: uify type of diamond attributes
    function updateCustodianValue(address custodian, address token, bool[] shapeRoundOrPear, uint256[] weightClass, uint8[] clarity, uint8[] color, uint256[] price) public maint nonReentrant auth assetMgrOrCustdn {
        require(dpasses[token], "Not a valid token");
        require(custodians[custodian], "Not a custodian");
        uint diamond;
        uint currentPrice;
        uint newPrice;
        uint oldCustV;
        while(weight.length > diamond) {
            newPrice = price[diamond];
            require(price > 0, "invalid price provided");
            currentPrice = priceCust[custodian][shapeRoundOrPear[diamond]][weightClass[diamond]][color[diamond]][clarity[diamond]];
            currentWeight = weightCust[custodian][shapeRoundOrPear[diamond]][weightClass[diamond]][color[diamond]][clarity[diamond]];
            oldCustV = totalCollateralValueCust[custodian];
            newCustV = currentPrice >= newPrice ?
                sub(totalCollateralV, wmul(sub(currentPrice, newPrice), currentWeight) :
                add(totalCollateralV, wmul(sub(newPrice, currentPrice), currentWeight);
            allowedCdcMintValueCalc = oldCustV >= newCustV ? 
                sub(allowedCdcMintValueCalc, sub(oldCustV, newCustV)):
                add(allowedCdcMintValueCalc, sub(newCustV, oldCustV)):
            totalCollateralValueCust[custodian] = newCustodian;
            diamond ++;
        }
    }

    function notifyTransferFrom(address dpass, address src, address dst, uint256 id721) external nonReentrant auth {
        require(dpasses[dpass], "ASM: Invalid token");
        // TODO: check if it is invalid

        // TODO: rest of code

    }

    function getPrice(TrustedErc721 erc721, uint256 id721, bool sell) external view returns(uint256) public view returns (uint256 price) {
        require(dpasses[address(erc721)], "Not a dpass token");
        
        (address owner,,,,uint ownerPrice, uint marketplacePrice, bytes32 state,, bytes32[] memory attributeValues,) = Dpass(address(erc721)).getDiamond(id721);
        
        require(state != "invalid", "Token should be valid");

        if(ownerPrice == 0 || sell) {
            if(marketPlacePrice == 0 || sell) {
               (,,,,,price) = getAttributes(attributeValues);
            } else {
                return marketplacePrice;
            }
        } else {
            return ownerPrice;
        }
    }

    function getAmtForSale(address token) external view returns(uint256) public view {
        return wdivT(sub(wdiv(totalCollateralV, overCollRatio), totalCdcV), getRate(token));
    }

    function mint(address token, address dst, uint256 amt) public maint nonReentrant auth {
        require(cdcs[token], "Token is not cdc");        
        if (totalCollateralV >= wmul(overCollRatio , add(totalCdcV, wmulV(getRate(token), amt)))) {
            DSToken(token).mint(dst, amt);
        }
    }

    function isOwnerOf(address token) external view returns(bool) public view {
        return cdcs[buyToken];
    }

    // TODO: recheck everything from the aspect of collaterization (removing, red flagging custodian) and the effect of collaterization
    // TODO: variables declarations
    // TODO: setup getters for mappings
    // TODO: make sure dpass will make use of red flag
    // TODO: function to mint cdc to someone
    // TODO: custodian contract have a diamondExhchange.denyToken(address token) function
    // TODO: custodian payment management (who gets how much) tit will be a proportional system, diverted with DPASS sent to user for CDC payment

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a, uint256 b, address token) public nonReentrant view returns(uint256) {
        return wmul(wdiv(a,b), decimals[token];
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public nonReentrant view returns (uint8) {
        require(decimalsSet[token_], "Token with unset decimals");
        int dec = 0; 
        while(dec <= 77 && decimals[token_] % 10 ** dec == 0){
            dec++;
        }
        return dec;
    }

    /**
    * @dev Maintenance function to check custodians
    */
    function _maintenance() internal {
        auditCustodian = next[auditCustodian];
        if(audit[auditCustodian] < now - yellowFlagInterval) {
            flag[auditCustodian] = yellow;
            emit Flag(msg.sender, auditCustodian, yellow);
        } else if (audit[auditCustodian] < now - redFlagInterval) {
            flag[auditCustodian] = red;
            emit Flag(msg.sender, auditCustodian, red);
        }

        // update cdc values
        cdc = next[cdc];                    
        updateCdcValue(cdc);                                            // TODO: optimize gas, call it once a day, or call by oracles
    }

    function _updateCdcValue(address cdc) internal {
        newRate = getRate(cdc);
        newValue = wmul(cdc.totalSupply(), newRate);
        
        totalCdcV = newValue >= cdcValues[cdc] ?
            add(totalCdcV, sub(newValue, cdcValues[cdc])) :
            sub(totalCdcV, sub(cdcValues[cdc], newValue));

        cdcValues[cdc] = newValue;
    }
}
