pragma solidity ^0.5.11;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";


contract TrustedErc20Wallet {
    function totalSupply() public view returns (uint);
    function balanceOf(address guy) public view returns (uint);
    function allowance(address src, address guy) public view returns (uint);

    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) public returns (bool);
}


contract Wallet is DSAuth, DSStop, DSMath {
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    event LogTransferEth(address src, address dst, uint256 amount);
    address public eth = address(0xee);

    function () external payable {
        emit LogTest(msg.value);
    }

    function transfer(address token, address payable dst, uint256 amt) public auth returns (bool) {
        return sendToken(token, address(this), dst, amt);
    }

    function transferFrom(address token, address src, address payable dst, uint256 amt) public auth returns (bool) {
        return sendToken(token, src, dst, amt);
    }

    function totalSupply(address token) public view returns (uint){
        if (token == eth) {
            require(false, "No total supply for Ether");
        } else {
            return TrustedErc20Wallet(token).totalSupply();
        }
    }

    function balanceOf(address token, address src) public view returns (uint) {
        if (token == eth) {
            return src.balance;
        } else {
            return TrustedErc20Wallet(token).balanceOf(src);
        }
    }

    function allowance(address token, address src, address guy)
    public view returns (uint) {
        if( token == eth) {
            require(false, "No allowance for Ether");
        } else {
            return TrustedErc20Wallet(token).allowance(src, guy);
        }
    }

    function approve(address token, address guy, uint wad)
    public auth returns (bool) {
        if( token == eth) {
            require(false, "Can't approve Ether");
        } else {
            return TrustedErc20Wallet(token).approve(guy, wad);
        }
    }

    /**
    * @dev send token or ether to destination
    */
    function sendToken(
        address token,
        address src,
        address payable dst,
        uint256 amount
    ) internal returns (bool){
        TrustedErc20Wallet erc20 = TrustedErc20Wallet(token);
        if (token == eth && amount > 0) {
            require(src == address(this), "Ether transfer invalid src");
            dst.transfer(amount);
            emit LogTransferEth(src, dst, amount);
        } else {
            if (amount > 0) erc20.transferFrom(src, dst, amount);   // transfer all of token to dst
        }
        return true;
    }
}
