// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KipuBankV3.sol";

/// @title Script de Despliegue de KipuBankV3
/// @notice Despliega KipuBankV3 en la red configurada
contract DeployScript is Script {
    function run() external {
        // Obtener private key del .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Parámetros de despliegue para Sepolia
        address usdcAddress = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC Sepolia
        address routerAddress = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008; // Uniswap V2 Router Sepolia
        address wethAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH Sepolia
        
        uint256 bankCap = 10000 * 10**6; // 10,000 USDC
        uint256 slippageTolerance = 100; // 1%
        uint256 deadline = 300; // 5 minutos
        
        // Deploy del contrato
        KipuBankV3 bank = new KipuBankV3(
            deployer,           // owner
            usdcAddress,        // USDC
            bankCap,            // bank cap
            routerAddress,      // Uniswap router
            wethAddress,        // WETH
            slippageTolerance,  // slippage tolerance
            deadline            // deadline
        );
        
        console.log("===========================================");
        console.log("KipuBankV3 deployed at:", address(bank));
        console.log("===========================================");
        console.log("Owner:", bank.owner());
        console.log("USDC:", address(bank.usdc()));
        console.log("Bank Cap:", bank.bankCap());
        console.log("Router:", bank.uniswapRouter());
        console.log("WETH:", bank.weth());
        console.log("Slippage Tolerance:", bank.slippageTolerance());
        console.log("Deadline:", bank.deadline());
        console.log("===========================================");
        
        vm.stopBroadcast();
    }
}
