pragma solidity ^0.5.11;

import "ds-token/token.sol";
contract Dcdc is DSToken {

    bytes32 public cccc;
    bool public stopTransfers = true;
    bool public isInteger;

    constructor(bytes32 cccc_, bytes32 symbol_, bool isInteger_) DSToken(symbol_) public {
        cccc = cccc_;
        isInteger = isInteger_;
    }

    modifier integerOnly(uint256 num) {
        if(isInteger)
            require(num % 10 ** decimals == 0, "dcdc-only-integer-value-allowed");
        _;
    }

    function getDiamondType() public view returns (bytes32) {
        return cccc;
    }

    function transferFrom(address src, address dst, uint wad)
    public
    stoppable
    integerOnly(wad)
    returns (bool) {
        if(!stopTransfers) {
            return super.transferFrom(src, dst, wad);
        }
    }

    function setStopTransfers(bool stopTransfers_) public auth {
        stopTransfers = stopTransfers_;
    }

    function mint(address guy, uint256 wad) public integerOnly(wad) {
        super.mint(guy, wad);
    }

    function burn(address guy, uint256 wad) public integerOnly(wad) {
        super.burn(guy, wad);
    }
}
// TODO: add tests
