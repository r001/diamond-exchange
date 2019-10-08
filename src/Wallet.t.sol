pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "./Wallet.sol";

contract TokenUser {
    Wallet wal;

    constructor(address payable _wal) public {
        wal = Wallet(_wal);
    }

    function doTransferWallet(address token, address payable dst, uint256 amt) public returns (bool) {
        return wal.transfer(token, dst, amt);
	}
    
    function doTransferFromWallet(address token, address src, address payable dst, uint256 amt) public returns (bool) {
		return wal.transferFrom(token, src, dst, amt);
	}
    
    function doTotalSupplyWallet(address token) public view returns (uint) {
		return wal.totalSupply(token);
	}
    
    function doBalanceOfWallet(address token, address src) public view returns (uint) {
		return wal.balanceOf(token, src);
	}
    
    function doAllowanceWallet(address token, address src, address guy) public view returns (uint) {
		return wal.allowance(token, src, guy);
	}

    function doApproveWallet(address token, address guy, uint wad) public {
        wal.approve(token, guy, wad);
    }

    function doTransferToken(address token, address payable dst, uint256 amt) public returns (bool) {
        return DSToken(token).transfer(dst, amt);
    }

    function doTransferFromToken(address token, address src, address payable dst, uint256 amt) public returns (bool) {
        return DSToken(token).transferFrom(src, dst, amt);
    }

    function doTotalSupplyToken(address token) public view returns (uint) {
        return DSToken(token).totalSupply();
    }

    function doBalanceOfToken(address token, address src) public view returns (uint) {
        return DSToken(token).balanceOf(src);
    }

    function doAllowanceToken(address token, address src, address guy) public view returns (uint) {
        return DSToken(token).allowance(src, guy);
    }

    function doApproveToken(address token, address guy, uint wad) public {
        DSToken(token).approve(guy, wad);
    }

    function () external payable {}
}


contract WalletTest is DSTest, DSMath {
    // TODO: remove all following LogTest()
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    uint constant initialBalance = 1000;

    DSToken dpt;
    address eth;
    TokenUser user;
    address payable userAddr;
    Wallet wal;
    address payable walAddr;
    address self;
    uint initEth;
    uint initDpt;

    function setUp() public {
        dpt = new DSToken("DPT");
        wal = new Wallet();
        walAddr = address(uint160(address(wal)));
        eth = address(0xee);
        user = new TokenUser(walAddr);
        userAddr = address(uint160(address(user)));
        self = address(this);

        dpt.mint(initialBalance * 1000);

        dpt.transfer(walAddr, initialBalance);
        dpt.transfer(userAddr, initialBalance);
        walAddr.transfer(initialBalance);
        userAddr.transfer(initialBalance);
        dpt.approve(userAddr, 100);
        initEth = address(this).balance;
        initDpt = dpt.balanceOf(address(this));
    }

    function () external payable {
    }
    
    function testWalletTransfer() public {
        uint sentAmount = 250;
        wal.transfer(address(dpt), userAddr, sentAmount);
        assertEq(wal.balanceOf(address(dpt), userAddr), add(initialBalance, sentAmount));
        assertEq(wal.balanceOf(address(dpt), address(uint160(walAddr))), sub(initialBalance, sentAmount));
    }

    function testWalletTransferEth() public {
        uint sentAmount = 250;
        wal.transfer(eth, userAddr, sentAmount);
        assertEq(userAddr.balance,  add(initialBalance, sentAmount));
        assertEq(walAddr.balance, sub(initialBalance, sentAmount));
    }

    function testWalletTransferFrom() public {
        uint sentAmount = 250;
        user.doApproveToken(address(dpt), walAddr, sentAmount);

        wal.transferFrom(address(dpt), userAddr, address(uint160(address(this))),  sentAmount);
        assertEq(
            wal.balanceOf(address(dpt), address(user)), 
            sub(initialBalance, sentAmount));
        assertEq(
            wal.balanceOf(address(dpt), address(uint160(address(this)))),
            add(initDpt, sentAmount));
    }

    function testWalletTotalSupply() public {
        uint totalSupply = wal.totalSupply(address(dpt));
        assertEq(totalSupply, initialBalance * 1000);
    }

    function testFailWalletTotalSupplyEth() public view {
        wal.totalSupply(eth);
    }

    function testWalletBalanceOf() public {
        assertEq(wal.balanceOf(address(dpt), userAddr), initialBalance);
    }

    function testWalletBalanceOfEth() public {
        assertEq(wal.balanceOf(eth, userAddr), initialBalance);
    }

    function testWalletAllowance() public {
        assertEq(wal.allowance(address(dpt), address(this), userAddr), 100);
    }

    function testFailWalletAllowanceEth() public view {
        wal.allowance(eth, address(this), userAddr);
    }

    function testWalletApprove() public {        

        wal.approve(address(dpt), userAddr, 500);
        assertEq(wal.allowance(address(dpt), walAddr, userAddr), 500);

        user.doTransferFromToken(address(dpt), walAddr, userAddr, 500);
        
        assertEq(wal.balanceOf(address(dpt), userAddr), add(initialBalance, 500));
        assertEq(wal.balanceOf(address(dpt), walAddr), sub(initialBalance, 500));
    }

    function testFailWalletApproveWithoutAuth() public {        
        wal.approve(address(dpt), userAddr, 500);
        user.doTransferFromToken(address(dpt), address(this), userAddr, 501);
    }

    function testFailWalletAboveApprove() public {
        wal.approve(eth, userAddr, 500);
    }

    function testFailWalletTransferByUser() public {
        user.doTransferWallet(address(dpt), userAddr, 500);
    }

    function testFailWalletTransferFromByUser() public {
        wal.approve(address(dpt), userAddr, 500);
        user.doTransferFromWallet(address(dpt), walAddr, userAddr, 500);
    }

    function testFailWalletApproveByUser() public {
        user.doApproveWallet(address(dpt), userAddr, 500);
    }

    function testWalletSetUserAsOwnerTransferByUser() public {
        wal.setOwner(userAddr);
        user.doTransferWallet(address(dpt), userAddr, 500);
    }

    function testWalletSetUserAsOwnerTransferFromByUser() public {
        wal.approve(address(dpt), userAddr, 500);
        wal.setOwner(userAddr);
        user.doTransferFromWallet(address(dpt), walAddr, userAddr, 500);
    }

    function testWalletSetUserAsOwnerApproveByUser() public {
        wal.setOwner(userAddr);
        user.doApproveWallet(address(dpt), userAddr, 500);
    }
}
