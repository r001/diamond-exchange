pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";


/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract TrustedDSAuthority is DSAuthority {
    function stub() external;
}


/**
* @dev Contract to calculate user fee based on amount
*/
contract TrustedFeeCalculator {
    function calculateFee(
        address sender,
        uint256 value,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) external view returns (uint);
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
    function getAmtForSale(TrustedErc20 token) external view returns(uint256);
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


/**
 * @title Cdc
 * @dev Cdc Exchange contract.
 */
contract CdcExchangeEvents {
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

    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);
}

// TODO: wallet functionality, proxy Contracts
contract CdcExchange is DSAuth, DSStop, DSMath, CdcExchangeEvents {
    TrustedDsToken public cdc;                              // CDC token contract
    address public dpt;                                     // DPT token contract
    TrustedErc721 public dpass;                             // DPASS default token address

    mapping(address => uint256) private rate;               // exchange rate for a token
    mapping(address => bool) public manualRate;             // manualRate is allowed for a token (if feed invalid)
    mapping(address => TrustedFeedLike) public priceFeed;   // price feed address for token
    mapping(address => bool) public canBuyErc20;            // stores allowed ERC20 tokens to buy
    mapping(address => bool) public canSellErc20;           // stores allowed ERC20 tokens to sell
    mapping(address => bool) public canBuyErc721;           // stores allowed ERC20 tokens to buy
    mapping(address => bool) public canSellErc721;          // stores allowed ERC20 tokens to sell
    mapping(address => uint8) public decimals;              // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores if decimals were set for ERC20 token
    mapping(address => address) public custodian20;         // custodian that holds an ERC20 token for Exchange
    mapping(address => bool) public handledByAsm;           // defines if token is managed by Asset Management

    TrustedFeeCalculator public fca;        // fee calculator contract

    address public liq;                     // contract providing DPT liquidity to pay for fee
    address payable public wal;             // wallet address, where we keep all the tokens we received as fee
    address payable public burner;          // contract where accured fee of DPT is stored before being burned
    TrustedAssetManagement public asm;      // Asset Management contract
    uint256 public fixFee;                  // Fixed part of fee charged for buying 18 decimals precision in base currency
    uint256 public varFee;                  // Variable part of fee charged for buying 18 decimals precision in base currency
    uint256 public profitRate;              // the percentage of profit that is burned on all fees received. 18 decimals precision
    uint256 public callGas = 2500;          // using this much gas when Ether is transferred
    uint256 public txId;                    // Unique id of each transaction.
    bool public takeProfitOnlyInDpt = true; // If true, it takes cost + profit in DPT, if false only profit in DPT
    uint256 public dust = 10000;            // Numbers below this amount are considered 0. Can only be used ...
                                            // ... along with 18 decimal precisions numbers.
    bool locked;                            // protect against reentrancy attacks
    address eth = address(0xee);            // to handle ether the same way as tokens we associate a fake address to it

    constructor(
        address cdc_,
        address dpt_,
        address dpass_,
        address ethPriceFeed_,
        address dptPriceFeed_,
        address cdcPriceFeed_,
        address liq_,
        address burner_,
        address asm_,
        uint fixFee_,
        uint varFee_,
        uint profitRate_,
        address wal_
    ) public {

    // default exchage rates must be set manually as constructor can not set more variables

        setConfig("canSellErc20", dpt_, true);
        setConfig("canBuyErc20", dpt_, true);
        setConfig("canSellErc20", cdc_, true);
        setConfig("canBuyErc20", cdc_, true);
        setConfig("canSellErc20", eth, true);
        setConfig("canBuyErc721", dpass_, true);
        setConfig("canSellErc721", dpass_, true);
        setConfig("decimals", dpt_, 18);
        setConfig("decimals", cdc_, 18);
        setConfig("decimals", eth, 18);
        setConfig("dpt", dpt_, "");
        setConfig("cdc", cdc_, "");
        setConfig("dpass", dpass_, "");
        setConfig("handledByAsm", cdc_, true);
        setConfig("handledByAsm", dpass_, true);
        setConfig("priceFeed", dpt_, dptPriceFeed_);
        setConfig("priceFeed", eth, ethPriceFeed_);
        setConfig("priceFeed", cdc_, cdcPriceFeed_);
        setConfig("liq", liq_, "");
        setConfig("burner", burner_, "");
        setConfig("asm", asm_, "");
        setConfig("fixFee", fixFee_, "");
        setConfig("varFee", varFee_, "");
        setConfig("profitRate", profitRate_, "");
        setConfig("wal", wal_, "");
    }

    modifier nonReentrant {
        require(!locked, "Reentrancy detected.");
        locked = true;
        _;
        locked = false;
    }

    /**
    * @dev Fallback function to buy tokens.
    */
    function () external payable {
        buyTokensWithFee(eth, msg.value, address(cdc), uint(-1));
    }

    /**
    * @dev Тoken purchase with fee. (If user has DPT he must approve this contract,
    * otherwise transaction will fail.)
    */
    function buyTokensWithFee (
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) public payable stoppable nonReentrant {
        uint buyV;
        uint sellV;
        uint feeV;
        uint sellT;
        uint buyT;

        updateRates(sellToken, buyToken);               // update currency rates

        (buyV, sellV) = getValues(                      // calculate highest possible buy and sell values (here they might not match)
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId);

        feeV = calculateFee(                            // calculate fee user has to pay for exchange
            msg.sender,
            min(buyV, sellV),
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId);

            emit LogTest("buyV");
            emit LogTest(buyV);
            emit LogTest("sellV");
            emit LogTest(sellV);
        (sellT, buyT) = takeFee(                        // takes the calculated fee from user in DPT or sellToken ...
            feeV,                                       // ... calculates final sell and buy values (in base currency)
            sellV,
            buyV,
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId);

            emit LogTest("msg.sender.balance");
            emit LogTest(msg.value);
        transferTokens(                                 // transfers tokens to user and seller
            sellT,
            buyT,
            sellToken,
            sellAmtOrId,
            buyToken,
            buyAmtOrId,
            feeV);
    }

    function setConfig(bytes32 what_, address value_, address value1_) public auth { setConfig(what_, b32(value_), b32(value1_)); }
    function setConfig(bytes32 what_, address value_, bytes32 value1_) public auth { setConfig(what_, b32(value_), value1_); }
    function setConfig(bytes32 what_, address value_, uint256 value1_) public auth { setConfig(what_, b32(value_), b32(value1_)); }
    function setConfig(bytes32 what_, uint256 value_, address value1_) public auth { setConfig(what_, b32(value_), b32(value1_)); }
    function setConfig(bytes32 what_, uint256 value_, bytes32 value1_) public auth { setConfig(what_, b32(value_), value1_); }
    function setConfig(bytes32 what_, uint256 value_, uint256 value1_) public auth { setConfig(what_, b32(value_), b32(value1_)); }
    function setConfig(bytes32 what_, address value_, bool value1_) public auth { setConfig(what_, b32(value_), b32(value1_)); }

    /**
    * @dev Set configuration values for contract
    */
    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public auth {
        if (what_ == "profitRate") {

            profitRate = uint256(value_);

            require(profitRate <= 10 ** 18, "Profit rate out of range");

        } else if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);

            require(
                canSellErc20[token] ||
                canBuyErc20[token],
                "Token not allowed rate");

            require(value > 0, "Rate must be greater than 0");

            rate[token] = value;

        } else if (what_ == "fixFee") {

            fixFee = uint256(value_);

        } else if (what_ == "varFee") {

            varFee = uint256(value_);

        } else if (what_ == "manualRate") {

            address token = addr(value_);

            require(
                canSellErc20[token] ||
                canBuyErc20[token],
                "Token not allowed manualRate");

            manualRate[token] = uint256(value1_) > 0;

        } else if (what_ == "priceFeed") {

            require(canSellErc20[addr(value_)] || canBuyErc20[addr(value_)], "Token not allowed priceFeed");

            require(addr(value1_) != address(address(0x0)), "Wrong PriceFeed address");

            priceFeed[addr(value_)] = TrustedFeedLike(addr(value1_));

        } else if (what_ == "fixFee") {

            fixFee = uint256(value_);

        } else if (what_ == "varFee") {

            varFee = uint256(value_);

        } else if (what_ == "takeProfitOnlyInDpt") {

            takeProfitOnlyInDpt = uint256(value_) > 0;

        } else if (what_ == "liq") {

            liq = addr(value_);

            require(liq != address(0x0), "Wrong address");

            require(TrustedErc20(dpt).balanceOf(liq) > 0,
                    "Insufficient funds of DPT");

        } else if (what_ == "handledByAsm") {

            address token = addr(value_);

            require(canBuyErc20[token] || canBuyErc721[token], "Token not allowed (handledByAsm)");

            handledByAsm[token] = uint256(value1_) > 0;

        } else if (what_ == "asm") {

            require(addr(value_) != address(0x0), "Wrong address");

            asm = TrustedAssetManagement(addr(value_));

        } else if (what_ == "burner") {

            require(addr(value_) != address(0x0), "Wrong address");

            burner = address(uint160(addr(value_)));

        } else if (what_ == "cdc") {

            require(addr(value_) != address(0x0), "Wrong address");

            cdc = TrustedDsToken(addr(value_));

        } else if (what_ == "fca") {

            require(addr(value_) != address(0x0), "Wrong address");

            fca = TrustedFeeCalculator(addr(value_));

        } else if (what_ == "custodian20") {

            require(addr(value_) != address(0x0), "Wrong address");

            custodian20[addr(value_)] = addr(value1_);

        } else if (what_ == "decimals") {

            require(addr(value_) != address(0x0), "Wrong address");

            decimals[addr(value_)] = uint8(uint256(value1_));

            decimalsSet[addr(value_)] = true;

        } else if (what_ == "wal") {

            require(addr(value_) != address(0x0), "Wrong address");

            wal = address(uint160(addr(value_)));

        } else if (what_ == "callGas") {

            callGas = uint256(value_);

        } else if (what_ == "dust") {

            dust = uint256(value_);

        } else if (what_ == "canBuyErc20") {

            require(addr(value_) != address(0x0), "Wrong address");

            canBuyErc20[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canSellErc20") {

            require(addr(value_) != address(0x0), "Wrong address");

            canSellErc20[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canBuyErc721") {

            require(addr(value_) != address(0x0), "Wrong address");

            canBuyErc721[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "canSellErc721") {

            require(addr(value_) != address(0x0), "Wrong address");

            canSellErc721[addr(value_)] = uint(value1_) > 0;

        } else if (what_ == "dpass") {

            require(addr(value_) != address(0x0), "Wrong address");

            dpass = TrustedErc721(addr(value_));

        } else if (what_ == "dpt") {

            require(addr(value_) != address(0x0), "Wrong address");

            dpt = addr(value_);

        } else if (what_ == "owner") {

            require(addr(value_) != address(0x0), "Wrong address");

            setOwner(addr(value_));

        } else if (what_ == "authority") {

            require(addr(value_) != address(0x0), "Wrong address");

            setAuthority(TrustedDSAuthority(addr(value_)));

        } else {

            require(false, "No such option");
        }

        emit LogConfigChange(what_, value_, value1_);
    }

    /**
    * @dev Get exchange rate in base currency
    */
    function getLocalRate(address token) public view auth returns(uint256) {
        return rate[token];
    }

    /**
    * @dev Get manual rate. If manual rate for token is set to true then if rate feed returns invalid data, still a manually set rate can be used.
    */
    function getManualRate(address token) public view returns(bool) {
        return manualRate[token];
    }

    /**
    * @dev Get price feed address for token.
    */
    function getPriceFeed(address token) public view returns(TrustedFeedLike) {
        return priceFeed[token];
    }

    /**
    * @dev Return true if token is allowed to exchange.
    * @param token the token addres in question
    * @param buy if true we ask if user can buy the token from exchange, otherwise if user can sell to exchange
    * @param erc20 if token is an erc20 token, otherwise if it is an erc721 token
    */
    function getAllowedToken(address token, bool buy, bool erc20) public view auth returns(bool) {
        if (buy) {
            return erc20 ? canBuyErc20[token] : canBuyErc721[token];
        } else {
            return erc20 ? canSellErc20[token] : canSellErc721[token];
        }
    }

    /**
    * @dev Return true if the decimals for token has been set by contract owner.
    */
    function getDecimalsSet(address token) public view returns(bool) {
        return decimalsSet[token];
    }

    /**
    * @dev Get the custodian of ERC20 token.
    */
    function getCustodian20(address token) public view returns(address) {
        return custodian20[token];
    }

    /**
    * @dev Convert address to bytes32
    * @param a_ address that is converted to bytes32
    * @return bytes32 conversion of address
    */
    function b32(address a_) public pure returns (bytes32) {
        return bytes32(uint256(a_));
    }

    /**
    * @dev Convert uint256 to bytes32
    * @param a_ uint value to be converted
    * @return bytes32 converted value
    */
    function b32(uint256 a_) public pure returns (bytes32) {
        return bytes32(a_);
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
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
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
    * @dev Calculate fee locally or using an external smart contract
    * @return the fee amount in USD
    */
    function calculateFee(
        address sender_,
        uint256 value_,
        address sellToken_,
        uint256 sellAmtOrId_,
        address buyToken_,
        uint256 buyAmtOrId_
    ) public view returns (uint256) {

        if (fca == TrustedFeeCalculator(0)) {

            return fixFee + wmul(varFee, value_);                        // calculate proportional fee locally

        } else {

            return fca.calculateFee(                                    // calculate fee using external smart contract
                sender_,
                value_,
                sellToken_,
                sellAmtOrId_,
                buyToken_,
                buyAmtOrId_);
        }
    }

    function getRate(address token) public view auth returns (uint) {
        return getNewRate(token);
    }

    /**
    * @dev Get token_ / quote_currency rate from priceFeed
    * Revert transaction if not valid feed and manual value not allowed
    */
    function getNewRate(address token_) private view returns (uint rate_) {
        bool feedValid;
        bytes32 usdRateBytes;

        require(
            TrustedFeedLike(address(0x0)) != priceFeed[token_],         // require token to have a price feed
            "No price feed for token");

        (usdRateBytes, feedValid) = priceFeed[token_].peek();           // receive DPT/USD price

        if (feedValid) {                                                // if feed is valid, load DPT/USD rate from it

            rate_ = uint(usdRateBytes);

        } else {

            require(manualRate[token_], "Manual rate not allowed");     // if feed invalid revert if manualEthRate is NOT allowed

            rate_ = rate[token_];
        }
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

    //
    // internal functions
    //

    function updateRates(address sellToken, address buyToken) internal {
        if (canSellErc20[sellToken]) updateRate(sellToken);
        if (canBuyErc20[buyToken]) updateRate(buyToken);
        updateRate(dpt);
    }

    /**
    * @dev Get sell and buy token values in base currency
    */
    function getValues(
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    ) internal returns (uint256 buyV, uint256 sellV) {
        uint sellAmtT = sellAmtOrId;
        uint buyAmtT = buyAmtOrId;
        uint maxT;

        require(buyToken != eth, "We don't sell Ether");                // we can not sell Ether with this smart contract currently
        require(sellToken == eth || msg.value == 0,                     // we don't accept ETH if user wants to sell other token
                "Really want to send Ether?");

        if (canSellErc20[sellToken]) {                                  // if sellToken is a valid ERC20 token

            maxT = sellToken == eth ?
                msg.value :
                min(
                    TrustedErc20(sellToken).balanceOf(msg.sender),
                    TrustedErc20(sellToken).allowance(
                        msg.sender, address(this)));

            require(maxT > 0, "Please approve us.");

            require(
                sellToken == eth ||                                     // disregard Ether
                sellAmtOrId == uint(-1) ||                              // disregard uint(-1) as it has a special meaning
                sellAmtOrId <= maxT,                                    // sellAmtOrId should be less then sellToken available to this contract
                "Sell amount exceeds allowance");

            require(
                sellToken != eth ||                                     // regard Ether only
                sellAmtOrId == uint(-1) ||                              // disregard uint(-1) as it has a special meaning
                sellAmtOrId <= msg.value,                               // sellAmtOrId sold should be less than the Ether we received from user
                "Sell amount exceeds Ether value");

            if (sellAmtT == uint(-1)) {                                 // if user wants to sell maxTimum possible

                sellAmtT = maxT;
            }

            sellV = wmulV(sellAmtT, rate[sellToken], sellToken);        // sell value in base currency

        } else if (canSellErc721[sellToken]) {                          // if sellToken is a valid ERC721 token

            sellV = asm.getPrice(TrustedErc721(buyToken), sellAmtOrId); // get price from Asset Management

        } else {

            require(false, "Token not allowed to be sold");

        }

        if (canBuyErc20[buyToken]) {                                    // if buyToken is a valid ERC20 token

            maxT = handledByAsm[buyToken] ?                             // set buy amount to maxT possible
                asm.getAmtForSale(TrustedErc20(buyToken)) :             // if managed by asset management get available
                min(                                                    // if not managed by asset management get maxT available
                    TrustedErc20(buyToken).balanceOf(
                        custodian20[buyToken]),
                    TrustedErc20(buyToken).allowance(
                        custodian20[buyToken], address(this)));

            require(maxT > 0, "0 token is for sale");

            require(                                                    // require token's buy amount to be less or equal than avaulable to us
                sellToken == eth ||                                     // disregard Ether
                buyAmtOrId == uint(-1) ||                               // disregard uint(-1) as it has a special meaning
                buyAmtOrId <= maxT,                                     // amount must be less or equal that maxT available
                "Buy amount exceeds allowance");

            if (buyAmtOrId == uint(-1)) {                               // user wants to buy the maxTimum possible

                buyAmtT = maxT;
            }

            buyV = wmulV(buyAmtT, rate[buyToken], buyToken);            // final buy value in base currency

        } else if (canBuyErc721[buyToken]) {                            // if buyToken is a valid ERC721 token

            require(canSellErc20[sellToken],                            // require that at least one of sell and buy token is ERC20
                    "One of tokens must be erc20");

            buyV = asm.getPrice(                                        // calculate price with Asset Management contract
                TrustedErc721(buyToken),
                buyAmtOrId);

        } else {
            require(false, "Token not allowed to be bought");           // token can not be bought here
        }

    }

    /**
    * @dev Transfer sellToken from user and buyToken to user
    */
    function transferTokens(
        uint256 sellT,                                                  // sell token amount
        uint256 buyT,                                                   // buy token amount
        address sellToken,                                              // token sold by user
        uint256 sellAmtOrId,                                            // sell amount or sell token id
        address buyToken,                                               // token bought by user
        uint256 buyAmtOrId,                                             // buy amount or buy id
        uint256 feeV                                                    // value of total fees in base currency
    ) internal {

        if (canSellErc20[sellToken]) {                                  // if sellToken is a valid ERC20 token

            sendToken(                                                  // send token or Ether from user to custodian
                sellToken,
                msg.sender,
                address(uint160(custodian20[sellToken])),
                sellT);
            emit LogTest("msg.sender.balance");
            emit LogTest(msg.sender.balance);

            asm.notifyTransferFrom(                                     // notify Asset Management contract about transfer
                sellToken,
                msg.sender,
                custodian20[sellToken],
                sellT);

        }  else {                                                       // if sellToken is a valid ERC721 token

            TrustedErc721(sellToken)                                    // transfer ERC721 token from user to custodian
            .transferFrom(
                msg.sender,
                TrustedErc721(sellToken).ownerOf(sellAmtOrId),
                sellAmtOrId);

            asm.notifyTransferFrom(                                     // notify Asset Management contract about transfer
                sellToken,
                msg.sender,
                TrustedErc721(sellToken).ownerOf(sellAmtOrId),
                sellAmtOrId);

            sellT = sellAmtOrId;
        }

        if (canBuyErc20[buyToken]) {                                    // if buyToken is a valid ERC20 token

            if (handledByAsm[buyToken]) {                               // if token belongs to Asset Management

                asm.sendToken(buyToken, msg.sender, buyT);           // send token from Asset Management to user

            } else {

                sendToken(buyToken, custodian20[buyToken],              // send buyToken from custodian to user
                              msg.sender, buyT);
            }

        }  else {                                                       // if buyToken is a valid ERC721 token

            TrustedErc721(buyToken)                                     // transfer buyToken from custodian20 to user
            .transferFrom(
                TrustedErc721(buyToken).ownerOf(buyAmtOrId),
                msg.sender,
                buyAmtOrId);

            asm.notifyTransferFrom(                                     // notify Asset management about the transfer
                buyToken,
                TrustedErc721(buyToken).ownerOf(buyAmtOrId),
                msg.sender,
                buyAmtOrId);

        }

        logTrade(sellToken, sellT, buyToken, buyT, buyAmtOrId, feeV);
    }

    /*
    * @dev log the trade event
    */
    function logTrade(
        address sellToken,
        uint256 sellT,
        address buyToken,
        uint256 buyT,
        uint256 buyAmtOrId,
        uint256 fee
    ) internal {

        address custodian = canBuyErc20[buyToken] ?
            custodian20[buyToken] :
            TrustedErc721(buyToken).ownerOf(buyAmtOrId);

        txId++;

        emit LogBuyTokenWithFee(
            txId,
            msg.sender,
            custodian,
            sellToken,
            sellT,
            buyToken,
            buyT,
            fee);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function updateRate(address token) internal returns (uint256 rate_) {
        require((rate_ = getNewRate(token)) > 0, "updateRate: rate must be > 0");
        rate[token] = rate_;
    }

    /**
    * @dev Taking fee from user. If user has DPT takes it, if there is none buys it for user.
    * @return the amount of remaining ETH after buying fee if it was required
    */
    function takeFee(
        uint256 fee,
        uint256 sellV,
        uint256 buyV,
        address sellToken,
        uint256 sellAmtOrId,
        address buyToken,
        uint256 buyAmtOrId
    )
    internal
    returns(uint256 sellT, uint256 buyT) {
        uint feeTakenV;
        uint amtT;
        address token;
        address src;
        uint restFeeV;

        feeTakenV = sellToken != dpt ?                      // if sellToken is not dpt then try to take fee in DPT
            takeFeeInDptFromUser(fee) :
            0;

        if (fee - feeTakenV > dust                          // if we could not take all fees from user in ...
            && fee - feeTakenV <= fee) {                    // ... DPT (with round-off errors considered)

            emit LogTest("fee");
            emit LogTest(fee);
            restFeeV = sub(fee, feeTakenV);

            if (canSellErc20[sellToken]) {

                require(
                    canBuyErc20[buyToken] ||                // apply rule below to ERC721 buyTokens only
                    sellV + dust >=                         // for erc721 buy tokens the sellValue must be buyValue plus restFeeV
                        buyV + restFeeV,
                    "Not enough user funds to sell");

                token = sellToken;                          // fees are sent in this token
                src = msg.sender;                           // owner of token is sender
                amtT = sellAmtOrId;                         // max amount user wants to sell

                if (add(sellV, dust) <                      // if buy value is too big
                    add(buyV, restFeeV)) {

                    buyV = sub(sellV, restFeeV);            // buyValue is adjusted
                }

                sellV = buyV;                               // reduce sellValue to buyValue plus restFeeV

            } else if (canBuyErc20[buyToken]) {             // if sellToken is an ERC721 token and buyToken is an ERC20 token

                require(
                    sellV <= buyV + restFeeV + dust,        // check if user can be supplied with enough buy tokens
                    "Not enough tokens to buy");


                token = buyToken;                           // fees are paid in buy token

                src = custodian20[token];                   // source of funds is custodian

                amtT = buyAmtOrId;                          // max amount the user intended to buy

                if (sellV <= add(add(buyV, restFeeV), dust))

                    buyV = sub(sellV, restFeeV);

            } else {

                require(false, "No token to get fee from"); // not allowed to have both buy and sell tokens to be ERC721

            }

            assert(                                         // buy value must be less or equal to sell value
                token != buyToken ||
                sub(buyV, restFeeV) <= add(sellV, dust));

            assert(                                         // buy value must be less or equal to sell value
                token != sellToken ||
                buyV <= add(sellV, dust));

            takeFeeInToken(                              // send profit and costs in sellToken
                restFeeV,
                feeTakenV,
                token,
                src,
                amtT);

        } else {                                            // no fee must be payed with sellToken

            require(buyV <= sellV || canBuyErc20[buyToken], "Not enough funds.");

            require(buyV >= sellV || canSellErc20[sellToken], "Not enough tokens to buy.");

            sellV = min(buyV, sellV);

            buyV = sellV;
        }

        sellT = canSellErc20[sellToken] ?
            wdivT(sellV, rate[sellToken], sellToken) :
            sellAmtOrId;   // calculate token amount to be sold

        buyT = canBuyErc20[buyToken] ?
            wdivT(buyV, rate[buyToken], buyToken) :
            buyAmtOrId;

        if (sellToken == eth) {                             // send unused Ether back to user

            amtT = wdivT(
                restFeeV,
                rate[sellToken],
                sellToken);

            sendToken(
                eth,
                address(this),
                msg.sender,
                sub(msg.value, add(sellT, amtT)));
        }

    }

    /**
    * @dev Calculate and send profit and cost
    */
    function takeFeeInToken(
        uint256 fee,                                            // fee that user still owes to CDiamondCoin after paying fee in DPT
        uint256 feeTaken,                                       // fee already taken from user in DPT
        address token,                                          // token that must be sent as fee
        address src,                                            // source of token sent
        uint256 amountToken                                     // total amount of tokens the user wanted to pay initially
    ) internal {
        uint profitV;
        uint profitDpt;
        uint feeT;
        uint profitPaidV;
        uint totalProfitV;

        totalProfitV = wmul(add(fee, feeTaken), profitRate);

        profitPaidV = takeProfitOnlyInDpt ?                     // profit value paid already in base currency
            feeTaken :
            wmul(feeTaken, profitRate);

        profitV = sub(totalProfitV, profitPaidV);               // profit value still to be paid in base currency

        profitDpt = wdivT(profitV, rate[dpt], dpt);             // profit in DPT still to be paid

        feeT = wdivT(fee, rate[token], token);                 // convert fee from base currency to token amount

        require(
            feeT < amountToken,                                // require that the cost we pay is less than user intended to pay
            "Not enough token to pay fee");

        if (token == dpt) {
            sendToken(dpt, src, burner, profitDpt);

            emit LogTest("sub(feeT, profitDpt)");
            emit LogTest(sub(feeT, profitDpt));
            sendToken(dpt, src, wal, sub(feeT, profitDpt));

        } else {
            emit LogTest("fee");
            emit LogTest(fee);
            emit LogTest("feeT");
            emit LogTest(feeT);
            emit LogTest("totalProfitV");
            emit LogTest(totalProfitV);
            emit LogTest("profitPaidV");
            emit LogTest(profitPaidV);
            emit LogTest("profitV");
            emit LogTest(profitV);
            emit LogTest("profitDpt");
            emit LogTest(profitDpt);

            sendToken(dpt, liq, burner, profitDpt);                 // send profit to burner

            sendToken(token, src, wal, feeT);                      // send user token to wallet
        }
    }

    /**
    * @dev Take fee in DPT from user if it has any
    * @param fee the fee amount in base currency
    * @return the remaining fee amount in DPT
    */
    function takeFeeInDptFromUser(
        uint256 fee                                                 // total fee to be paid
    ) internal returns(uint256 feeTaken) {
        TrustedErc20 dpt20 = TrustedErc20(dpt);
        uint profitDpt;
        uint costDpt;
        uint feeTakenDpt;

        uint dptUser = min(
            dpt20.balanceOf(msg.sender),
            dpt20.allowance(msg.sender, address(this))
        );

        if (dptUser == 0) return 0;

        uint feeDpt = wdivT(fee, rate[dpt], dpt);                   // fee in DPT

        uint minDpt = min(feeDpt, dptUser);                         // get the maximum possible fee amount


        if (minDpt > 0) {

            if (takeProfitOnlyInDpt) {                              // only profit is paid in dpt

                profitDpt = min(wmul(feeDpt, profitRate), minDpt);

                sendToken(dpt, msg.sender, burner, profitDpt);      // only profit is put to the burner

            } else {

                profitDpt = wmul(minDpt, profitRate);

                sendToken(dpt, msg.sender, burner, profitDpt);      // send profit to burner

                costDpt = sub(minDpt, profitDpt);

                sendToken(dpt, msg.sender, wal, costDpt);           // send cost
            }

            feeTakenDpt = add(profitDpt, costDpt);                  // total fee taken in DPT

            feeTaken = wmulV(feeTakenDpt, rate[dpt], dpt);          // total fee taken in base currency value
        }

    }

    /**
    * &dev send token or ether to destination
    */
    function sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns(uint256 etherSpent) {
        TrustedErc20 erc20 = TrustedErc20(token);

        if (token == eth && amount > dust) {                        // if token is Ether and amount is higher than dust limit

            // TODO: do it with call.value() to use gas as needed
            dst.transfer(amount);

            emit LogTransferEth(src, dst, amount);

            etherSpent = amount;                                    // let caller know how much ether was spent

        } else {

            if (amount > 0) erc20.transferFrom(src, dst, amount);   // transfer all of token to dst
        }
    }
}

// TODO: remark formatting to align all
