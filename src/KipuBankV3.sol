// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title KipuBankV3
/// @author Tu Nombre
/// @notice Banco DeFi que acepta múltiples tokens y los convierte a USDC usando Uniswap V2
/// @dev Integra con Uniswap V2 Router para intercambios automáticos de tokens
contract KipuBankV3 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============
    
    /// @notice Dirección del propietario del contrato
    address public owner;
    
    /// @notice Token USDC utilizado como moneda base del banco
    IERC20 public immutable usdc;
    
    /// @notice Límite máximo total que puede almacenar el banco en USDC
    uint256 public bankCap;
    
    /// @notice Router de Uniswap V2 para realizar swaps
    address public immutable uniswapRouter;
    
    /// @notice Dirección del token WETH (Wrapped Ether)
    address public immutable weth;
    
    /// @notice Tolerancia de slippage en basis points (100 = 1%)
    uint256 public slippageTolerance;
    
    /// @notice Tiempo límite para transacciones en segundos
    uint256 public deadline;
    
    /// @notice Balance en USDC de cada usuario
    mapping(address => uint256) public balances;
    
    /// @notice Balance total del banco en USDC
    uint256 public totalBalance;

    // ============ Events ============
    
    /// @notice Se emite cuando un usuario deposita tokens
    /// @param user Dirección del usuario
    /// @param token Dirección del token depositado
    /// @param amountDeposited Cantidad depositada del token original
    /// @param usdcCredited Cantidad acreditada en USDC
    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amountDeposited,
        uint256 usdcCredited
    );
    
    /// @notice Se emite cuando un usuario retira USDC
    /// @param user Dirección del usuario
    /// @param amount Cantidad retirada en USDC
    event Withdrawal(address indexed user, uint256 amount);
    
    /// @notice Se emite cuando se actualiza el bank cap
    /// @param newCap Nuevo límite del banco
    event BankCapUpdated(uint256 newCap);
    
    /// @notice Se emite cuando cambia el propietario
    /// @param newOwner Nueva dirección del propietario
    event OwnershipTransferred(address indexed newOwner);

    // ============ Errors ============
    
    error OnlyOwner();
    error BankCapExceeded();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidAddress();
    error SwapFailed();
    error TransferFailed();

    // ============ Modifiers ============
    
    /// @notice Restringe función solo al propietario
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // ============ Constructor ============
    
    /// @notice Inicializa el contrato KipuBankV3
    /// @param _owner Dirección del propietario inicial
    /// @param _usdc Dirección del token USDC
    /// @param _bankCap Límite máximo del banco en USDC
    /// @param _uniswapRouter Dirección del router de Uniswap V2
    /// @param _weth Dirección del token WETH
    /// @param _slippageTolerance Tolerancia de slippage (en basis points, ej: 100 = 1%)
    /// @param _deadline Tiempo límite para transacciones en segundos
    constructor(
        address _owner,
        address _usdc,
        uint256 _bankCap,
        address _uniswapRouter,
        address _weth,
        uint256 _slippageTolerance,
        uint256 _deadline
    ) {
        if (_owner == address(0) || _usdc == address(0) || _uniswapRouter == address(0) || _weth == address(0)) {
            revert InvalidAddress();
        }
        
        owner = _owner;
        usdc = IERC20(_usdc);
        bankCap = _bankCap;
        uniswapRouter = _uniswapRouter;
        weth = _weth;
        slippageTolerance = _slippageTolerance;
        deadline = _deadline;
    }

    // ============ External Functions ============
    
    /// @notice Deposita ETH nativo, lo convierte a USDC y acredita al usuario
    /// @dev Utiliza Uniswap V2 para intercambiar ETH por USDC
    function depositNative() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        
        // Swap ETH -> USDC usando Uniswap V2
        uint256 usdcReceived = _swapNativeForUSDC(msg.value);
        
        // Verificar bank cap
        if (totalBalance + usdcReceived > bankCap) revert BankCapExceeded();
        
        // Actualizar balances
        balances[msg.sender] += usdcReceived;
        totalBalance += usdcReceived;
        
        emit Deposit(msg.sender, address(0), msg.value, usdcReceived);
    }
    
    /// @notice Deposita un token ERC20, lo convierte a USDC si es necesario
    /// @param token Dirección del token a depositar
    /// @param amount Cantidad del token a depositar
    function depositToken(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert InvalidAddress();
        
        // Transferir tokens del usuario al contrato
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        uint256 usdcReceived;
        
        // Si el token es USDC, acreditar directamente
        if (token == address(usdc)) {
            usdcReceived = amount;
        } else {
            // Si es otro token, intercambiar por USDC
            usdcReceived = _swapTokenForUSDC(token, amount);
        }
        
        // Verificar bank cap
        if (totalBalance + usdcReceived > bankCap) revert BankCapExceeded();
        
        // Actualizar balances
        balances[msg.sender] += usdcReceived;
        totalBalance += usdcReceived;
        
        emit Deposit(msg.sender, token, amount, usdcReceived);
    }
    
    /// @notice Retira USDC del balance del usuario
    /// @param amount Cantidad de USDC a retirar
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        
        // Actualizar balances
        balances[msg.sender] -= amount;
        totalBalance -= amount;
        
        // Transferir USDC al usuario
        usdc.safeTransfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /// @notice Consulta el balance en USDC de un usuario
    /// @param user Dirección del usuario
    /// @return Balance en USDC del usuario
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
    
    /// @notice Actualiza el límite máximo del banco
    /// @param newCap Nuevo bank cap
    function setBankCap(uint256 newCap) external onlyOwner {
        bankCap = newCap;
        emit BankCapUpdated(newCap);
    }
    
    /// @notice Transfiere la propiedad del contrato
    /// @param newOwner Nueva dirección del propietario
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }

    // ============ Internal Functions ============
    
    /// @notice Intercambia ETH por USDC usando Uniswap V2
    /// @param amountIn Cantidad de ETH a intercambiar
    /// @return Cantidad de USDC recibida
    function _swapNativeForUSDC(uint256 amountIn) internal returns (uint256) {
        // Preparar el path: ETH -> WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(usdc);
        
        // Calcular mínimo de salida considerando slippage
        uint256 minAmountOut = _getMinAmountOut(amountIn, path);
        
        // Realizar el swap
        // swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        (bool success, bytes memory data) = uniswapRouter.call{value: amountIn}(
            abi.encodeWithSignature(
                "swapExactETHForTokens(uint256,address[],address,uint256)",
                minAmountOut,
                path,
                address(this),
                block.timestamp + deadline
            )
        );
        
        if (!success) revert SwapFailed();
        
        // Decodificar la respuesta (array de amounts)
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        return amounts[amounts.length - 1];
    }
    
    /// @notice Intercambia un token ERC20 por USDC usando Uniswap V2
    /// @param token Dirección del token a intercambiar
    /// @param amountIn Cantidad del token a intercambiar
    /// @return Cantidad de USDC recibida
    function _swapTokenForUSDC(address token, uint256 amountIn) internal returns (uint256) {
        // Aprobar el router para gastar los tokens
        IERC20(token).safeIncreaseAllowance(uniswapRouter, amountIn);
        
        // Preparar el path: Token -> USDC (o Token -> WETH -> USDC si no hay par directo)
        address[] memory path = _getSwapPath(token);
        
        // Calcular mínimo de salida considerando slippage
        uint256 minAmountOut = _getMinAmountOut(amountIn, path);
        
        // Realizar el swap
        // swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        (bool success, bytes memory data) = uniswapRouter.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                amountIn,
                minAmountOut,
                path,
                address(this),
                block.timestamp + deadline
            )
        );
        
        if (!success) revert SwapFailed();
        
        // Decodificar la respuesta (array de amounts)
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        return amounts[amounts.length - 1];
    }
    
    /// @notice Determina el mejor path para el swap
    /// @param token Token de entrada
    /// @return path Array con la ruta del swap
    function _getSwapPath(address token) internal view returns (address[] memory) {
        // Intentar path directo: Token -> USDC
        address[] memory directPath = new address[](2);
        directPath[0] = token;
        directPath[1] = address(usdc);
        
        // Por simplicidad, siempre usar path directo
        // En producción, se debería verificar si existe el par
        return directPath;
    }
    
    /// @notice Calcula el mínimo de salida considerando slippage
    /// @param amountIn Cantidad de entrada
    /// @param path Ruta del swap
    /// @return Cantidad mínima de salida
    function _getMinAmountOut(uint256 amountIn, address[] memory path) internal view returns (uint256) {
        // Obtener amounts esperados del router
        (bool success, bytes memory data) = uniswapRouter.staticcall(
            abi.encodeWithSignature(
                "getAmountsOut(uint256,address[])",
                amountIn,
                path
            )
        );
        
        if (!success) revert SwapFailed();
        
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        uint256 expectedOut = amounts[amounts.length - 1];
        
        // Aplicar tolerancia de slippage
        return (expectedOut * (10000 - slippageTolerance)) / 10000;
    }
    
    /// @notice Permite recibir ETH
    receive() external payable {}
}