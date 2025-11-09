// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title KipuBankV3
 * @author Matías Chacón
 * @notice Versión avanzada de KipuBank que permite depositar cualquier token soportado por Uniswap V2,
 *         convierte automáticamente los tokens a USDC, y respeta el límite del banco en USD.
 * @dev Mantiene toda la lógica de seguridad, roles, y CEI de KipuBankV2Corrected.
 */

import {KipuBankV2Corrected} from "./KipuBankV2Corrected.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract KipuBankV3 is KipuBankV2Corrected {
  using SafeERC20 for IERC20;

  // -----------------
  // VARIABLES NUEVAS
  // -----------------

  /// @notice Token USDC (utilizado como referencia del valor total)
  IERC20 public immutable USDC;

  /// @notice Router de Uniswap V2 para swaps
  IUniswapV2Router02 public immutable UNISWAP_ROUTER;

  /// @notice Dirección del token WETH usado por Uniswap
  address public immutable WETH;

  /// @notice Saldo de cada usuario expresado en USDC (unidad nativa del token)
  mapping(address => uint256) public usdcBalances;

  // -----------------
  // CONSTRUCTOR
  // -----------------

  /**
   * @param _bankCap Límite global del banco (USD con 8 decimales)
   * @param _withdrawLimit Límite máximo de retiro en ETH (wei)
   * @param admin Dirección del admin principal (AccessControl)
   * @param _priceFeed Dirección del feed de Chainlink ETH/USD
   * @param _uniswapRouter Dirección del router de Uniswap V2
   * @param _usdc Dirección del token USDC
   * @param _weth Dirección del token WETH
   */
  constructor(
    uint256 _bankCap,
    uint256 _withdrawLimit,
    address admin,
    address _priceFeed,
    address _uniswapRouter,
    address _usdc,
    address _weth
  ) KipuBankV2Corrected(_bankCap, _withdrawLimit, admin, _priceFeed) {
    require(_uniswapRouter != address(0), "Invalid router");
    require(_usdc != address(0), "Invalid USDC");
    require(_weth != address(0), "Invalid WETH");

    UNISWAP_ROUTER = IUniswapV2Router02(_uniswapRouter);
    USDC = IERC20(_usdc);
    WETH = _weth;
  }

  // -----------------
  // DEPÓSITOS
  // -----------------

  /**
   * @notice Permite depositar cualquier token soportado por Uniswap.
   * @dev Si el token no es USDC ni ETH, se intercambia automáticamente a USDC.
   *      Antes de acreditar, se verifica que el nuevo total (normalizado a 8 decimales)
   *      no supere el bankCap.
   * @param token Dirección del token a depositar (usar address(0) para ETH)
   * @param amount Cantidad a depositar (para ETH, pasar 0 y enviar value)
   */
  function depositAny(address token, uint256 amount)
    external
    payable
    nonReentrant
  {
    uint256 usdcReceived;

    if (token == address(0)) {
      // Depósito en ETH
      require(msg.value > 0, "No ETH sent");
      usdcReceived = _swapEthToUsdc(msg.value);
    } else if (token == address(USDC)) {
      // Depósito directo en USDC
      IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
      usdcReceived = amount;
    } else {
      // Depósito de otro token ERC20 soportado
      IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
      // Aprobación para router
      IERC20(token).safeIncreaseAllowance(address(UNISWAP_ROUTER), amount);
      usdcReceived = _swapTokenToUsdc(token, amount);
    }

    // Normalizar saldos a 8 decimales para comparar con bankCap (bankCap usa 8 decimales)
    uint256 currentUsdcNorm = _to8Decimals(address(USDC), USDC.balanceOf(address(this)));
    uint256 receivedNorm = _to8Decimals(address(USDC), usdcReceived);
    uint256 newTotalNorm = currentUsdcNorm + receivedNorm;

    if (newTotalNorm > bankCap) revert ExceedsBankCap(newTotalNorm, bankCap);

    // Acreditar en USDC (unidad nativa de USDC)
    usdcBalances[msg.sender] += usdcReceived;
    emit Deposit(msg.sender, token, usdcReceived);
  }

  // -----------------
  // RETIROS
  // -----------------

  /**
   * @notice Permite retirar el balance en USDC.
   * @param amount Cantidad de USDC a retirar
   */
  function withdrawUsdc(uint256 amount) external nonReentrant {
    if (amount == 0) revert ZeroWithdrawal();
    uint256 bal = usdcBalances[msg.sender];
    if (bal < amount) revert InsufficientBalance(bal, amount);

    usdcBalances[msg.sender] = bal - amount;
    USDC.safeTransfer(msg.sender, amount);

    emit Withdrawal(msg.sender, address(USDC), amount);
  }

  // -----------------
  // FUNCIONES INTERNAS DE SWAP
  // -----------------

  /// @dev Swapea ETH -> USDC via UniswapV2 (devuelve cantidad de USDC recibida, en decimals de USDC)
  function _swapEthToUsdc(uint256 amountIn) private returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = address(USDC);

    uint256[] memory amounts = UNISWAP_ROUTER.swapExactETHForTokens{value: amountIn}(
      0, // amountOutMin = 0 (en tests). En producción, usar slippage razonable.
      path,
      address(this),
      block.timestamp
    );

    return amounts[amounts.length - 1];
  }

  /// @dev Swapea tokenIn -> USDC via UniswapV2 (usa route token -> WETH -> USDC si es necesario)
  function _swapTokenToUsdc(address tokenIn, uint256 amountIn)
    private
    returns (uint256)
  {
    // Si tokenIn == WETH hacemos ruta WETH -> USDC (2 pasos)
    if (tokenIn == WETH) {
      address[] memory pathWeth = new address[](2);
      pathWeth[0] = WETH;
      pathWeth[1] = address(USDC);

      uint256[] memory amountsWeth = UNISWAP_ROUTER.swapExactTokensForTokens(
        amountIn,
        0,
        pathWeth,
        address(this),
        block.timestamp
      );

      return amountsWeth[amountsWeth.length - 1];
    }

    // Ruta token -> WETH -> USDC
    address[] memory pathToken = new address[](3);
    pathToken[0] = tokenIn;
    pathToken[1] = WETH;
    pathToken[2] = address(USDC);

    uint256[] memory amountsToken = UNISWAP_ROUTER.swapExactTokensForTokens(
      amountIn,
      0,
      pathToken,
      address(this),
      block.timestamp
    );

    return amountsToken[amountsToken.length - 1];
  }

  // -----------------
  // HELPERS
  // -----------------

  /// @dev Convierte una cantidad de token (decimales arbitrarios) a la representación con 8 decimales.
  ///      Usa IERC20Metadata.decimals(). Si el token no implementa decimals(), asume 18.
  function _to8Decimals(address token, uint256 amount) private view returns (uint256) {
    uint8 d;
    // Intentamos leer decimals; si la llamada falla reverts, esto asumirá 18 — la mayoría de tokens sí lo implementan.
    try IERC20Metadata(token).decimals() returns (uint8 dec) {
      d = dec;
    } catch {
      d = 18;
    }

    if (d == 8) return amount;
    else if (d > 8) return amount / (10 ** (d - 8));
    else return amount * (10 ** (8 - d));
  }

  // -----------------
  // VIEWS ADICIONALES
  // -----------------

  /// @notice Total de USDC que posee el contrato (unidad nativa de USDC, p.ej. 6 decimales)
  function getTotalUsdc() public view returns (uint256) {
    return USDC.balanceOf(address(this));
  }
}