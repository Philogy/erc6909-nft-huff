// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";

import {IERC6909} from "./IERC6909.sol";

/// @author philogy <https://github.com/philogy>
contract NFT6909Test is Test {
    IERC6909 token;

    event Transfer(address indexed sender, address indexed receiver, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed spender, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    function setUp() public {
        address addr;
        bytes memory code = getCode();
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "FAILED_TO_DEPLOY");

        token = IERC6909(addr);
    }

    function test_fuzzing_totalSupply(address owner, uint256 tokenId, uint256 otherId) public {
        vm.assume(otherId != tokenId);
        vm.assume(owner != address(0));
        _mint(owner, tokenId);
        assertEq(token.totalSupply(tokenId), 1);
        assertEq(token.totalSupply(otherId), 0);
    }

    function test_fuzzing_getBalanceOf(address owner, address other, uint256 tokenId) public {
        vm.assume(other != owner);
        _mint(owner, tokenId);
        assertEq(token.balanceOf(owner, tokenId), 1);
        assertEq(token.balanceOf(other, tokenId), 0);
    }

    function test_fuzzing_getAllowance(address owner, address spender, uint256 tokenId, uint256 allowance) public {
        _approve(owner, spender, tokenId, allowance);
        assertEq(token.allowance(owner, spender, tokenId), allowance);
    }

    function test_fuzzing_isOperator(address owner, address spender, bool isOperator) public {
        _setIsOperator(owner, spender, isOperator);
        assertEq(token.isOperator(owner, spender), isOperator);
    }

    function test_fuzzing_transferFrom_self(address from, address to, uint256 tokenId) public {
        _mint(from, tokenId);
        vm.prank(from);
        assertTrue(token.transferFrom(from, to, tokenId, 1));

        if (from != to) {
            assertEq(token.balanceOf(from, tokenId), 0);
        }
        assertEq(token.balanceOf(to, tokenId), 1);
    }

    function test_fuzzing_transferFrom_operator(address operator, address from, address to, uint256 tokenId) public {
        _setIsOperator(from, operator, true);
        _mint(from, tokenId);
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId, 1);
        assertTrue(token.transferFrom(from, to, tokenId, 1));

        if (from != to) {
            assertEq(token.balanceOf(from, tokenId), 0);
        }
        assertEq(token.balanceOf(to, tokenId), 1);
    }

    function test_fuzzing_transferFrom_allowance(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        uint256 allowance
    ) public {
        allowance = bound(allowance, 1, type(uint256).max);
        _approve(from, operator, tokenId, allowance);
        _mint(from, tokenId);
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId, 1);
        assertTrue(token.transferFrom(from, to, tokenId, 1));

        if (from != to) {
            assertEq(token.balanceOf(from, tokenId), 0);
        }
        assertEq(token.balanceOf(to, tokenId), 1);
        assertEq(token.allowance(from, operator, tokenId), allowance - 1);
    }

    function test_fuzzing_transfer(address from, address to, uint256 tokenId) public {
        _mint(from, tokenId);

        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId, 1);
        assertTrue(token.transfer(to, tokenId, 1));

        if (from != to) {
            assertEq(token.balanceOf(from, tokenId), 0);
        }
        assertEq(token.balanceOf(to, tokenId), 1);
    }

    function test_fuzzing_approve(address owner, address spender, uint256 tokenId, uint256 amount) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(owner, spender, tokenId, amount);
        assertTrue(token.approve(spender, tokenId, amount));

        assertEq(token.allowance(owner, spender, tokenId), amount);
    }

    function test_fuzzing_setOperator(address owner, address operator, bool approved) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit OperatorSet(owner, operator, approved);
        assertTrue(token.setOperator(operator, approved));
        assertEq(token.isOperator(owner, operator), approved);
    }

    function getCode() internal returns (bytes memory) {
        string[] memory args = new string[](3);
        args[0] = "huffc";
        args[1] = "-b";
        args[2] = "src/NFT6909.huff";
        return vm.ffi(args);
    }

    function _mint(address to, uint256 tokenId) internal {
        bytes memory pre = abi.encodePacked(uint32(0x11111111), tokenId);
        bytes32 k = keccak256(pre);
        vm.store(address(token), k, bytes32(uint256(uint160(to))));
    }

    function _approve(address owner, address spender, uint256 tokenId, uint256 allowance) internal {
        bytes memory pre = abi.encodePacked(uint32(0x22222222), tokenId, owner, spender);
        assertEq(pre.length, 0x4c);
        bytes32 k = keccak256(pre);
        vm.store(address(token), k, bytes32(allowance));
    }

    function _setIsOperator(address owner, address spender, bool isOperator) internal {
        bytes memory pre = abi.encodePacked(uint32(0x33333333), owner, spender);
        bytes32 k = keccak256(pre);
        vm.store(address(token), k, bytes32(isOperator ? uint256(1) : uint256(0)));
    }
}
