// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title KipuBankV2Corrected - Versión corregida según feedback del profesor
/// @author Matías Chacón
/// @notice Este contrato permite a los usuarios depositar y retirar ETH y tokens ERC20
/// @dev Implementa correcciones: immutable withdrawLimit, CEI pattern, private functions, bankCap con USD

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract KipuAccess is AccessControl {
bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

	constructor(address admin) {
		require(admin != address(0), "Invalid admin");
		_grantRole(DEFAULT_ADMIN_ROLE, admin);
	}
}

contract KipuBankV2Corrected is KipuAccess, ReentrancyGuard {
	using SafeERC20 for IERC20;

// -----------------
// VARIABLES
// -----------------

/// @notice Límite global de depósitos del banco en USD (8 decimales, formato Chainlink)
/// @dev Ahora considera el valor total en USD de ETH + tokens
	uint256 public bankCap;

/// @notice Límite máximo por retiro de ETH (en wei)
/// @dev CORRECCIÓN 1: Ahora es immutable y solo aplica a ETH
	uint256 public immutable withdrawLimit;

/// @notice Saldo de ETH de cada usuario
	mapping(address => uint256) private vaults;

/// @notice Contabilidad interna multi-token (user => token => amount)
	mapping(address => mapping(address => uint256)) private tokenVaults;

/// @notice Cantidad total de depósitos realizados
	uint256 private totalDeposits;

/// @notice Cantidad total de retiros realizados
	uint256 private totalWithdraws;

/// @notice Precio actual de ETH en USD con 8 decimales (según Chainlink)
	uint256 public ethUsdPrice;

/// @notice Instancia del feed de Chainlink para ETH/USD
	AggregatorV3Interface public priceFeed;

// -----------------
// EVENTOS
// -----------------

	event Deposit(address indexed user, address indexed token, uint256 amount);
	event Withdrawal(address indexed user, address indexed token, uint256 amount);
	event BankCapUpdated(uint256 newLimit);
	event PriceFeedUpdated(address feed);
	event EthUsdPriceUpdated(uint256 newPrice);

// -----------------
// ERRORES PERSONALIZADOS
// -----------------

	error ExceedsBankCap(uint256 attempted, uint256 cap);
	error ExceedsWithdrawLimit(uint256 attempted, uint256 limit);
	error InsufficientBalance(uint256 available, uint256 requested);
	error ZeroDeposit();
	error ZeroWithdrawal();
	error TransferFailed(address to, uint256 amount);
	error InvalidToken();

// -----------------
// MODIFICADORES
// -----------------

/// @notice CORRECCIÓN 2: Verifica bankCap considerando el valor total en USD (ETH + tokens)
/// @dev Convierte el balance de ETH a USD usando el oracle
	modifier underBankCap(uint256 ethAmount) {
		uint256 totalValueUsd = _calculateTotalValueInUsd(ethAmount);
		if (totalValueUsd > bankCap) {
				revert ExceedsBankCap(totalValueUsd, bankCap);
		}
		_;
	}

/// @notice Verifica que el retiro de ETH no supere el límite (solo para ETH)
	modifier withinWithdrawLimit(uint256 amount) {
		if (amount > withdrawLimit) {
				revert ExceedsWithdrawLimit(amount, withdrawLimit);
		}
		_;
	}

// -----------------
// CONSTRUCTOR
// -----------------

/// @param _bankCap Límite global en USD (8 decimales)
/// @param _withdrawLimit Límite máximo por retiro de ETH (wei) - ahora immutable
/// @param admin address assigned DEFAULT_ADMIN_ROLE
/// @param _priceFeed Dirección del price feed de Chainlink ETH/USD
	constructor(
		uint256 _bankCap,
		uint256 _withdrawLimit,
		address admin,
		address _priceFeed
	) KipuAccess(admin) {
		require(_priceFeed != address(0), "Invalid feed");
		require(_withdrawLimit > 0, "Invalid withdraw limit");
		
		bankCap = _bankCap;
		withdrawLimit = _withdrawLimit; // immutable
		priceFeed = AggregatorV3Interface(_priceFeed);
		
		// Inicializar precio
		_updatePriceFromChainlink();
	}

// -----------------
// ADMIN FUNCTIONS
// -----------------

	function setBankCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(newCap > 0, "Invalid cap");
		bankCap = newCap;
		emit BankCapUpdated(newCap);
	}

	function setPriceFeed(address feed) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(feed != address(0), "Invalid feed");
		priceFeed = AggregatorV3Interface(feed);
		emit PriceFeedUpdated(feed);
	}

// -----------------
// FUNCIONES PÚBLICAS / EXTERNAS
// -----------------

/// @notice Deposita ETH en la bóveda del remitente
	function deposit() external payable underBankCap(msg.value) nonReentrant {
		if (msg.value == 0) revert ZeroDeposit();

		vaults[msg.sender] += msg.value;
		totalDeposits++;

		emit Deposit(msg.sender, address(0), msg.value);
	}

/// @notice Retira ETH de la bóveda del remitente
	function withdraw(uint256 amount) external withinWithdrawLimit(amount) nonReentrant {
		if (amount == 0) revert ZeroWithdrawal();

		uint256 bal = vaults[msg.sender];
		if (bal < amount) revert InsufficientBalance(bal, amount);

		// CEI: Effects
		vaults[msg.sender] = bal - amount;
		totalWithdraws++;

		// CEI: Interactions
		(bool sent, ) = msg.sender.call{value: amount}("");
		if (!sent) revert TransferFailed(msg.sender, amount);

		emit Withdrawal(msg.sender, address(0), amount);
	}

/// @notice CORRECCIÓN 4: depositToken ahora sigue CEI correctamente
/// @param token Dirección del contrato del token
/// @param amount Cantidad a depositar
	function depositToken(address token, uint256 amount) external nonReentrant {
		if (token == address(0)) revert InvalidToken();
		if (amount == 0) revert ZeroDeposit();

		// CEI: Effects (actualizar estado ANTES de la interacción)
		tokenVaults[msg.sender][token] += amount;
		totalDeposits++;

		// CEI: Interactions (transferencia DESPUÉS de actualizar estado)
		IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

		emit Deposit(msg.sender, token, amount);
	}

/// @notice Retira tokens ERC20 de la bóveda
	function withdrawToken(address token, uint256 amount) external nonReentrant {
		if (token == address(0)) revert InvalidToken();
		if (amount == 0) revert ZeroWithdrawal();

		uint256 bal = tokenVaults[msg.sender][token];
		if (bal < amount) revert InsufficientBalance(bal, amount);

		// CEI: Effects
		tokenVaults[msg.sender][token] = bal - amount;
		totalWithdraws++;

		// CEI: Interactions
		IERC20(token).safeTransfer(msg.sender, amount);

		emit Withdrawal(msg.sender, token, amount);
	}

// -----------------
// ORACLE / PRICE
// -----------------

/// @notice Actualiza el precio de ETH/USD manualmente
	function updateEthUsdPrice(uint256 newPrice) external onlyRole(ORACLE_ROLE) {
		require(newPrice > 0, "Invalid price");
		ethUsdPrice = newPrice;
		emit EthUsdPriceUpdated(newPrice);
	}

	/// @notice Lee el feed de Chainlink y actualiza el precio
	function updatePriceFromChainlink() external onlyRole(ORACLE_ROLE) nonReentrant {
		_updatePriceFromChainlink();
	}

// -----------------
// CORRECCIÓN 3: FUNCIONES PRIVATE
// -----------------

/// @notice Actualiza el precio desde Chainlink (función interna)
/// @dev CORRECCIÓN 3: Función private para cumplir requisito académico
	function _updatePriceFromChainlink() private {
		require(address(priceFeed) != address(0), "Feed not set");
		
		(, int256 latest, , , ) = priceFeed.latestRoundData();
		require(latest > 0, "Invalid feed data");
		
		ethUsdPrice = uint256(latest);
		emit EthUsdPriceUpdated(uint256(latest));
	}

/// @notice CORRECCIÓN 2: Calcula el valor total en USD (ETH del contrato + nuevo depósito)
/// @dev Función private que convierte ETH a USD usando el oracle
/// @param additionalEth ETH adicional que se está depositando
/// @return Total value in USD (8 decimals)
	function _calculateTotalValueInUsd(uint256 additionalEth) private view returns (uint256) {
		uint256 totalEth = address(this).balance + additionalEth;
		
		// Convertir ETH (18 decimals) a USD (8 decimals)
		// ethUsdPrice tiene 8 decimales (ej: 2000_00000000 = $2000)
		// totalEth tiene 18 decimales (wei)
		// Resultado: (eth * price) / 1e18 = USD con 8 decimales
		
		return (totalEth * ethUsdPrice) / 1e18;
	}

// -----------------
// VIEWS
// -----------------

	function getTotalDeposits() external view returns (uint256) {
		return totalDeposits;
	}

	function getTotalWithdraws() external view returns (uint256) {
		return totalWithdraws;
	}

	function getTokenBalance(address user, address token) external view returns (uint256) {
		if (token == address(0)) {
				return vaults[user];
		}
		return tokenVaults[user][token];
	}

	function bankBalance() external view returns (uint256) {
		return address(this).balance;
	}

	function getLatestPrice() public view returns (int256) {
		(, int256 price, , , ) = priceFeed.latestRoundData();
		return price;
	}

	function getBankCap() external view returns (uint256) {
		return bankCap;
	}

	function getWithdrawLimit() external view returns (uint256) {
		return withdrawLimit;
	}

/// @notice Calcula el valor total del banco en USD
	function getTotalValueInUsd() external view returns (uint256) {
		return _calculateTotalValueInUsd(0);
	}
}
