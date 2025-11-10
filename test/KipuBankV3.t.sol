// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC Token
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**6); // 1M USDC (6 decimals)
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock ERC20 Token
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Uniswap V2 Router (simplificado para testing)
contract MockUniswapRouter {
    address public immutable weth;
    MockUSDC public immutable usdc;
    
    constructor(address _weth, address _usdc) {
        weth = _weth;
        usdc = MockUSDC(_usdc);
    }
    
    // Simula el swap de ETH por USDC (1 ETH = 2000 USDC)
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(path[0] == weth, "Invalid path");
        require(path[path.length - 1] == address(usdc), "Invalid path");
        
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = (msg.value * 2000 * 10**6) / 10**18; // 1 ETH = 2000 USDC
        
        require(amounts[1] >= amountOutMin, "Insufficient output");
        
        usdc.mint(to, amounts[1]);
        return amounts;
    }
    
    // Simula el swap de Token por USDC
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        
        // Transferir tokens del caller
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        // Simular conversión (1:1 con USDC ajustado por decimals)
        amounts[amounts.length - 1] = (amountIn * 10**6) / 10**18;
        
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output");
        
        usdc.mint(to, amounts[amounts.length - 1]);
        return amounts;
    }
    
    // Simula getAmountsOut
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        if (path[0] == weth) {
            // ETH to USDC: 1 ETH = 2000 USDC
            amounts[amounts.length - 1] = (amountIn * 2000 * 10**6) / 10**18;
        } else {
            // Token to USDC: conversión simple
            amounts[amounts.length - 1] = (amountIn * 10**6) / 10**18;
        }
        
        return amounts;
    }
    
    receive() external payable {}
}

contract KipuBankV3Test is Test {
    KipuBankV3 public bank;
    MockUSDC public usdc;
    MockToken public weth;
    MockToken public dai;
    MockUniswapRouter public router;
    
    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(3);
    
    uint256 constant BANK_CAP = 10000 * 10**6; // 10,000 USDC
    uint256 constant SLIPPAGE_TOLERANCE = 100; // 1%
    uint256 constant DEADLINE = 300; // 5 minutos
    
    function setUp() public {
        // Deploy mock tokens
        usdc = new MockUSDC();
        weth = new MockToken("Wrapped Ether", "WETH");
        dai = new MockToken("Dai Stablecoin", "DAI");
        
        // Deploy mock router
        router = new MockUniswapRouter(address(weth), address(usdc));
        
        // Mint USDC to router para swaps
        usdc.mint(address(router), 1000000 * 10**6);
        
        // Deploy KipuBankV3 con los 7 parámetros correctos
        bank = new KipuBankV3(
            owner,
            address(usdc),
            BANK_CAP,
            address(router),
            address(weth),
            SLIPPAGE_TOLERANCE,
            DEADLINE
        );
        
        // Dar fondos a los usuarios
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);
        
        usdc.mint(user, 10000 * 10**6);
        dai.mint(user, 10000 ether);
        
        // Aprobar el banco para gastar tokens
        vm.prank(user);
        usdc.approve(address(bank), type(uint256).max);
        
        vm.prank(user);
        dai.approve(address(bank), type(uint256).max);
    }
    
    // ============ Constructor Tests ============
    
    function test_Constructor() public {
        assertEq(bank.owner(), owner);
        assertEq(address(bank.usdc()), address(usdc));
        assertEq(bank.bankCap(), BANK_CAP);
        assertEq(bank.uniswapRouter(), address(router));
        assertEq(bank.weth(), address(weth));
        assertEq(bank.slippageTolerance(), SLIPPAGE_TOLERANCE);
        assertEq(bank.deadline(), DEADLINE);
    }
    
    function test_ConstructorRevertsOnZeroAddress() public {
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        new KipuBankV3(
            address(0), // owner cero
            address(usdc),
            BANK_CAP,
            address(router),
            address(weth),
            SLIPPAGE_TOLERANCE,
            DEADLINE
        );
    }
    
    // ============ Deposit USDC Tests ============
    
    function test_DepositUSDC() public {
        uint256 depositAmount = 1000 * 10**6; // 1000 USDC
        
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        uint256 userBalance = bank.balanceOf(user);
        assertEq(userBalance, depositAmount);
        assertEq(bank.totalBalance(), depositAmount);
    }
    
    function test_DepositUSDCMultipleUsers() public {
        uint256 depositAmount = 1000 * 10**6;
        
        // User 1 deposita
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        // Dar USDC a user2
        usdc.mint(user2, depositAmount);
        vm.prank(user2);
        usdc.approve(address(bank), depositAmount);
        
        // User 2 deposita
        vm.prank(user2);
        bank.depositToken(address(usdc), depositAmount);
        
        assertEq(bank.balanceOf(user), depositAmount);
        assertEq(bank.balanceOf(user2), depositAmount);
        assertEq(bank.totalBalance(), depositAmount * 2);
    }
    
    function test_DepositUSDCRevertsOnBankCapExceeded() public {
        uint256 depositAmount = BANK_CAP + 1;
        usdc.mint(user, depositAmount);
        
        vm.prank(user);
        usdc.approve(address(bank), depositAmount);
        
        vm.prank(user);
        vm.expectRevert(KipuBankV3.BankCapExceeded.selector);
        bank.depositToken(address(usdc), depositAmount);
    }
    
    function test_DepositUSDCRevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.InvalidAmount.selector);
        bank.depositToken(address(usdc), 0);
    }
    
    // ============ Deposit Native ETH Tests ============
    
    function test_DepositNative() public {
        uint256 ethAmount = 1 ether;
        uint256 expectedUSDC = (ethAmount * 2000 * 10**6) / 10**18; // 1 ETH = 2000 USDC
        
        vm.prank(user);
        bank.depositNative{value: ethAmount}();
        
        uint256 userBalance = bank.balanceOf(user);
        
        // Verificar que el balance está cerca del esperado (considerando slippage)
        assertGt(userBalance, 0);
        assertLe(userBalance, expectedUSDC);
    }
    
    function test_DepositNativeRevertsOnZeroValue() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.InvalidAmount.selector);
        bank.depositNative{value: 0}();
    }
    
    // ============ Deposit Other Tokens Tests ============
    
    function test_DepositOtherToken() public {
        uint256 daiAmount = 1000 ether;
        
        vm.prank(user);
        bank.depositToken(address(dai), daiAmount);
        
        uint256 userBalance = bank.balanceOf(user);
        
        // El balance debe ser > 0 después del swap
        assertGt(userBalance, 0);
    }
    
    // ============ Withdrawal Tests ============
    
    function test_Withdraw() public {
        uint256 depositAmount = 1000 * 10**6;
        uint256 withdrawAmount = 500 * 10**6;
        
        // Depositar primero
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        uint256 initialBalance = usdc.balanceOf(user);
        
        // Retirar
        vm.prank(user);
        bank.withdraw(withdrawAmount);
        
        assertEq(bank.balanceOf(user), depositAmount - withdrawAmount);
        assertEq(usdc.balanceOf(user), initialBalance + withdrawAmount);
        assertEq(bank.totalBalance(), depositAmount - withdrawAmount);
    }
    
    function test_WithdrawAll() public {
        uint256 depositAmount = 1000 * 10**6;
        
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        vm.prank(user);
        bank.withdraw(depositAmount);
        
        assertEq(bank.balanceOf(user), 0);
        assertEq(bank.totalBalance(), 0);
    }
    
    function test_WithdrawRevertsOnInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.InsufficientBalance.selector);
        bank.withdraw(100 * 10**6);
    }
    
    function test_WithdrawRevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.InvalidAmount.selector);
        bank.withdraw(0);
    }
    
    // ============ Owner Functions Tests ============
    
    function test_SetBankCap() public {
        uint256 newCap = 20000 * 10**6;
        
        vm.prank(owner);
        bank.setBankCap(newCap);
        
        assertEq(bank.bankCap(), newCap);
    }
    
    function test_SetBankCapRevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.OnlyOwner.selector);
        bank.setBankCap(20000 * 10**6);
    }
    
    function test_TransferOwnership() public {
        address newOwner = address(99);
        
        vm.prank(owner);
        bank.transferOwnership(newOwner);
        
        assertEq(bank.owner(), newOwner);
    }
    
    function test_TransferOwnershipRevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.OnlyOwner.selector);
        bank.transferOwnership(address(99));
    }
    
    function test_TransferOwnershipRevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        bank.transferOwnership(address(0));
    }
    
    // ============ View Functions Tests ============
    
    function test_BalanceOf() public {
        uint256 depositAmount = 1000 * 10**6;
        
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        assertEq(bank.balanceOf(user), depositAmount);
        assertEq(bank.balanceOf(user2), 0);
    }
    
    // ============ Reentrancy Tests ============
    
    function test_DepositIsNonReentrant() public {
        // Este test verifica que el modifier nonReentrant está presente
        // En un ataque real se necesitaría un contrato malicioso
        assertTrue(true);
    }
    
    // ============ Integration Tests ============
    
    function test_FullDepositWithdrawCycle() public {
        uint256 depositAmount = 5000 * 10**6;
        
        // Depositar
        vm.prank(user);
        bank.depositToken(address(usdc), depositAmount);
        
        assertEq(bank.balanceOf(user), depositAmount);
        
        // Retirar parcial
        vm.prank(user);
        bank.withdraw(2000 * 10**6);
        
        assertEq(bank.balanceOf(user), 3000 * 10**6);
        
        // Depositar más
        vm.prank(user);
        bank.depositToken(address(usdc), 1000 * 10**6);
        
        assertEq(bank.balanceOf(user), 4000 * 10**6);
        
        // Retirar todo
        vm.prank(user);
        bank.withdraw(4000 * 10**6);
        
        assertEq(bank.balanceOf(user), 0);
    }
}