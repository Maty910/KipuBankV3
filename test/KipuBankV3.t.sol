// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC para testing
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**6); // 1M USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

// Mock WETH para testing
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
        _mint(msg.sender, 1000 * 10**18); // 1000 WETH
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
        
        // Deploy bank (necesitarás addresses reales en testnet)
        // Por ahora usamos mocks
        vm.skip(true); // Skipear hasta que tengas addresses reales
    }
    
    function testDepositUSDC() public {
        // TODO: Implementar test de depósito USDC
    }
    
    function testWithdrawUSDC() public {
        // TODO: Implementar test de retiro USDC
    }
}
