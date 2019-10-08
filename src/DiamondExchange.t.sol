pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "./CdcExchange.sol";
import "./Burner.sol";


contract TestFeeCalculator is DSMath {
    uint public fee;

    function calculateFee(
        address sender,
        uint256 value,
        address sellToken, 
        uint256 sellAmtOrId, 
        address buyToken,
        uint256 buyAmtOrId
    ) external view returns (uint256) {
        if (sender == address(0x0)) {return 0;}
        if (sellToken == address(0x0)) {return 0;}
        if (buyToken == address(0x0)) {return 0;}
        return add(add(add(value, sellAmtOrId), buyAmtOrId), fee);
    }

    function setFee(uint fee_) public {
        fee = fee_;
    }
}


contract TestFeedLike {
    bytes32 public rate;
    bool public feedValid;

    constructor(uint rate_, bool feedValid_) public {
        require(rate_ > 0, "TestFeedLike: Rate must be > 0");
        rate = bytes32(rate_);
        feedValid = feedValid_;
    }

    function peek() external view returns (bytes32, bool) {
        return (rate, feedValid);
    }

    function setRate(uint rate_) public {
        rate = bytes32(rate_);
    }

    function setValid(bool feedValid_) public {
        feedValid = feedValid_;
    }
}


contract DptTester {
    DSToken public _dpt;

    constructor(DSToken dpt) public {
        require(address(dpt) != address(0), "CET: dpt 0x0 invalid");
        _dpt = dpt;
    }

    function doApprove(address to, uint amount) public {
        DSToken(_dpt).approve(to, amount);
    }

    function doTransfer(address to, uint amount) public {
        DSToken(_dpt).transfer(to, amount);
    }

    function () external payable {
    }
}


contract CdcExchangeTester {
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    CdcExchange public exchange;

    DSToken public _dpt;
    DSToken public _cdc;
    DSToken public _dai;

    constructor(address payable exchange_, address dpt, address cdc, address dai) public {
        require(exchange_ != address(0), "CET: exchange 0x0 invalid");
        require(dpt != address(0), "CET: dpt 0x0 invalid");
        require(cdc != address(0), "CET: cdc 0x0 invalid");
        require(dai != address(0), "CET: dai 0x0 invalid");
        exchange = CdcExchange(exchange_);
        _dpt = DSToken(dpt);
        _cdc = DSToken(cdc);
        _dai = DSToken(dai);
    }

    function () external payable {
    }

    function doApprove(address token, address to, uint amount) public {
        require(token != address(0), "Can't approve token of 0x0");
        require(to != address(0), "Can't approve address of 0x0");
        DSToken(token).approve(to, amount);
    }

    function doApprove721(address token, address to, uint amount) public {
        require(token != address(0), "Can't approve token of 0x0");
        require(to != address(0), "Can't approve address of 0x0");
        Dpass(token).approve(to, amount);
    }

    function doTransfer(address token, address to, uint amount) public {
        DSToken(token).transfer(to, amount);
    }

    function doTransferFrom(address token, address from, address to, uint amount) public {
        DSToken(token).transferFrom(from, to, amount);
    }

    function doBuyTokensWithFee(
        address sellToken, 
        uint256 sellAmtOrId, 
        address buyToken,
        uint256 buyAmtOrId
    ) public payable {
        if (sellToken == address(0xee)) {
            
            CdcExchange(exchange)
            .buyTokensWithFee
            .value(sellAmtOrId == uint(-1) ? address(this).balance : sellAmtOrId)
            (sellToken, sellAmtOrId, buyToken, buyAmtOrId);

        } else {
            
            CdcExchange(exchange).buyTokensWithFee(sellToken, sellAmtOrId, buyToken, buyAmtOrId);
        }
    }

    function doSetConfig(bytes32 what, address value_, address value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, address value_, bytes32 value1_) public { doSetConfig(what, b32(value_), value1_); }
    function doSetConfig(bytes32 what, address value_, uint256 value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, address value_, bool value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, address value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, bytes32 value1_) public { doSetConfig(what, b32(value_), value1_); }
    function doSetConfig(bytes32 what, uint256 value_, uint256 value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }
    function doSetConfig(bytes32 what, uint256 value_, bool value1_) public { doSetConfig(what, b32(value_), b32(value1_)); }

    function doSetConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public {
        CdcExchange(exchange).setConfig(what_, value_, value1_);
    }
    
    function doGetDecimals(address token_) public view returns(uint8) {
        return CdcExchange(exchange).getDecimals(token_);
    }

    /**
    * @dev Convert address to bytes32
    * @param a address that is converted to bytes32
    * @return bytes32 conversion of address
    */
    function b32(address a) public pure returns (bytes32) {
        return bytes32(uint256(a));
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a uint value to be converted
    * @return bytes32 converted value
    */
    function b32(uint a) public pure returns (bytes32) {
        return bytes32(a);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a_ bool value to be converted
    * @return bytes32 converted value
    */
    function b32(bool a_) public pure returns (bytes32) {
        return bytes32(uint256(a_ ? 1 : 0));
    }

    /**
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b) public pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function doToDecimals(uint256 amt_, uint8 srcDec_, uint8 dstDec_) public view returns (uint256) {
        return CdcExchange(exchange).toDecimals(amt_, srcDec_, dstDec_);
    }

    function doCalculateFee(
        address sender_,
        uint256 value_,
        address sellToken_, 
        uint256 sellAmtOrId_, 
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256) {
        return CdcExchange(exchange).calculateFee(sender_, value_, sellToken_, sellAmtOrId_, buyToken_, buyAmtOrId_);
    }

    function doGetRate(address token_) public view returns (uint rate_) {
        return CdcExchange(exchange).getRate(token_);
    }

    function doGetLocalRate(address token_) public view returns (uint rate_) {
        return CdcExchange(exchange).getRate(token_);
    }

}


contract TrustedASMTester {
    bool public txEnabled = true;
    mapping(address => mapping( uint256 => uint256)) public price;
    mapping(address => uint256) public forSale;
    mapping(address => bool) public own;

    function setPrice(address erc721, uint256 id721, uint256 price_) public {
        price[erc721][id721] = price_;
    }
    
    function setTxEnabled(bool enabled_) public {
        txEnabled = enabled_;
    }

    function setAmtForSale(address token, uint256 amtForSale) public {
        forSale[token] = amtForSale;
    }
    
    function setOwnerOf(address token, bool isOwner) public {
        own[token] = isOwner;
    }

    function sendToken(address token, address dst, uint256 value) public {
       DSToken tok = DSToken(token);
       tok.transfer(dst, value);
    }

    function notifyTransferFrom(TrustedErc721 erc721, address src, address dst, uint256 id721) public view {
        // begin----------------- just to avoid compiler warnings --------
        TrustedErc721 a;
        address b;
        uint c;
        
        a = erc721;
        b = src;
        b = dst;
        c = id721;
        // end----------------- just to avoid compiler warnings --------

        require(txEnabled, "Transaction is not allowed");
    }

    function getPrice(address erc721, uint256 id721) public view returns(uint256) {
        return price[erc721][id721];
    }

    function getAmtForSale(address token) public view returns (uint256){
        return forSale[token];
    }

    function isOwnerOf(address token) public view returns(bool) {
        return own[token];
    }

    function () external payable {
    }
}


contract CdcExchangeTest is DSTest, DSMath, CdcExchangeEvents {
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    uint public constant SUPPLY = (10 ** 10) * (10 ** 18);
    uint public constant INITIAL_BALANCE = 1000 ether;

    address public cdc;             // Cdc()
    address public dpass;           // Dpass()
    address public dpass1;           // Dpass()
    address public dpt;                         // DSToken()
    address public dai;     // DSToken()
    address public eth;
    address public eng;
    address payable public exchange; // CdcExchange()

    address payable public liquidityContract;   // CdcExchangeTester()
    address payable public wal;                 // DptTester()
    address payable public asm;                 // TrustedASMTester()
    address payable public user;                // CdcExchangeTester()
    address payable public seller;         // CdcExchangeTester()

    address payable public burner;              // Burner()
    address payable public fca;                 // TestFeeCalculator()

    // test variables
    mapping(address => mapping(address => uint)) public balance;
    mapping(address => mapping(uint => uint)) public usdRateDpass;
    mapping(address => uint) public usdRate;
    mapping(address => address) feed;                           // address => TestFeedLike()
    mapping(address => address payable) custodian20;
    mapping(address => uint8) public decimals;
    mapping(address => bool) public decimalsSet;
    mapping(address => uint) public dpassId;
    mapping(address => bool) public erc20;                      // tells if token is ERC20 ( eth considered ERC20 here)

    uint public fixFee = 0 ether;           
    uint public varFee = .2 ether;          // variable fee is 20% of value
    uint public profitRate = .3 ether;      // profit rate 30%
    bool public takeProfitOnlyInDpt = true; // take only profit or total fee (cost + profit) in DPT 

    // variables for calculating expected behaviour --------------------------
    uint userDpt;
    uint feeDpt;
    uint feeSellTokenT;
    uint restOfFeeT;
    uint restOfFeeV;
    uint restOfFeeDpt;
    uint feeV;
    uint buySellTokenT;
    uint sentV;
    uint profitV;
    uint profitDpt;
    uint feeSpentDpt;
    uint profitSellTokenT;
    uint expectedBalance;

    function setUp() public {
        cdc = address(new Cdc());
        dpass = address(new Dpass());
        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));   // TODO: make sure it is 8 decimals

        erc20[cdc] = true;
        erc20[dpt] = true;
        erc20[dai] = true;
        erc20[eng] = true;
        erc20[eth] = true;

        DSToken(dpt).mint(SUPPLY);
        DSToken(dai).mint(SUPPLY);
        DSToken(eng).mint(SUPPLY);
        DSToken(cdc).mint(SUPPLY);

        usdRate[dpt] = 5 ether;
        usdRate[cdc] = 7 ether;
        usdRate[eth] = 11 ether;
        usdRate[dai] = 13 ether;

        decimals[dpt] = 18;
        decimals[cdc] = 18;
        decimals[eth] = 18;
        decimals[dai] = 18;

        decimalsSet[dpt] = true;
        decimalsSet[cdc] = true;
        decimalsSet[eth] = true;
        decimalsSet[dai] = true;

        feed[eth] = address(new TestFeedLike(usdRate[eth], true));
        feed[dpt] = address(new TestFeedLike(usdRate[dpt], true));
        feed[cdc] = address(new TestFeedLike(usdRate[cdc], true));
        feed[dai] = address(new TestFeedLike(usdRate[dai], true));

        burner = address(uint160(address(new Burner(DSToken(dpt))))); // Burner()


        wal = address(uint160(address(new DptTester(DSToken(dai))))); // DptTester()
        asm = address(uint160(address(new TrustedASMTester())));
        
        custodian20[dpt] = asm;
        custodian20[cdc] = asm;
        custodian20[eth] = asm;
        custodian20[dai] = asm;

        TrustedASMTester(asm).setOwnerOf(cdc, true);                             // asset management will handle this token
        TrustedASMTester(asm).setAmtForSale(cdc, INITIAL_BALANCE);
        Cdc(cdc).transfer(asm, INITIAL_BALANCE);

        TrustedASMTester(asm).setOwnerOf(dpass, true);

        liquidityContract = address(uint160(address(new CdcExchangeTester(address(0xfa), dpt, cdc, dai)))); // FAKE DECLARATION, will overdeclare later
        DSToken(dpt).transfer(liquidityContract, INITIAL_BALANCE);
        
        exchange = address(uint160(address(new CdcExchange(
            cdc,
            dpt,
            dpass,
            feed[eth],
            feed[dpt],
            feed[cdc],
            liquidityContract,
            burner,
            asm,
            fixFee,
            varFee,
            profitRate,
            wal
        ))));
        CdcExchange(exchange).setConfig("canSellErc20", dai, true);
        CdcExchange(exchange).setConfig("priceFeed", dai, feed[dai]);
        CdcExchange(exchange).setConfig("rate", dai, usdRate[dai]);
        CdcExchange(exchange).setConfig("manualRate", dai, true);
        CdcExchange(exchange).setConfig("decimals", dai, 18);
        CdcExchange(exchange).setConfig("custodian20", dai, custodian20[dai]);
        // CdcExchange(exchange).setConfig("handledByAsm", dai, true);      // set true if token can be bougt by user and asm should handle it

        CdcExchange(exchange).setConfig("canSellErc20", eth, true);
        CdcExchange(exchange).setConfig("priceFeed", eth, feed[eth]);
        CdcExchange(exchange).setConfig("rate", eth, usdRate[eth]);
        CdcExchange(exchange).setConfig("manualRate", eth, true);
        CdcExchange(exchange).setConfig("decimals", eth, 18);
        CdcExchange(exchange).setConfig("custodian20", eth, custodian20[eth]);
        // CdcExchange(exchange).setConfig("handledByAsm", eth, true);      // set true if token can be bougt by user and asm should handle it

        CdcExchange(exchange).setConfig("canSellErc20", cdc, true);
        CdcExchange(exchange).setConfig("canBuyErc20", cdc, true);
        CdcExchange(exchange).setConfig("custodian20", cdc, custodian20[cdc]);
        CdcExchange(exchange).setConfig("priceFeed", cdc, feed[cdc]);
        CdcExchange(exchange).setConfig("rate", cdc, usdRate[cdc]);
        CdcExchange(exchange).setConfig("manualRate", cdc, true);
        CdcExchange(exchange).setConfig("decimals", cdc, 18);

        CdcExchange(exchange).setConfig("canSellErc20", dpt, true);
        CdcExchange(exchange).setConfig("custodian20", dpt, asm);
        CdcExchange(exchange).setConfig("priceFeed", dpt, feed[dpt]);
        CdcExchange(exchange).setConfig("rate", dpt, usdRate[dpt]);
        CdcExchange(exchange).setConfig("manualRate", dpt, true);
        CdcExchange(exchange).setConfig("decimals", dpt, 18);
        CdcExchange(exchange).setConfig("custodian20", dpt, custodian20[dpt]);
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(takeProfitOnlyInDpt), "");

        liquidityContract = address(uint160(address(new CdcExchangeTester(exchange, dpt, cdc, dai))));
        DSToken(dpt).transfer(liquidityContract, INITIAL_BALANCE);
        CdcExchangeTester(liquidityContract).doApprove(dpt, exchange, uint(-1));
        CdcExchange(exchange).setConfig("liq", liquidityContract, "");

        user = address(uint160(address(new CdcExchangeTester(exchange, dpt, cdc, dai))));
        seller = address(uint160(address(new CdcExchangeTester(exchange, dpt, cdc, dai))));
        fca = address(uint160(address(new TestFeeCalculator())));

        Cdc(cdc).approve(exchange, uint(-1));
        DSToken(dpt).approve(exchange, uint(-1));
        DSToken(dai).approve(exchange, uint(-1));
        
        // Prepare dpass tokens
        uint dpassOwnerPrice = 137 ether;
        bytes32[] memory attributes = new bytes32[](5); 
        attributes[0] = "round";
        attributes[1] = "2.1";
        attributes[2] = "G";
        attributes[3] = "VVS1";
        attributes[4] = "";

        dpassId[user] = Dpass(dpass).mintDiamondTo(
            user,                                                               // address _to,
            "gia",                                                              // bytes32 _issuer,
            "2141438167",                                                       // bytes32 _report,
            dpassOwnerPrice,                                                    // uint _ownerPrice,
            139 ether,                                                          // uint _marketplacePrice,
            "sale",                                                             // bytes32 _state,
            attributes,// bytes32[] memory _attributes,
            bytes32(uint(0xc0a5d062e13f99c8f70d19dc7993c2f34020a7031c17f29ce2550315879006d7)) // bytes32 _attributesHash
        ); 
        TrustedASMTester(asm).setPrice(dpass, dpassId[user], dpassOwnerPrice);
        CdcExchangeTester(user).doApprove721(dpass, exchange, dpassId[user]);

        dpassOwnerPrice = 151 ether;
        bytes32[] memory attributes1 = new bytes32[](5); 
        attributes1[0] = "round";
        attributes1[1] = "3.1";
        attributes1[2] = "F";
        attributes1[3] = "VVS1";
        attributes1[4] = "";

        dpassId[seller] = Dpass(dpass).mintDiamondTo(
            seller,                                                        // address _to,
            "gia",                                                              // bytes32 _issuer,
            "2141438168",                                                       // bytes32 _report,
            dpassOwnerPrice,                                                    // uint _ownerPrice,
            109 ether,                                                          // uint _marketplacePrice,
            "sale",                                                             // bytes32 _state,
            attributes,                                  // bytes32[] memory _attributes,
            bytes32(0xac5c1daab5131326b23d7f3a4b79bba9f236d227338c5b0fb17494defc319886)  // bytes32 _attributesHash
        ); 

        TrustedASMTester(asm).setPrice(dpass, dpassId[seller], dpassOwnerPrice);
        CdcExchangeTester(seller).doApprove721(dpass, exchange, dpassId[seller]);
        // Prepare seller of DPT fees
        
        user.transfer(INITIAL_BALANCE);
        Cdc(cdc).transfer(user, INITIAL_BALANCE);
        DSToken(dai).transfer(user, INITIAL_BALANCE);

        CdcExchangeTester(user).doApprove(dpt, exchange, uint(-1));
        CdcExchangeTester(user).doApprove(cdc, exchange, uint(-1));
        CdcExchangeTester(user).doApprove(dai, exchange, uint(-1));

        balance[address(this)][eth] = address(this).balance;
        balance[user][eth] = user.balance;
        balance[user][cdc] = Cdc(cdc).balanceOf(user);
        balance[user][dpt] = Cdc(dpt).balanceOf(user);
        balance[user][dai] = Cdc(dai).balanceOf(user);

        balance[asm][eth] = asm.balance;
        balance[asm][cdc] = Cdc(cdc).balanceOf(asm);
        balance[asm][dpt] = Cdc(dpt).balanceOf(asm);
        balance[asm][dai] = Cdc(dai).balanceOf(asm);

        balance[liquidityContract][eth] = liquidityContract.balance;
        balance[wal][eth] = wal.balance;
        balance[custodian20[eth]][eth] = custodian20[eth].balance;
        balance[custodian20[cdc]][cdc] = Cdc(cdc).balanceOf(custodian20[cdc]);
        balance[custodian20[dpt]][cdc] = DSToken(dpt).balanceOf(custodian20[dpt]);
        balance[custodian20[dai]][cdc] = DSToken(dai).balanceOf(custodian20[dai]);

        emit log_named_address("exchange", exchange);
        emit log_named_address("dpt", dpt);
        emit log_named_address("cdc", cdc);
        emit log_named_address("asm", asm);
        emit log_named_address("user", user);
        emit log_named_address("wal", wal);
        emit log_named_address("liq", liquidityContract);
        emit log_named_address("burner", burner);
    }
/*
    function doExchange(address sellToken, uint256 sellAmtOrId, address buyToken, uint256 buyAmtOrId) public {
        uint currentUserBalanceT;
        uint buyT;
        uint buyV;
        bool _takeProfitOnlyInDpt = CdcExchange(exchange).takeProfitOnlyInDpt();

        if (sellToken == eth) {
            currentUserBalanceT = user.balance;
        } else {
            currentUserBalanceT = DSToken(sellToken).balanceOf(user);
        }

        sentV = sellAmtOrId == uint(-1) ?                                               // sent value in fiat currency
            wmulV(currentUserBalanceT, usdRate[sellToken], sellToken) : 
            erc20[sellToken] ?
                wmulV(sellAmtOrId, usdRate[sellToken], sellToken) :
                TrustedASMTester(asm).getPrice(sellToken, sellAmtOrId);
        
        buyT = erc20[buyToken] ?                                                        // total amount of token available to buy (or tokenid)
            DSToken(buyToken).balanceOf(custodian20[buyToken]) :
            buyAmtOrId;
        
        buyV = erc20[buyToken] ?                                                        // total value of tokens available to buy (or tokenid)
            wmulV(buyT, usdRate[buyToken], buyToken) : 
            TrustedASMTester(asm).getPrice(buyToken, buyAmtOrId);

        buySellTokenT = erc20[sellToken] ?                                              // the amount of sellToken to pay for buy token
            wdivT(buyV, usdRate[sellToken], sellToken) :
            0;

        feeV = add(wmul(varFee, min(sentV, buyV)), fixFee);                             // fiat value in fiat

        feeDpt = wdivT(feeV, usdRate[dpt], dpt);                                        // the amount of DPT tokens to pay for fee

        feeSellTokenT = erc20[sellToken] ?                                              // amount of sell token to pay for fee
            wdivT(feeV, usdRate[sellToken], sellToken) :
            0;

        profitV = wmul(feeV, profitRate);                                               // value of total profit in fiat
        
        profitDpt = wdivT(profitV, usdRate[dpt], dpt);                                  // total amount of DPT to pay for profit

        feeSpentDpt = _takeProfitOnlyInDpt ? 
            min(userDpt, wdivT(profitV, usdRate[dpt], dpt)) :
            min(userDpt, wdivT(feeV, usdRate[dpt], dpt));

        uint feeSpentDptV = wmulV(feeSpentDpt, usdRate[dpt], dpt);
        
        profitSellTokenT = wdivT(profitV, usdRate[sellToken], sellToken);               // total amount of sellToken to pay for profit

        if (feeSpentDpt < feeDpt) {

            restOfFeeV = wmulV(sub(feeDpt, feeSpentDpt), usdRate[dpt], dpt);                // fee that remains after paying (part of) it with user DPT
            
            restOfFeeDpt = sub(feeDpt, feeSpentDpt);                                        // fee in DPT that remains after paying (part of) with DPT 
            
            restOfFeeT = erc20[sellToken] ? 
                wdivT(restOfFeeV, usdRate[sellToken], sellToken) : 
                0;                                                                      // amount of sellToken to pay for remaining fee
        }

        if (takeProfitOnlyInDpt) {

            expectedBalance = sub(                                                      // expected balance after tx has been made
                INITIAL_BALANCE, 
                userDpt < profitDpt ?
                    sub(profitDpt, userDpt) :
                    0);
        } else {

            expectedBalance = sub(
                INITIAL_BALANCE, 
                userDpt < feeDpt ?
                    sub(profitDpt, wmul(userDpt, profitRate)) :
                    0);
        }

        CdcExchangeTester(user).doBuyTokensWithFee(
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId
        );

        uint userDptV = wmulV(userDpt, usdRate[dpt], dpt);

        uint balanceUserIncreaseT = erc20[buyToken] ? 
            sub(
                (buyToken == eth ? 
                    user.balance :
                    DSToken(buyToken).balanceOf(user)),
                balance[user][buyToken]) : 
            0;

        uint balanceUserIncreaseV = erc20[buyToken] ? 
            wmulV(
                balanceUserIncreaseT,
                usdRate[buyToken],
                buyToken) :
            TrustedASMTester(asm).getPrice(buyToken, buyAmtOrId);

        uint balanceUserDecreaseT = erc20[sellToken] ? 
            sub(
                balance[user][sellToken],
                (sellToken == eth ? 
                    user.balance :
                    DSToken(sellToken).balanceOf(user))) : 
            0;

        uint balanceUserDecreaseV = erc20[sellToken] ? 
            wmulV(
                balanceUserDecreaseT,
                usdRate[sellToken],
                sellToken) :
            TrustedASMTester(asm).getPrice(sellToken, sellAmtOrId);

        emit log_named_uint("--------takeProfitOnlyInDpt", takeProfitOnlyInDpt ? 1 : 0);
        emit log_named_bytes32("---------------sellToken", getName(sellToken));
        logUint("---------sellAmtOrId", sellAmtOrId, 18);
        emit log_named_bytes32("----------------buyToken", getName(buyToken));
        logUint("----------buyAmtOrId", buyAmtOrId, 18);
        emit log_bytes32(bytes32("-----------------------------"));
        logUint("--------------sentV", sentV, 18);
        logUint("--------------buyV:", buyV, 18);
        logUint("-----buySellTokenT:", buySellTokenT, 18);
        logUint("--------feeV(total)", feeV, 18);
        logUint("------feeDpt(total)", feeDpt, 18);
        logUint("---------feeT(tot.)", feeSellTokenT, 18);
        logUint("------------userDpt", userDpt, 18);
        logUint("-----------userDptV", userDptV, 18);
        emit log_bytes32(bytes32("-----------------------------"));
        logUint("---------profitRate", profitRate, 18);
        logUint("------------profitV", profitV, 18);
        logUint("----------profitDpt", profitDpt, 18);
        logUint("------------profitT", profitSellTokenT, 18);
        logUint("--------feeSpentDpt", feeSpentDpt, 18);
        logUint("-------feeSpentDptV", feeSpentDptV, 18);
        logUint("---------restOfFeeV", restOfFeeV, 18);
        logUint("-------restOfFeeDpt", restOfFeeDpt, 18);
        logUint("---------restOfFeeT", restOfFeeT, 18);

        // DPT (eq fee in USD) must be sold from: liquidityContract balance
        assertEq(dpt.balanceOf(address(liquidityContract)), sub(INITIAL_BALANCE, sub(_takeProfitOnlyInDpt ? profitDpt : feeDpt, feeSpentDpt)));

        // ETH for DPT fee must be sent to wallet balance from user balance
        assertEq(address(wal).balance, add(balance[wal][sellToken], feeEth));    //TODO: finish this
        
        // DPT fee have to be transfered to burner
        assertEq(dpt.balanceOf(burner), profitDpt);

        // ETH (minus ETH for DPT fee) must be sent to owner balance from user balance
        if (erc20[sellToken]) {

            assertEq(
                currentUserBalanceT,                                                            // current user balance
                add(
                    balance[custodian20[sellToken]][sellToken],                                 // original balance
                    add(buySellTokenT, restOfFeeT)));                                           // amount of sell token that must be paid for buy token ...
                                                                                                // ... + value of sell token sent as fee
        } else {
            assertEq(
                TrustedASMTester(asm).getPrice(sellToken, sellAmtOrId),
                add(balanceUserIncreaseV, feeV));
        }

        // ETH on user balance
        if (erc20[buyToken]) {
            assertEq(
                sellToken == eth ?
                    user.balance : DSToken(buyToken).balanceOf(user),
                sub(
                    balance[custodian20[buyToken]][buyToken],
                    balanceUserDecreaseT));
        } else {
            
            assertEq(
                Dpass(buyToken).ownerOf(buyAmtOrId), 
                user);

            assertEq(
                add(TrustedASMTester(asm).getPrice(buyToken, buyAmtOrId), feeV),
                add(balanceUserDecreaseV, feeSpentDptV)); 
        }

        // CDC must be transfered to user
        assertEq(cdc.balanceOf(user), wdiv(sub(wmul(sentEth, ethUsdRate), fee), cdcUsdRate));
    }         
*/
    function getName(address token) public view returns (bytes32 name) {
        if (token == eth) {
            name = "eth";
        } else if (token == dpt) {
            name = "dpt";
        } else if (token == cdc) {
            name = "cdc";
        } else if (token == dai) {
            name = "dai";
        }  else if (token == eng) {
            name = "dai";
        } else if (token == dpass) {
            name = "dpass";
        } else if (token == dpass1) {
            name = "dpass1";
        }

    }
    
    function logUint(bytes32 what, uint256 num, uint256 dec) public {
        emit LogUintIpartUintFpart( what, num / 10 ** dec, num % 10 ** dec);
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wmul(toDecimals(a, getDecimals(token), 18), b);
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wdiv(a, toDecimals(b, 18, getDecimals(token)));
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public view returns (uint8) {
        require(decimalsSet[token_], "Token with unset decimals");
        return decimals[token_];
    }

    /**
    * @dev Adjusts a number from one precision to another
    */
    function toDecimals(uint256 amt_, uint8 srcDec_, uint8 dstDec_) public pure returns (uint256) {
        if (srcDec_ == dstDec_) return amt_;                                        // no change
        if (srcDec_ < dstDec_) return mul(amt_, 10 ** uint256(dstDec_ - srcDec_));  // add zeros to the right
        return amt_ / 10 ** uint256(srcDec_ - dstDec_);                             // remove digits 
    }    

    /**
    * @dev Convert address to bytes32
    * @param a address that is converted to bytes32
    * @return bytes32 conversion of address
    */
    function b32(address a) public pure returns (bytes32) {
        return bytes32(uint256(a) << 96);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a uint value to be converted
    * @return bytes32 converted value
    */
    function b32(uint a) public pure returns (bytes32) {
        return bytes32(a);
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a_ bool value to be converted
    * @return bytes32 converted value
    */
    function b32(bool a_) public pure returns (bytes32) {
        return bytes32(uint256(a_ ? 1 : 0));
    }

    function () external payable {
    }

    function testCalculateFee() public {
        uint valueV = 1 ether;

        uint expectedFeeV = add(fixFee, wmul(varFee, valueV));

        // By default fee should be equal to init value
        assertEq(CdcExchange(exchange).calculateFee(
            address(this),
            valueV,
            address(0x0),
            0,
            address(0x0),
            0
        ), expectedFeeV);
    }
    
    function testSetFixFee() public {
        uint fee = 0.1 ether;
        CdcExchange(exchange).setConfig("fixFee", fee, "");
        assertEq(CdcExchange(exchange).calculateFee(
            address(this),
            0 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarFee() public {
        uint fee = 0.5 ether;
        CdcExchange(exchange).setConfig("varFee", fee, "");
        assertEq(CdcExchange(exchange).calculateFee(
            address(this),
            1 ether,
            address(0x0),
            0,
            address(0x0),
            0
        ), fee);
    }

    function testSetVarAndFixFee() public {
        uint value = 1 ether;
        uint varFee1 = 0.5 ether;
        uint fixFee1 = uint(10) / uint(3) * 1 ether;
        CdcExchange(exchange).setConfig("varFee", varFee1, "");
        CdcExchange(exchange).setConfig("fixFee", fixFee1, "");
        assertEq(CdcExchange(exchange).calculateFee(
            address(this),
            value,
            address(0x0),
            0,
            address(0x0),
            0
        ), add(fixFee1, wmul(varFee1, value)));
    }

    function testFailNonOwnerSetVarFee() public {
        uint newFee = 0.1 ether;
        CdcExchangeTester(user).doSetConfig("varFee", newFee, "");
    }

    function testFailNonOwnerSetFixFee() public {
        uint newFee = 0.1 ether;
        CdcExchangeTester(user).doSetConfig("fixFee", newFee, "");
    }

    function testSetEthPriceFeed() public {
        address token = eth;
        uint rate = 1 ether;
        CdcExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate); 
        assertEq(CdcExchange(exchange).getRate(token), rate);
    }

    function testSetDptPriceFeed() public {
        address token = dpt;
        uint rate = 2 ether;
        CdcExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate); 
        assertEq(CdcExchange(exchange).getRate(token), rate);
    }

    function testSetCdcPriceFeed() public {
        address token = cdc;
        uint rate = 4 ether;
        CdcExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate); 
        assertEq(CdcExchange(exchange).getRate(token), rate);
    }

    function testSetDaiPriceFeed() public {
        address token = dai;
        uint rate = 5 ether;
        CdcExchange(exchange).setConfig("priceFeed", token, feed[dai]);
        TestFeedLike(feed[dai]).setRate(rate); 
        assertEq(CdcExchange(exchange).getRate(token), rate);
    }

    function testFailWrongAddressSetPriceFeed() public {
        address token = eth;
        CdcExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailNonOwnerSetEthPriceFeed() public {
        address token = eth;
        CdcExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testFailWrongAddressSetDptPriceFeed() public {
        address token = dpt;
        CdcExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailWrongAddressSetCdcPriceFeed() public {
        address token = cdc;
        CdcExchange(exchange).setConfig("priceFeed", token, address(0));
    }

    function testFailNonOwnerSetCdcPriceFeed() public {
        address token = cdc;
        CdcExchangeTester(user).doSetConfig("priceFeed", token, address(0));
    }

    function testSetLiquidityContract() public {
        DSToken(dpt).transfer(user, 100 ether);
        CdcExchange(exchange).setConfig("liq", user, "");
        assertEq(CdcExchange(exchange).liq(), user);
    }

    function testFailWrongAddressSetLiquidityContract() public {
        CdcExchange(exchange).setConfig("liq", address(0x0), "");
    }

    function testFailNonOwnerSetLiquidityContract() public {
        DSToken(dpt).transfer(user, 100 ether);
        CdcExchangeTester(user).doSetConfig("liq", user, "");
    }

    function testFailWrongAddressSetWalletContract() public {
        CdcExchange(exchange).setConfig("wal", address(0x0), "");
    }

    function testFailNonOwnerSetWalletContract() public {
        CdcExchangeTester(user).doSetConfig("wal", user, "");
    }

    function testSetManualDptRate() public {
        CdcExchange(exchange).setConfig("manualRate", dpt, true);
        assertTrue(CdcExchange(exchange).getManualRate(dpt));
        CdcExchange(exchange).setConfig("manualRate", dpt, false);
        assertTrue(!CdcExchange(exchange).getManualRate(dpt));
    }

    function testSetManualCdcRate() public {
        CdcExchange(exchange).setConfig("manualRate", cdc, true);
        assertTrue(CdcExchange(exchange).getManualRate(cdc));
        CdcExchange(exchange).setConfig("manualRate", cdc, false);
        assertTrue(!CdcExchange(exchange).getManualRate(cdc));
    }

    function testSetManualEthRate() public {
        CdcExchange(exchange).setConfig("manualRate", address(0xee), true);
        assertTrue(CdcExchange(exchange).getManualRate(address(0xee)));
        CdcExchange(exchange).setConfig("manualRate", address(0xee), false);
        assertTrue(!CdcExchange(exchange).getManualRate(address(0xee)));
    }

    function testSetManualDaiRate() public {
        CdcExchange(exchange).setConfig("manualRate", dai, true);
        assertTrue(CdcExchange(exchange).getManualRate(dai));
        CdcExchange(exchange).setConfig("manualRate", dai, false);
        assertTrue(!CdcExchange(exchange).getManualRate(dai));
    }
    
    function testFailNonOwnerSetManualDptRate() public {
        CdcExchangeTester(user).doSetConfig("manualRate", dpt, false);
    }

    function testFailNonOwnerSetManualCdcRate() public {
        CdcExchangeTester(user).doSetConfig("manualRate", cdc, false);
    }

    function testFailNonOwnerSetManualEthRate() public {
        CdcExchangeTester(user).doSetConfig("manualRate", address(0xee), false);
    }

    function testFailNonOwnerSetManualDaiRate() public {
        CdcExchangeTester(user).doSetConfig("manualRate", dai, false);
    }

    function testSetFeeCalculatorContract() public {
        CdcExchange(exchange).setConfig("fca", address(fca), "");
        assertEq(address(CdcExchange(exchange).fca()), address(fca));
    }

    function testFailWrongAddressSetCfo() public {
        CdcExchange(exchange).setConfig("fca", address(0), "");
    }

    function testFailNonOwnerSetCfo() public {
        CdcExchangeTester(user).doSetConfig("fca", user, "");
    }

    function testSetDptUsdRate() public {
        uint newRate = 5 ether;
        CdcExchange(exchange).setConfig("rate", dpt, newRate);
        assertEq(CdcExchange(exchange).getLocalRate(dpt), newRate);
    }

    function testFailIncorectRateSetDptUsdRate() public {
        CdcExchange(exchange).setConfig("rate", dpt, uint(0));
    }

    function testFailNonOwnerSetDptUsdRate() public {
        uint newRate = 5 ether;
        CdcExchangeTester(user).doSetConfig("rate", dpt, newRate);
    }

    function testSetCdcUsdRate() public {
        uint newRate = 5 ether;
        CdcExchange(exchange).setConfig("rate", cdc, newRate);
        assertEq(CdcExchange(exchange).getLocalRate(cdc), newRate);
    }

    function testFailIncorectRateSetCdcUsdRate() public {
        CdcExchange(exchange).setConfig("rate", cdc, uint(0));
    }

    function testFailNonOwnerSetCdcUsdRate() public {
        uint newRate = 5 ether;
        CdcExchangeTester(user).doSetConfig("rate", cdc, newRate);
    }

    function testSetEthUsdRate() public {
        uint newRate = 5 ether;
        CdcExchange(exchange).setConfig("rate", eth, newRate);
        assertEq(CdcExchange(exchange).getLocalRate(eth), newRate);
    }

    function testFailIncorectRateSetEthUsdRate() public {
        CdcExchange(exchange).setConfig("rate", eth, uint(0));
    }

    function testFailNonOwnerSetEthUsdRate() public {
        uint newRate = 5 ether;
        CdcExchangeTester(user).doSetConfig("rate", eth, newRate);
    }

    function testFailInvalidDptFeedAndManualDisabledBuyTokensWithFee() public logs_gas {
        uint sentEth = 1 ether;
       
        CdcExchange(exchange).setConfig("manualRate", dpt, false);
       
        TestFeedLike(feed[dpt]).setValid(false);
        
        CdcExchange(exchange).buyTokensWithFee(dpt, sentEth, cdc, uint(-1));
    }

    function testFailInvalidEthFeedAndManualDisabledBuyTokensWithFee() public logs_gas {
        uint sentEth = 1 ether;

        CdcExchange(exchange).setConfig("manualRate", eth, false);

        TestFeedLike(feed[eth]).setValid(false);
        
        CdcExchange(exchange).buyTokensWithFee.value(sentEth)(eth, sentEth, cdc, uint(-1));
    }

    function testFailInvalidCdcFeedAndManualDisabledBuyTokensWithFee() public {
        uint sentEth = 1 ether;

        CdcExchange(exchange).setConfig("manualRate", cdc, false);

        TestFeedLike(feed[cdc]).setValid(false);
        
        CdcExchange(exchange).buyTokensWithFee(cdc, sentEth, cdc, uint(-1));
    }
/*
    function testForFixEthBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixEthBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixEthBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuch() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuch() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address buyToken = cdc;

        doExchange(eth, 1000 ether, buyToken, 1001 ether); 
        
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuch() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailSendEthIfNoEthIsSellToken() public {
        uint sentEth = 1 ether;

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        CdcExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixDaiBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixDaiBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixDaiBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDaiBuyAllCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllDaiBuyAllCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDaiBuyAllCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDaiBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllDaiBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDaiBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixDaiBuyFixCdcUserHasNoDpt() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixDaiBuyFixCdcUserDptNotZeroNotEnough() public {
        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixDaiBuyFixCdcUserDptEnough() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptSellAmtTooMuch() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBuyAmtTooMuch() public {
        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;   // has only 1000 cdc balance

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testFailForFixDaiBuyFixCdcUserHasNoDptBothTooMuch() public {
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 1001 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 1001 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixEthBuyAllCdcUserHasNoDptAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 41 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 27 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyAllCdcUserHasNoDptAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllEthBuyAllCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyFixCdcUserHasNoDptAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForAllEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllEthBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixEthBuyFixCdcUserHasNoDptAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testForFixEthBuyFixCdcUserDptNotZeroNotEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixEthBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptSellAmtTooMuchAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 1001 ether;  // has only 1000 eth balance
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
        
    }

    function testAssertForTestFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt() public {

        // if this test fails, it is because in the test testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt ...
        // ... we do not actually buy too much, or the next test fails before the feature could be tested

        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        user.transfer(sellAmtOrId);
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBuyAmtTooMuchAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        uint buyAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // more than available
        uint sellAmtOrId = wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth);
        DSToken(eth).transfer(user, sellAmtOrId);

        doExchange(eth, sellAmtOrId, cdc, buyAmtOrId); 
    }

    function testFailForFixEthBuyFixCdcUserHasNoDptBothTooMuchAllFeeInDpt() public {

        userDpt = 123 ether; // this can be changed
        uint buyAmtOrId = INITIAL_BALANCE + 1 ether; // DO NOT CHANGE THIS!!!
        uint sellAmtOrId = DSToken(cdc).balanceOf(custodian20[cdc]) + 1 ether; // DO NOT CHANGE THIS!!!

        if (wdivT(wmulV(buyAmtOrId, usdRate[cdc], cdc), usdRate[eth], eth) <= sellAmtOrId) {
            DSToken(dpt).transfer(user, userDpt);

            doExchange(eth, sellAmtOrId, cdc, buyAmtOrId); 
        }
    }

    function testFailSendEthIfNoEthIsSellTokenAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        uint sentEth = 1 ether;

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 11 ether;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        CdcExchange(exchange).buyTokensWithFee.value(sentEth)(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixDptBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1000 ether;
        uint sellDpt = 10 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDptBuyAllCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1000 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = uint(-1);

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForAllDptBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1000 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testForFixDptBuyFixCdcUserDptEnoughAllFeeInDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");

        userDpt = 1000 ether;
        uint sellDpt = 10 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dpt;
        uint sellAmtOrId = sellDpt;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailBuyTokensWithFeeLiquidityContractHasInsufficientDpt() public {
        CdcExchangeTester(liquidityContract).doTransfer(dpt, address(this), INITIAL_BALANCE);
        assertEq(DSToken(dpt).balanceOf(liquidityContract), 0);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testBuyTokensWithFeeWithManualEthUsdRate() public {
        
        usdRate[eth] = 400 ether;
        CdcExchange(exchange).setConfig("rate", eth, usdRate[eth]);
        TestFeedLike(feed[eth]).setValid(false);

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testBuyTokensWithFeeWithManualDptUsdRate() public {
        
        usdRate[dpt] = 400 ether;
        CdcExchange(exchange).setConfig("rate", dpt, usdRate[dpt]);
        TestFeedLike(feed[dpt]).setValid(false);

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testBuyTokensWithFeeWithManualCdcUsdRate() public {
        
        usdRate[cdc] = 400 ether;
        CdcExchange(exchange).setConfig("rate", cdc, usdRate[cdc]);
        TestFeedLike(feed[cdc]).setValid(false);

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testBuyTokensWithFeeWithManualDaiUsdRate() public {
        
        usdRate[dai] = 400 ether;
        CdcExchange(exchange).setConfig("rate", dai, usdRate[dai]);
        TestFeedLike(feed[dai]).setValid(false);

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }

    function testFailBuyTokensWithFeeSendZeroEth() public {
        
        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, 0, buyToken, buyAmtOrId); 
    }

    function testBuyTokensWithFeeWhenFeeIsZero() public {

        CdcExchange(exchange).setConfig("fixFee", 0, "");
        CdcExchange(exchange).setConfig("varFee", 0, "");

        userDpt = 123 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 17 ether;
        address buyToken = cdc;
        uint buyAmtOrId = 47 ether;

        doExchange(sellToken, sellAmtOrId, buyToken, buyAmtOrId); 
    }
    
    function testUpdateRates() public {
        usdRate[cdc] = 40 ether;
        usdRate[dpt] = 12 ether;
        usdRate[eth] = 500 ether;
        usdRate[dai] = 500 ether;

        TestFeedLike(feed[cdc]).setRate(usdRate[cdc]);
        TestFeedLike(feed[dpt]).setRate(usdRate[dpt]);
        TestFeedLike(feed[eth]).setRate(usdRate[eth]);
        TestFeedLike(feed[dai]).setRate(usdRate[dai]);

        assertEq(CdcExchange(exchange).getRate(cdc), usdRate[cdc]);
        assertEq(CdcExchange(exchange).getRate(dpt), usdRate[dpt]);
        assertEq(CdcExchange(exchange).getRate(eth), usdRate[eth]);
        assertEq(CdcExchange(exchange).getRate(dai), usdRate[dai]);
    }

    function testForFixEthBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixEthBuyDpassUserDptNotEnough() public {

        userDpt = 5 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixEthBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 15.65 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 15.65 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserEthNotEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDptBuyDpass() public {


        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;                       

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, add(userDpt, sellAmtOrId));
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDptBuyDpassUserDptNotEnough() public {


        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;                       

        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, add(userDpt, sellAmtOrId));
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDptBuyDpass() public {

        userDpt = 0 ether;                                

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);                       

        DSToken(dpt).transfer(user, 500);
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserDptNotEnough() public {

        userDpt = 5 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.1 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDpassBuyDpass() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);


        doExchange(dpass, dpassId[user], dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }
    function testForFixDaiBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDaiBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDaiBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 25.1 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserDaiNotEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserBothNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassUserHasNoDpt() public {

        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassDptNotEnough() public {

        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassUserDptEnough() public {

        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }
//-------------------new--------------------------------------------------

    function testForFixEthBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(true), "", "");


        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 16.5 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }
    function testForFixEthBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");

        userDpt = 5 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 14.2 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixEthBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 6.4 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.73 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserEthNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixEthBuyDpassUserBothNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = 13.72 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllEthBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = eth;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDptBuyDpass() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");



        address sellToken = dpt;
        uint sellAmtOrId = 36.3 ether;                       

        userDpt = 0 ether;
        DSToken(dpt).transfer(user, add(userDpt, sellAmtOrId));
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDptBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");



        address sellToken = dpt;
        uint sellAmtOrId = 15.65 ether;                       

        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, add(userDpt, sellAmtOrId));
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDptBuyDpass() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;                                

        address sellToken = dpt;
        uint sellAmtOrId = uint(-1);                       

        DSToken(dpt).transfer(user, 500);
        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 5 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixCdcBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.89 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 25.1 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserCdcNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixCdcBuyDpassUserBothNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDpassBuyDpass() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);


        doExchange(dpass, dpassId[user], dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllCdcBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = cdc;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }
    function testForFixDaiBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                                 // the minimum value user has to pay

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDaiBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForFixDaiBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 13.94 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 25.1 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserDaiNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testFailForFixDaiBuyDpassUserBothNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = 10 ether;                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassUserHasNoDpt() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 0 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassDptNotEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }

    function testForAllDaiBuyDpassUserDptEnough() public {
        CdcExchange(exchange).setConfig("takeProfitOnlyInDpt", b32(false), "");


        userDpt = 1.812 ether;                                
        DSToken(dpt).transfer(user, userDpt);

        address sellToken = dai;
        uint sellAmtOrId = uint(-1);                       

        doExchange(sellToken, sellAmtOrId, dpass, dpassId[seller]); 
    }
    */
}
