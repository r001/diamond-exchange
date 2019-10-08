pragma solidity ^0.5.11;

import "ds-auth/auth.sol";
import "ds-token/token.sol";


/**
 * @title DPT token burner
 * @dev The place where DPT are stored before be burned
 */
contract Burner is DSAuth {
    DSToken public token;

    constructor(DSToken token_) public {
        token = token_;
        // token.approve(token.owner());
    }

    function burn(uint amount_) public auth {
        token.burn(amount_);
    }

    function burnAll() public auth {
        uint totalAmount = token.balanceOf(address(this));
        burn(totalAmount);
    }

    function returnToOwner(uint amount_) public auth {
        token.transfer(owner, amount_);
    }
}
