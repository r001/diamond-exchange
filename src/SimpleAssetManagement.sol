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
    event LogUpdateCollateral(uint256 positiveV, uint256 negativeV, address custodian);
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);
    mapping(
        address => mapping(
            uint => uint)) private basePrice;               // the base price used for collateral valuation
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
    mapping(address => bool) payTokens;                    // returns true for tokens allowed to make payment to custodians with
    mapping(address => bool) dpasses;                       // returns true for dpass tokens allowed in this contract
    mapping(address => bool) dcdcs;                         // returns true for tokens representing cdc assets (without gia number) that are allowed in this contract
    mapping(address => bool) cdcs;                          // returns true for cdc tokens allowed in this contract
    mapping(address => uint) public decimals;               // stores decimals for each ERC20 token
    mapping(address => bool) public decimalsSet;            // stores decimals for each ERC20 token
    mapping(address => address) public priceFeed;           // price feed address for token
    mapping(address => uint) public tokenPurchaseRate;      // the average purchase rate of a token. This is the ...
                                                            // ... price of token at which we send it to custodian
    mapping(address => uint) public totalPaidV;             // total amount that has been paid to custodian for dpasses and cdc in base currency
    mapping(address => uint) public totalDpassSoldV;        // totoal amount of all dpass tokens that have been sold by custodian
    mapping(address => bool) public manualRate;             // if manual rate is enabled then owner can update rates if feed not available
    mapping(address => bytes32) public domains;             // the domain that connects the set of cdc, dpass, and dcdc tokens, and custodians
    mapping(bytes32 => uint) public totalDpassV;            // total value of dpass collaterals in base currency
    mapping(bytes32 => uint) public totalDcdcV;             // total value of dcdc collaterals in base currency
    mapping(bytes32 => uint) public totalCdcV;              // total value of cdc tokens issued in base currency
    mapping(bytes32 => uint) public overCollRatio;          // the totalDpassV >= overCollRatio * totalCdcV
    uint public dust = 1000;                                // dust value is the largest value we still consider 0 ...
    bool public locked;                                     // variable prevents to exploit by recursively calling funcions
    address public currDcdc;                                // the current dcdc token to update the price for
    /**
     * @dev Modifier making sure the function can not be called in a recursive way in one transaction.
     */
    modifier nonReentrant {
        require(!locked, "asm-reentrancy-detected");
        locked = true;
        _;
        locked = false;
    }

    /**
    * @dev Set configuration variables of asset managment contract.
    * @param what_ bytes32 tells to function what to set.
    * @param value_ bytes32 setter variable. Its meaning is dependent on what_.
    * @param value1_ bytes32 setter variable. Its meaning is dependent on what_.
    * @param value2_ bytes32 setter variable. Its meaning is dependent on what_. In most cases it stands for domain.
    *
    */
    function setConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public nonReentrant auth {
        if (what_ == "rate") {
            address token = addr(value_);
            uint256 value = uint256(value1_);
            require(payTokens[token] || cdcs[token] || dcdcs[token], "asm-token-not-allowed-rate");
            require(value > 0, "asm-rate-must-be-gt-0");
            rate[token] = value;
        } else if (what_ == "priceFeed") {
            require(addr(value1_) != address(address(0x0)), "asm-wrong-pricefeed-address");
            priceFeed[addr(value_)] = addr(value1_);
        } else if (what_ == "dpasses") {
            bytes32 domain = value2_;
            address dpass = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[dpass] = domain;
            require(dpass != address(0), "asm-dpass-address-zero");
            dpasses[dpass] = enable;
        } else if (what_ == "cdcs") {
            bytes32 domain = value2_;
            address newCdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[newCdc] = domain;
            require(priceFeed[newCdc] != address(0), "asm-add-pricefeed-first");
            require(decimalsSet[newCdc], "asm-add-decimals-first");
            require(newCdc != address(0), "asm-cdc-address-zero");
            cdcs[newCdc] = enable;
            _updateCdcValue(newCdc);
        } else if (what_ == "dcdcs") {
            bytes32 domain = value2_;
            address newDcdc = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[newDcdc] = domain;
            require(priceFeed[newDcdc] != address(0), "asm-add-pricefeed-first");
            require(newDcdc != address(0), "asm-dcdc-address-zero");
            dcdcs[newDcdc] = enable;
            _updateTotalDcdcValue(newDcdc);
        } else if (what_ == "custodians") {
            bytes32 domain = value2_;
            address custodian = addr(value_);
            bool enable = uint(value1_) > 0;
            if(enable) domains[custodian] = domain;
            require(custodian != address(0), "asm-custodian-zero-address");
            custodians[addr(value_)] = enable;
        } else if (what_ == "setApprovalForAll") {
            address dst = addr(value_);
            address token = addr(value1_);
            bool enable = uint(value2_) > 0;
            require(dpasses[token],"asm-not-a-dpass-token");
            require(dst != address(0), "asm-custodian-zero-address");
            Dpass(token).setApprovalForAll(dst, enable);
        } else if (what_ == "overCollRatio") {
            bytes32 domain = value2_;
            overCollRatio[domain] = uint(value_);
            require(overCollRatio[domain] >= 1 ether, "asm-system-must-be-overcollaterized");
            _requireSystemCollaterized(domain);
        } else if (what_ == "payTokens") {
            address token = addr(value_);
            require(token != address(0), "asm-pay-token-address-no-zero");
            payTokens[token] = uint(value1_) > 0;
        } else if (what_ == "decimals") {
            address token = addr(value_);
            uint decimal = uint256(value1_);
            require(token != address(0x0), "asm-wrong-address");
            decimals[token] = 10 ** decimal;
            decimalsSet[token] = true;
        } else if (what_ == "dust") {

            dust = uint256(value_);

        }

        emit LogConfigChange(msg.sender, what_, value_, value1_);
    }

    /**
     * @dev Returns true if custodian is a valid custodian.
     */
    function isCustodian(address custodian) public view returns(bool) {
        return custodians[custodian];
    }

    /**
     * @dev Return the total value of all dpass tokens at custodians.
     */
    function getTotalDpassCustV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalDpassCustV[custodian];
    }

    /**
     * @dev Get newest rate in base currency from priceFeed for token.
     */
    function getRateNewest(address token) public view auth returns (uint) {
        return _getNewRate(token);
    }

    /**
     * @dev Get currently stored rate in base currency from priceFeed for token.
     */
    function getRate(address token) public view auth returns (uint) {
        return rate[token];
    }

    /**
     * @dev Get currently stored value in base currency of cdc token.
     */
    function getCdcValues(address cdc) public view returns(uint256) {
        require(cdcs[cdc], "asm-token-not-listed");
        return cdcValues[cdc];
    }

    /**
     * @dev Get currently stored total value of dcdc token.
     */
    function getDcdcValues(address dcdc) public view returns(uint256) {
        require(dcdcs[dcdc], "asm-token-not-listed");
        return dcdcValues[dcdc];
    }

    /**
     * @dev Get the currently stored total value in base currency of all dcdc tokens at a custodian.
     */
    function getTotalDcdcCustV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalDcdcCustV[custodian];
    }

    /**
     * @dev Get the currently sotored total value in base currency of a certain dcdc token at a custodian.
     */
    function getDcdcCustV(address custodian, address dcdc) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        return dcdcCustV[dcdc][custodian];
    }

    /**
     * @dev Returns true if token can be used as a payment token.
     */
    function isPayToken(address payToken) public view returns(bool) {
        return payTokens[payToken];
    }

    /**
     * @dev Returns true if token is a valid dpass token.
     */
    function isDpass(address dpass) public view returns(bool) {
        return dpasses[dpass];
    }

    /**
     * @dev Returns true if token is a valid dcdc token.
     */
    function isDcdc(address dcdc) public view returns(bool) {
        return dcdcs[dcdc];
    }

    /**
     * @dev Returns true if token is a valid cdc token.
     */
    function isCdc(address cdc) public view returns(bool) {
        return cdcs[cdc];
    }

    /**
    * @dev Retrieve the decimals of a token. As we can store only uint values, the decimals defne how many of the lower digits are part of the fraction part.
    */
    function getDecimals(address token_) public view returns (uint8 dec) {
        require(cdcs[token_] || payTokens[token_] || dcdcs[token_], "asm-token-not-listed");
        require(decimalsSet[token_], "asm-token-with-unset-decimals");
        while(dec <= 77 && decimals[token_] % uint(10) ** uint(dec) == 0){
            dec++;
        }
        dec--;
    }

    /**
    * @dev Returns true if decimals have been set for a certain token.
    */
    function isDecimalsSet(address token) public view returns(bool) {
        return decimalsSet[token];
    }

    /**
    * @dev Returns the price feed address of a token. Price feeds provide pricing info for asset management.
    */
    function getPriceFeed(address token_) public view returns(address) {
        require(dpasses[token_] || cdcs[token_] || dcdcs[token_] || payTokens[token_], "asm-token_-not-listed");
        return priceFeed[token_];
    }

    /**
    * @dev Returns the average purchase rate for a token. Users send
           different tokens several times to asm. Their price in terms of
           base currency is varying. This function returns the avarage value of the token.
    */
    function getTokenPurchaseRate(address token) public view returns(uint256) {
        require(payTokens[token], "asm-token-not-listed");
        return tokenPurchaseRate[token];
    }

    /**
    * @dev  Returns the total value that has been paid out for a custodian
            for its services. The value is calculated in terms of base currency.
    */
    function getTotalPaidV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalPaidV[custodian];
    }

    /**
    * @dev  Returns the total value of all the dpass diamonds sold by a custodian.
            The value is calculated in base currency.
    */
    function getTotalDpassSoldV(address custodian) public view returns(uint256) {
        require(custodians[custodian], "asm-not-a-custodian");
        return totalDpassSoldV[custodian];
    }

    /*
    * @dev Convert address to bytes32
    */
    function addr(bytes32 b_) public pure returns (address) {
        return address(uint256(b_));
    }

    /**
    * @dev Returns the base price of a diamond. This price is the final value of the diamond. Asset management uses this price to define total collateral value.
    */
    function getBasePrice(address token, uint256 tokenId) public view returns(uint) {
        require(dpasses[token], "asm-invalid-token-address");
        return basePrice[token][tokenId];
    }

    /**
    * @dev Set base price for a diamond. This function should be used by oracles to update values of diamonds for sale.
    */
    function setBasePrice(address token, uint256 tokenId, uint256 price) public auth {
        require(dpasses[token], "asm-invalid-token-address");

        if(Dpass(token).ownerOf(tokenId) == address(this)) {
            _updateCollateralDpass(price, basePrice[token][tokenId], Dpass(token).getCustodian(tokenId));
        }

        basePrice[token][tokenId] = price;
    }

    /**
    * @dev Returns the total value of all the dpass tokens in a domain.
    */
    function getTotalDpassV(bytes32 domain) public view returns(uint) {
        return totalDpassV[domain];
    }

    /**
    * @dev Returns the total value of all the dcdc tokens in a domain.
    */
    function getTotalDcdcV(bytes32 domain) public view returns(uint) {
        return totalDcdcV[domain];
    }

    /**
    * @dev Returns the total value of all the cdc tokens in a domain.
    */
    function getTotalCdcV(bytes32 domain) public view returns(uint) {
        return totalCdcV[domain];
    }

    /**
    * @dev Returns the required of overcollaterization ratio that is required. The total value of cdc tokens in a domain should be less than total value of dpass tokens plus total value of dcdc tokens divided by overcollatrization ratio.
    */
    function getOverCollRatio(bytes32 domain) public view returns(uint) {
        return overCollRatio[domain];
    }

    /**
    * @dev Updates value of cdc token from priceFeed. This function is called by oracles but can be executed by anyone wanting update cdc value in the system.
    */
    function updateCdcValue(address cdc) public stoppable {
        _updateCdcValue(cdc);
    }

    /**
    * @dev Updates value of a dcdc token. This function should be called by oracles but anyone can call it.
    */
    function updateTotalDcdcValue(address dcdc) public stoppable {
        _updateTotalDcdcValue(dcdc);
    }

    /**
    * @dev Updates value of a dcdc token belonging to a custodian. This function should be called by oracles or custodians but anyone can call it.
    * @param dcdc address the dcdc token we want to update the value for
    * @param custodian address the custodian whose total dcdc values will be updated.
    */
    function updateDcdcValue(address dcdc, address custodian) public stoppable {
        _updateDcdcValue(dcdc, custodian);
    }

    /**
    * @dev Allows asset management to be notified about a token transfer. If system would get undercollaterized because of transfer it will be reverted.
    * @param token address the token that has been sent during transaction
    * @param src address the source address the token has been sent from
    * @param dst address the destination address the token has been sent to
    * @param amtOrId uint the amount of tokens sent if token is a DSToken or the id of token if token is a Dpass token.
    */
    function notifyTransferFrom(address token, address src, address dst, uint256 amtOrId) external nonReentrant auth {
        uint balance;
        address custodian;
        bytes32 domain = domains[token];

        require(dpasses[token] || cdcs[token] || payTokens[token], "asm-invalid-token");

        if(dpasses[token] && src == address(this)) {                        // custodian sells dpass to user
            custodian = Dpass(token).getCustodian(amtOrId);
            _updateCollateralDpass(0, basePrice[token][amtOrId], custodian);
            totalDpassSoldV[custodian] = add(totalDpassSoldV[custodian], basePrice[token][amtOrId]);

            _requireCustodianCollaterized(custodian, _getCustodianCdcV(domain, custodian));
            _requireSystemCollaterized(domain);

        } else if (dst == address(this) && !dpasses[token]) {                                  // user sells ERC20 token to sellers
            require(payTokens[token], "asm-we-dont-accept-this-token");

            if (cdcs[token]) {                                              //
                _burn(token, amtOrId);
            } else {
                balance = sub(DSToken(token).balanceOf(address(this)), amtOrId); // this assumes that first tokens are sent, than notifyTransferFrom is called, if it is the other way around then amtOrId must not be subrtacted from current balance
                tokenPurchaseRate[token] = wdiv(
                    add(
                        wmulV(
                            tokenPurchaseRate[token],
                            balance,
                            token),
                        wmulV(_updateRate(token), amtOrId, token)),
                    add(balance, amtOrId));
            }


        } else if (dpasses[token]) {                                        // user sells erc721 token to custodian

            require(payTokens[token], "asm-token-not-accepted");

            _updateCollateralDpass(basePrice[token][amtOrId], 0, Dpass(token).getCustodian(amtOrId));

        } else {
            require(false, "asm-unsupported-tx");
        }
    }

    /**
    * @dev Burns cdc tokens when users pay with them. Also updates system collaterization.
    * @param token address cdc token that needs to be burnt
    * @param amt uint the amount to burn.
    */
    function burn(address token, uint256 amt) public nonReentrant auth {
        _burn(token, amt);
    }

    /**
    * @dev Mints cdc tokens when users buy them. Also updates system collaterization.
    * @param token address cdc token that needs to be minted
    * @param dst address the address for whom cdc token will be minted for.
    */
    function mint(address token, address dst, uint256 amt) public nonReentrant auth {
        bytes32 domain = domains[token];
        require(cdcs[token], "asm-token-is-not-cdc");
        DSToken(token).mint(dst, amt);
        _updateCdcValue(token);
        _requireSystemCollaterized(domain);
    }

    /**
    * @dev Mints cdc tokens when users buy them. Also updates system collaterization.
    * @param token address cdc token that needs to be minted
    * @param dst address the address for whom cdc token will be minted for.
    * @param amt uint amount to be minted
    */
    function mintDcdc(address token, address dst, uint256 amt) public nonReentrant auth {
        require(!custodians[msg.sender] || dst == msg.sender, "asm-can-not-mint-for-dst");
        require(dcdcs[token], "asm-token-is-not-cdc");
        require(custodians[msg.sender], "asm-dst-not-a-custodian");
        DSToken(token).mint(dst, amt);
        _updateDcdcValue(token, dst);
    }

    function burnDcdc(address token, address src, uint256 amt) public nonReentrant auth {
        bytes32 domain = domains[token];

        uint custodianCdcV = _getCustodianCdcV(domain, src);

        require(dcdcs[token], "asm-token-is-not-cdc");
        require(custodians[src], "asm-dst-not-a-custodian");
        DSToken(token).burn(src, amt);
        _updateDcdcValue(token, src);

        _requireCustodianCollaterized(src, custodianCdcV);
        _requireSystemCollaterized(domain);
        _requirePaidLessThanSold(src, custodianCdcV);
    }

    function getWithdrawValue(address custodian) public view returns(uint) {
        require(custodians[custodian], "asm-not-a-custodian");
        uint custodianCdcV = _getCustodianCdcV(domains[custodian], custodian);
        uint totalSoldV = add(
            custodianCdcV,
            totalDpassSoldV[custodian]);
        if (add(totalSoldV, dust) > totalPaidV[custodian]) {
            return sub(totalSoldV, totalPaidV[custodian]);
        } else {
            return 0;
        }
    }

    function withdraw(address token, uint256 amt) public nonReentrant auth {
        address custodian = msg.sender;
        bytes32 domain = domains[custodian];
        require(custodians[custodian], "asm-not-a-custodian");
        require(payTokens[token], "asm-cant-withdraw-token");
        require(tokenPurchaseRate[token] > 0, "asm-token-purchase-rate-invalid");

        uint tokenV = wmulV(tokenPurchaseRate[token], amt, token);

        totalPaidV[msg.sender] = add(totalPaidV[msg.sender], tokenV);
        _requirePaidLessThanSold(custodian, _getCustodianCdcV(domain, custodian));

        sendToken(token, address(this), msg.sender, amt);
    }

    function getAmtForSale(address token) external view returns(uint256) {
        bytes32 domain = domains[token];
        require(cdcs[token], "asm-token-is-not-cdc");
        return wdivT(
            sub(
                wdiv(
                    add(
                        totalDpassV[domain],
                        totalDcdcV[domain]),
                    overCollRatio[domain]),
                totalCdcV[domain]),
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

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dpass tokens at custodian.
    */
    function updateCollateralDpass(uint positiveV, uint negativeV, address custodian) public auth {
        _updateCollateralDpass(positiveV, negativeV, custodian);
        emit LogUpdateCollateral(positiveV, negativeV, custodian);
    }

    /*
    * @dev function should only be used in case of unexpected events at custodian!! It will update the system collateral value and collateral value of dpass tokens custodian.
    */
    function updateCollateralDcdc(uint positiveV, uint negativeV, address custodian) public auth {
        _updateCollateralDcdc(positiveV, negativeV, custodian);
        emit LogUpdateCollateral(positiveV, negativeV, custodian);
    }

    function () external payable {
    }

    function _burn(address token, uint256 amt) internal {
        require(cdcs[token], "asm-token-is-not-cdc");
        DSToken(token).burn(amt);
        _updateCdcValue(token);
    }

    /**
    * @dev Get exchange rate for a token
    */
    function _updateRate(address token) internal returns (uint256 rate_) {
        require((rate_ = _getNewRate(token)) > 0, "asm-updateRate-rate-gt-zero");
        rate[token] = rate_;
    }

    function _updateCdcValue(address cdc) internal {
        require(cdcs[cdc], "asm-not-a-cdc-token");
        bytes32 domain = domains[cdc];
        uint newValue = wmulV(DSToken(cdc).totalSupply(), _updateRate(cdc), cdc);

        totalCdcV[domain] = sub(add(totalCdcV[domain], newValue), cdcValues[cdc]);

        cdcValues[cdc] = newValue;
    }

    function _updateTotalDcdcValue(address dcdc) internal {
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        bytes32 domain = domains[dcdc];
        uint newValue = wmulV(DSToken(dcdc).totalSupply(), _updateRate(dcdc), dcdc);
        totalDcdcV[domain] = sub(add(totalDcdcV[domain], newValue), dcdcValues[dcdc]);
        dcdcValues[dcdc] = newValue;
    }

    function _updateDcdcValue(address dcdc, address custodian) internal {
        require(dcdcs[dcdc], "asm-not-a-dcdc-token");
        require(custodians[custodian], "asm-not-a-custodian");
        uint newValue = wmulV(DSToken(dcdc).balanceOf(custodian), _updateRate(dcdc), dcdc);

        totalDcdcCustV[custodian] = sub(
            add(
                totalDcdcCustV[custodian],
                newValue),
            dcdcCustV[dcdc][custodian]);

        dcdcCustV[dcdc][custodian] = newValue;

        _updateTotalDcdcValue(dcdc);
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

    function _getCustodianCdcV(bytes32 domain, address custodian) internal view returns(uint) {
        return wmul(
            totalCdcV[domain],
            add(totalDpassV[domain], totalDcdcV[domain]) > 0 ?
                wdiv(
                    add(
                        totalDpassCustV[custodian],
                        totalDcdcCustV[custodian]),
                    add(
                        totalDpassV[domain],
                        totalDcdcV[domain])):
                1 ether);
    }
    /**
    * @dev System must be overcollaterized at all time. Whenever collaterization shrinks this function must be called.
    */
    
    function _requireSystemCollaterized(bytes32 domain) internal view returns(uint) {
        require(
            add(
                add(
                    totalDpassV[domain],
                    totalDcdcV[domain]),
                dust) >=
            wmul(
                overCollRatio[domain],
                totalCdcV[domain])
            , "asm-system-undercollaterized");
    }

    /**
    * @dev Custodian's total collateral value must be more or equal than proportional cdc value and dpasses sold
    */
    function _requireCustodianCollaterized(address custodian, uint256 custodianCdcV) internal view {
        require(                                    
            custodianCdcV
                 <=
            add(
                add(
                    totalDpassCustV[custodian],
                    totalDcdcCustV[custodian]),
                dust)
            , "asm-custodian-undercollaterized");
    }

    /**
    * @dev The total value paid to custodian must be less then the total value of sold assets
    */
    function _requirePaidLessThanSold(address custodian, uint256 custodianCdcV) internal view returns(uint) {
        require(
            add(
                add(
                    custodianCdcV,
                    totalDpassSoldV[custodian]),
                dust) >=
                totalPaidV[custodian]
            , "asm-too-much-withdrawn");
    }

    function _updateCollateralDpass(uint positiveV, uint negativeV, address custodian) internal {
        require(custodians[custodian], "asm-not-a-custodian");
        bytes32 domain = domains[custodian];

        totalDpassCustV[custodian] = sub(
            add(
                totalDpassCustV[custodian],
                positiveV),
            negativeV);

        totalDpassV[domain] = sub(
            add(
                totalDpassV[domain],
                positiveV),
            negativeV);
    }

    function _updateCollateralDcdc(uint positiveV, uint negativeV, address custodian) internal {
        require(custodians[custodian], "asm-not-a-custodian");
        bytes32 domain = domains[custodian];

        totalDcdcCustV[custodian] = sub(
            add(
                totalDcdcCustV[custodian],
                positiveV),
            negativeV);

        totalDcdcV[domain] = sub(
            add(
                totalDcdcV[domain],
                positiveV),
            negativeV);
    }
}
// TODO: do function attributes variable_ notation
// TODO: document functions
// TODO: emit events
// TODO: remove LogTest
// TODO: scenario, when theft is at custodian, how to recover from it, make a testcase of how to zero his collateral, and what to do with dpass tokens, dcdc tokens of him 
