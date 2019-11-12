pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-token/base.sol";
import "./Dcdc.sol";

contract DcdcTester {
    Dcdc public _dcdc;

    constructor(Dcdc dcdc) public {
        _dcdc = dcdc;
    }
}

contract DcdcTest is DSTest {
    uint constant dcdcMinted = (10 ** 7) * (10 ** 18);
    Dcdc dcdc;
    DcdcTester user;

    function setUp() public {
        dcdc = new Dcdc("BR,VS,G,0.05", "DCDC", true);
        user = new DcdcTester(dcdc);
    }

    function testDiamondType() public {
        assertEq(dcdc.cccc(), "BR,VS,G,0.05");
    }
    
    function testSymbol() public {
        assertEq(dcdc.symbol(), "DCDC");
    }

    function testMint() public {
        dcdc.mint(10 ether);
        assertEq(dcdc.totalSupply(), 10 ether);
    }

    function testFailStopTransfers() public {
        dcdc.mint(address(this), dcdcMinted);
        assertTrue(dcdc.transferFrom(address(this), address(user), dcdcMinted));
    }

    function testWeReallyGotAllTokens() public {
        dcdc.mint(address(this), dcdcMinted);
        dcdc.setStopTransfers(false);
        assertTrue(dcdc.transferFrom(address(this), address(user), dcdcMinted));
        assertEq(dcdc.balanceOf(address(this)), 0);
        assertEq(dcdc.balanceOf(address(user)), dcdcMinted);
    }

    function testFailSendMoreThanAvailable() public {
        dcdc.mint(address(this), dcdcMinted);
        dcdc.setStopTransfers(false);
        dcdc.transfer(address(user), dcdcMinted + 1);
    }
}
