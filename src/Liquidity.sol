pragma solidity ^0.5.11;

import "./Wallet.sol";

contract Liquidity is Wallet {
    function burn(address dpt, address burner, uint256 burnValue) public {
        if (burnValue == 0) {
            return;
        }
    }
}
