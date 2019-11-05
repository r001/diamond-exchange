pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";
import "dpass/Dpass.sol";
import "./Wallet.sol";


/**
* @dev Contract to get ETH/USD price
*/
contract TrustedFeedLike {
    function peek() external view returns (bytes32, bool);
}


contract SimpleAssetManagement is DSAuth, DSStop, DSMath, Wallet {
    event LogConfigChange(address sender, bytes32 what, bytes32 value, bytes32 value1);
    mapping(address => mapping(uint => uint)) 
        private basePrice;                                  // the base price used for collateral valuation
    mapping(address => bool) custodians;                    // returns true for custodians
    mapping(address => uint)                                // total base currency value of custodians collaterals
        public totalDpassCustV;
    mapping(address => uint) private rate;                  // current rate of a token in base currency
    mapping(address => uint) public cdcValues;              // base currency value of cdc token
    mapping(address => uint) public dcdcValues;             // base currency value of dcdc token
    mapping(address => uint) public totalDcdcCustV;         // total value of all dcdcs at custodian
    mapping(
        address => mapping(
            address => uint)) public dcdcCustV;             // dcdcCustV[dcdc][custodian] value of dcdc at custodian
    mapping(address => bool) payTokens;                     // returns true for tokens allowed to make payment to custodians with
    mapping(address => bool) dpasses;                       // returns true for dpass tokens allowed in this contract
    mapping(address => bool) dcdcs;                         // returns true for tokens representing cdc assets (without gia number) that are allowed in this contract
    mapping(address => bool) cdcs;                          // returns true for cdc tokens allowed in this contract
    mapping(address => uint) public decimals;               // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores decimals for each ERC20 token
    mapping(address => address) public priceFeed;           // price feed address for token
    mapping(address => uint) public tokenPurchaseRate;      // the average purchase rate of a token. This is the ...
                                                            // ... price of token at which we send it to custodian
    mapping(address => uint) public totalPaidV;             // total amount that has been paid to custodian for dpasses and cdc in base currency
    mapping(address => bool) public manualRate;             // if manual rate is enabled then owner can update rates if feed not available

    uint public totalDpassV;                                // total value of dpass collaterals in base currency
    uint public totalDcdcV;                                 // total value of dcdc collaterals in base currency
    uint public totalCdcV;                                  // total value of cdc tokens issued in base currency
    uint public overCollRatio = 1.1 ether;                  // the totalDpassV >= overCollRatio * totalCdcV
    uint public dust = 1000;                                // dust value is the largest value we still consider 0 ...
    bool public locked;                                     // variable prevents to exploit by recursively calling funcions
    address public currDcdc;                                // the current dcdc token to update the price for

    modifier nonReentrant {
        require(!locked, "asm-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_) public nonReentrant auth {
        if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);
            require(payTokens[token] || cdcs[token] || dcdcs[token], "Token not allowed rate");
            require(value > 0, "Rate must be greater than 0");
            rate[token] = value;
        } else if (what_ == "dpasses") {
            address dpass = addr(value_);
            require(dpass != address(0), "asm-dpass-address-zero");
            dpasses[dpass] = uint(value1_) > 0;
        } else if (what_ == "dcdcs") {
            address newDcdc = addr(value_);
            require(priceFeed[newDcdc] != address(0), "asm-add-pricefeed-first");
            require(newDcdc != address(0), "asm-dcdc-address-zero");
            dcdcs[newDcdc] = uint(value1_) > 0;
            updateTotalDcdcValue(newDcdc);
        } else if (what_ == "cdcs") {
            address newCdc = addr(value_);
            require(priceFeed[newCdc] != address(0), "asm-add-pricefeed-first");
            require(newCdc != address(0), "asm-cdc-address-zero");
            cdcs[newCdc] = uint(value1_) > 0;
            updateCdcValue(newCdc);
        } else if (what_ == "custodians") {
            address custodian = addr(value_);
            require(custodian != address(0), "asm-custodian-zero-address");
            payTokens[addr(value_)] = uint(value1_) > 0;
        } else if (what_ == "overCollRatio") {
            overCollRatio = uint(value_);
            require(overCollRatio >= 1 ether, "asm-system-must-be-overcollaterized");
            require(
                add(
                    add(
                        totalDpassV,
                        totalDcdcV),
                    dust) >=
                    wmul(
                        overCollRatio,
                        totalCdcV)
                , "asm-can-not-introduce-new-ratio");
        } else if (what_ == "payTokens") {
            require(addr(value_) != address(0), "asm-pay-token-address-no-zero");
            payTokens[addr(value_)] = uint(value1_) > 0;
        } else if (what_ == "decimals") {
            require(addr(value_) != address(0x0), "asm-wrong-address");
            uint decimal = uint256(value1_);
            if(decimal >= 18) {
                decimals[addr(value_)] = mul(10 ** 18, 10 ** (uint256(value1_) - 18));
            } else {
                decimals[addr(value_)] = 10 ** 18 / 10 ** (18 - uint256(value1_));
            }

            decimalsSet[addr(value_)] = true;
        } else if (what_ == "dust") {

            dust = uint256(value_);

        }

        emit LogConfigChange(msg.sender, what_, value_, value1_);
    }
    
    function isCustodian(address custodian) public view returns(bool) {
        return custodians[custodian];
    }
    
    function getTotalDpassCustV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalDpassCustV[custodian];
    }

    function getRateNewest(address token) public view auth returns (uint) {
        return _getNewRate(token);
    }

    function getRate(address token) public view auth returns (uint) {
        return rate[token];
    }

    function getCdcValues(address cdc) public view returns(uint256) {
        require(cdcs[cdc], "asm-token-not-listed");
        return cdcValues[cdc];
    }

    function getDcdcValues(address dcdc) public view returns(uint256) {
        require(dcdcs[dcdc], "asm-token-not-listed");
        return dcdcValues[dcdc];
    }

    function getTotalDcdcCustV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalDcdcCustV[custodian];
    }

    function getDcdcCustV(address custodian, address dcdc) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        return dcdcCustV[dcdc][custodian];
    }

    function isPayToken(address payToken) public view returns(bool) {
        return payTokens[payToken];
    }

    function isDpass(address dpass) public view returns(bool) {
        return dpasses[dpass];
    }

    function isDcdc(address dcdc) public view returns(bool) {
        return dcdcs[dcdc];
    }

    function isCdc(address cdc) public view returns(bool) {
        return cdcs[cdc];
    }

    /**
    * @dev Retrieve the decimals of a token
    */
    function getDecimals(address token_) public view returns (uint8 dec) {
        require(cdcs[token_] || payTokens[token_] || dcdcs[token_], "asm-token-not-listed");
        require(decimalsSet[token_], "asm-token-with-unset-decimals");
        while(dec <= 77 && decimals[token_] % uint(10) ** dec == 0){
            dec++;
        }
    }

    function isDecimalisSet(address token) public view returns(bool) {
        return decimalsSet[token];
    }

    function getPriceFeed(address token) public view returns(address) {
        require(dpasses[token], "asm-token-not-listed");
        return priceFeed[token];
    }

    function getTokenPurchaseRate(address token) public view returns(uint256) {
        require(payTokens[token], "asm-token-not-listed");
        return tokenPurchaseRate[token];
    }

    function getTotalPaidV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalPaidV[custodian];
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    function getBasePrice(address token, uint256 tokenId) public view returns(uint) {
        require(dpasses[token], "asm-invalid-token-address");
        return basePrice[token][tokenId];
    }

    function setBasePrice(address token, uint256 tokenId, uint256 price) public auth {
        require(dpasses[token], "asm-invalid-token-address");

        if(Dpass(token).ownerOf(tokenId) == address(this)) {
            updateCollateral(price, basePrice[token][tokenId], Dpass(token).getCustodian(tokenId));
        }

        basePrice[token][tokenId] = price;
    }

    function updateCdcValue(address cdc) public stoppable {
        require(cdcs[cdc], "asm-not-a-cdc-token");
        uint newValue = wmulV(DSToken(cdc).totalSupply(), _updateRate(cdc), cdc);

        totalCdcV = sub(add(totalCdcV, newValue), cdcValues[cdc]);

        cdcValues[cdc] = newValue;
    }

    function updateTotalDcdcValue(address dcdc) public stoppable {
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        uint newValue = wmulV(DSToken(dcdc).totalSupply(), _updateRate(dcdc), dcdc);

        totalDcdcV = sub(add(totalDcdcV, newValue), dcdcValues[dcdc]);

        dcdcValues[dcdc] = newValue;
    }

    function updateDcdcValue(address dcdc, address custodian) public stoppable {
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        require(custodians[custodian], "asm-not-a-custodian");

        uint newValue = wmulV(DSToken(dcdc).balanceOf(custodian), _updateRate(dcdc), dcdc);

        totalDcdcCustV[custodian] = sub(add(totalDcdcCustV[custodian], newValue), dcdcCustV[dcdc][custodian]);

        dcdcCustV[dcdc][custodian] = newValue; 
    }

    function notifyTransferFrom(address token, address src, address dst, uint256 amtOrId) external nonReentrant auth {
        uint balance;
        address custodian;

        require(dpasses[token] || cdcs[token] || payTokens[token], "asm-invalid-token");
        
        if(dpasses[token] && src == address(this)) {                        // custodian sells dpass to user
            custodian = Dpass(token).getCustodian(amtOrId);
            updateCollateral(0, basePrice[token][amtOrId], custodian);

            require(                                                        // custodian's total collateral value must be ...
                                                                            // ... more or equal than proportional cdc value and dpasses sold
                wmul(
                    totalCdcV,
                    wdiv(
                        add(
                            totalDpassCustV[custodian],
                            totalDcdcCustV[custodian]),
                        add(
                            totalDpassV,
                            totalDcdcV)))
                     <=
                add(
                    add(
                        totalDpassCustV[custodian],
                        totalDcdcCustV[custodian]),
                    dust)
                , "asm-undercollaterized");

            require(
                add(
                    add(
                        totalDpassV, 
                        totalDcdcV), 
                    dust) >= 
                wmul(
                    overCollRatio, 
                    totalCdcV)
                , "asm-not-enough-collateral");

        } else if (dst == address(this)) {                                  // user sells ERC20 token to sellers
            require(payTokens[token], "asm-we-dont-accept-this-token");

            if (cdcs[token]) {                                              // 
                burn(token, address(this), amtOrId);
            }

            balance = sub(DSToken(token).balanceOf(address(this)), amtOrId); // this assumes that first tokens are sent, than notifyTransferFrom is called, if it is the other way around then amtOrId must not be subrtacted from current balance

            tokenPurchaseRate[token] = wdiv(
                add(
                    wmulV(
                        tokenPurchaseRate[token],
                        balance,
                        token),
                    wmulV(_updateRate(token), amtOrId, token)),
                add(balance, amtOrId));

        } else if (dpasses[token]) {                                        // user sells erc721 token to custodian

            require(payTokens[token], "asm-token-not-accepted");

            updateCollateral(basePrice[token][amtOrId], 0, dst);

        } else {
            require(false, "asm-should-not-end-up-here");
        }
    }

    function burn(address token, address src, uint256 amt) public nonReentrant auth {
        require(cdcs[token], "asm-token-is-not-cdc");
        uint tokenRate = _updateRate(token);

        totalCdcV = sub(
            totalCdcV,
            wmulV(amt, tokenRate, token));
        DSToken(token).burn(src, amt);
    }

    function mint(address token, address dst, uint256 amt) public nonReentrant auth {
        require(cdcs[token], "asm-token-is-not-cdc");
        totalCdcV = add(totalCdcV, wmulV(_updateRate(token), amt, token));
        require(
            add(
                add(
                    totalDpassV, 
                    totalDcdcV), 
                dust) >= 
            wmul(
                overCollRatio, 
                totalCdcV)
            , "asm-not-enough-collateral");
        DSToken(token).mint(dst, amt);
    }

    function mintDcdc(address token, address dst, uint256 amt) public nonReentrant auth {
        require(dcdcs[token], "asm-token-is-not-cdc");
        require(custodians[dst], "asm-dst-not-a-custodian");
        DSToken(token).mint(msg.sender, amt);
        updateTotalDcdcValue(token);
        updateDcdcValue(token, msg.sender);
    }

    function withdraw(address token, uint256 amt) public nonReentrant auth {
        require(custodians[msg.sender], "asm-not-a-custodian");
        require(payTokens[token], "asm-cant-withdraw-token");
        require(tokenPurchaseRate[token] > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(tokenPurchaseRate[token], amt, token);

        require(
            add(
                wmul(
                    totalCdcV,
                    wdiv(
                        totalDpassCustV[msg.sender],
                        totalDpassV)),
                dust) >=
            add(
                totalPaidV[msg.sender],
                tokenV)
            , "asm-too-much-withdrawn");

        sendToken(token, address(this), msg.sender, amt);
        totalPaidV[msg.sender] = add(totalPaidV[msg.sender], tokenV);
    }

    function getAmtForSale(address token) external view returns(uint256) {
        require(cdcs[token], "asm-token-is-not-cdc");
        return wdivT(
            sub(
                wdiv(
                    add(
                        totalDpassV,
                        totalDcdcV),
                    overCollRatio),
                totalCdcV),
            _getNewRate(token),
            token);
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wdiv(wmul(a, b), decimals[token]);
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a, uint256 b, address token) public view returns(uint256) {
        return wmul(wdiv(a,b), decimals[token]);
    }

    function updateCollateral(uint positiveV, uint negativeV, address custodian) public auth {
        require(custodians[custodian], "asm-not-a-custodian");

        totalDpassCustV[custodian] = sub(
            add(
                totalDpassCustV[custodian],
                positiveV),
            negativeV);

        totalDpassV = sub(
            add(
                totalDpassV,
                positiveV),
            negativeV);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token)) > 0, "asm-updateRate-rate-gt-zero");
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
            "asm-no-price-feed");

        (usdRateBytes, feedValid) = 
            TrustedFeedLike(priceFeed[token_]).peek();                  // receive DPT/USD price

        if (feedValid) {                                                // if feed is valid, load DPT/USD rate from it
            rate_ = uint(usdRateBytes);
        } else {
            require(manualRate[token_], "Manual rate not allowed");     // if feed invalid revert if manualEthRate is NOT allowed
            rate_ = rate[token_];
        }
    }
}
