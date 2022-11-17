// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test }   from "@std/Test.sol";
import { IERC20 } from "@oz/token/ERC20/IERC20.sol";

import { AjnaToken }       from "../src/AjnaToken.sol";
import { BurnWrappedAjna } from "../src/BurnWrapper.sol";

contract BurnWrappedTokenTest is Test {

    AjnaToken internal _token;
    BurnWrappedAjna internal _wrappedToken;

    address internal _tokenDeployer = makeAddr("tokenDeployer");
    address internal _tokenHolder = makeAddr("_tokenHolder");
    uint256 _initialAjnaTokenSupply   = 2_000_000_000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function setUp() external {
        vm.startPrank(_tokenDeployer);
        _token = new AjnaToken(_tokenDeployer);
        _wrappedToken = new BurnWrappedAjna(IERC20(address(_token)));
    }

   function approveAndWrapTokens(address account_, uint256 amount_) internal {
        changePrank(account_);
        _token.approve(address(_wrappedToken), amount_);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(account_), address(_wrappedToken), amount_);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(account_), amount_);
        (bool wrapSuccess) = _wrappedToken.depositFor(account_, amount_);

        assertTrue(wrapSuccess);
    }

    function testBaseInvariantMetadata() external {
        assertEq(_token.name(),     "AjnaToken");
        assertEq(_token.symbol(),   "AJNA");
        assertEq(_token.decimals(), 18);
    }

    function testWrappedInvariantMetadata() external {
        assertEq(_wrappedToken.name(),     "Burn Wrapped AJNA");
        assertEq(_wrappedToken.symbol(),   "bwAJNA");
        assertEq(_wrappedToken.decimals(), 18);
    }

    function testWrap() external {
        uint256 tokensToWrap = 50 * 1e18;

        // check initial token balances
        assertEq(_token.balanceOf(_tokenHolder), 0);
        assertEq(_wrappedToken.balanceOf(_tokenHolder), 0);
        assertEq(_token.balanceOf(address(_tokenDeployer)), _initialAjnaTokenSupply);
        assertEq(_wrappedToken.balanceOf(address(_tokenDeployer)), 0);

        // check initial token supply
        assertEq(_token.totalSupply(),        2_000_000_000 * 10 ** _token.decimals());
        assertEq(_wrappedToken.totalSupply(), 0);

        // transfer some tokens to the test address
        changePrank(_tokenDeployer);
        _token.approve(address(_tokenDeployer), tokensToWrap);
        _token.transferFrom(_tokenDeployer, _tokenHolder, tokensToWrap);

        // check token balances after transfer
        assertEq(_token.balanceOf(_tokenHolder), tokensToWrap);
        assertEq(_wrappedToken.balanceOf(_tokenHolder), 0);
        assertEq(_token.balanceOf(address(_tokenDeployer)), _initialAjnaTokenSupply - tokensToWrap);
        assertEq(_wrappedToken.balanceOf(address(_tokenDeployer)), 0);

        // wrap tokens
        approveAndWrapTokens(_tokenHolder, tokensToWrap);

        // check token balances after wrapping
        assertEq(_token.balanceOf(_tokenHolder), 0);
        assertEq(_wrappedToken.balanceOf(_tokenHolder), tokensToWrap);
        assertEq(_token.balanceOf(address(_tokenDeployer)), _initialAjnaTokenSupply - tokensToWrap);
        assertEq(_wrappedToken.balanceOf(address(_tokenDeployer)), 0);

        // check token supply after wrapping
        assertEq(_token.totalSupply(),        2_000_000_000 * 10 ** _token.decimals());
        assertEq(_wrappedToken.totalSupply(), tokensToWrap);
    }

    function testCantUnwrap() external {
        uint256 tokensToWrap = 50 * 1e18;

        // transfer some tokens to the test address
        changePrank(_tokenDeployer);
        _token.approve(address(_tokenDeployer), tokensToWrap);
        _token.transferFrom(_tokenDeployer, _tokenHolder, tokensToWrap);

        // wrap tokens
        approveAndWrapTokens(_tokenHolder, tokensToWrap);

        // try to unwrap tokens
        vm.expectRevert(BurnWrappedAjna.UnwrapNotAllowed.selector);
        _wrappedToken.withdrawTo(_tokenHolder, 25 * 1e18);
    }

}