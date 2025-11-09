// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

// Mock WETH
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
        _mint(msg.sender, 1_000 * 10 ** decimals());
    }
}

contract KipuBankV3Test is Test {
    KipuBankV3 public bank;
    MockUSDC public usdc;
    MockWETH public weth;

    address admin = address(1);
    address user = address(2);

    function setUp() public {
        // Deploy mocks
        usdc = new MockUSDC();
        weth = new MockWETH();

        // Deploy KipuBankV3 con router y factory "dummy" para test
        bank = new KipuBankV3(
            address(usdc),
            address(weth),
            address(0x10), // fake router
            1_000_000 * 10 ** 6 // bankCap
        );

        vm.label(address(bank), "KipuBankV3");
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        vm.label(user, "User");
    }

    function testDepositUSDC() public {
        uint256 amount = 100 * 10 ** 6;
        usdc.transfer(user, amount);

        vm.startPrank(user);
        usdc.approve(address(bank), amount);
        bank.depositToken(address(usdc), amount);
        vm.stopPrank();

        uint256 userBalance = bank.balanceOf(user);
        assertEq(userBalance, amount, "User USDC balance not credited properly");
    }

    function testWithdrawUSDC() public {
        uint256 amount = 100 * 10 ** 6;
        usdc.transfer(user, amount);

        vm.startPrank(user);
        usdc.approve(address(bank), amount);
        bank.depositToken(address(usdc), amount);
        bank.withdraw(amount);
        vm.stopPrank();

        uint256 userBalance = bank.balanceOf(user);
        assertEq(userBalance, 0, "User balance not reset after withdraw");
    }

    // Solo prueba de que el bankCap funciona
    function testCannotExceedBankCap() public {
        uint256 amount = 2_000_000 * 10 ** 6; // más que bankCap
        usdc.transfer(user, amount);

        vm.startPrank(user);
        usdc.approve(address(bank), amount);
        vm.expectRevert();
        bank.depositToken(address(usdc), amount);
        vm.stopPrank();
    }
}