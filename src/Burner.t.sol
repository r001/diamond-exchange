pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "./Burner.sol";

contract TokenUser {
    DSToken token;

    constructor(DSToken token_) public {
        token = token_;
    }
}

contract BurnerTest is DSTest {
    uint constant initialBalance = 1000;

    DSToken token;
    TokenUser user;
    Burner burner;
    address self;

    function setUp() public {
        token = new DSToken("DPT");
        token.mint(initialBalance);
        user = new TokenUser(token);
        burner = new Burner(token);
        // To burn burner have to be owner of token
        token.setOwner(address(burner));
        self = address(this);
    }

    function testValidBurn() public {
        uint sentAmount = 250;
        token.transfer(address(burner), sentAmount);
        burner.burn(sentAmount);
        assertEq(token.totalSupply(), initialBalance - sentAmount);
    }

    function testValidAllBurn() public {
        uint sentAmount = 250;
        token.transfer(address(burner), sentAmount);
        burner.burnAll();
        assertEq(token.totalSupply(), initialBalance - sentAmount);
    }

    function testReturnToOwner() public {
        uint sentAmount = 250;
        token.transfer(address(burner), sentAmount);
        burner.returnToOwner(sentAmount);
        assertEq(token.totalSupply(), initialBalance);
        assertEq(token.balanceOf(burner.owner()), initialBalance);
    }
}
