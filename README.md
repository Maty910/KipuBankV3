# KipuBankV3

Aplicación DeFi avanzada que permite a los usuarios depositar cualquier token soportado por Uniswap V2, realizando swaps automáticos a USDC y gestionando balances con límites de capacidad.

Mensaje para Jimy: Ya puse solucionar el error. Lo que sucedía era que en mi archivo .env el link que tenía era de la mainnet y no de la red de sepolia. Cambié eso y se solucionó.
Adjunto links solicitados. Muchas gracias por todo!

- **Repositorio**: https://github.com/Maty910/KipuBankV3
- **Contrato Verificado**: https://sepolia.etherscan.io/address/0xb8634997588fb56c0178a07fc358cc40e5cd5086

## Descripción

KipuBankV3 es una evolución de KipuBankV2 que integra Uniswap V2 para ofrecer:

- **Depósitos multi-token**: Acepta ETH nativo, USDC y cualquier ERC20 con par en Uniswap V2
- **Swaps automáticos**: Convierte todos los depósitos a USDC de forma transparente
- **Bank Cap**: Límite máximo de fondos para gestión de riesgo
- **Control de acceso**: Sistema de ownership para funciones administrativas

## Mejoras Implementadas

### 1. Integración con Uniswap V2
- Swaps automáticos de tokens a USDC usando `IUniswapV2Router02`
- Rutas optimizadas: Token → USDC (directo) o Token → WETH → USDC
- Protección contra slippage configurable (1% por defecto)

### 2. Gestión de Liquidez
- **Bank Cap**: Límite total de 10,000 USDC para controlar exposición
- Validación pre-swap para evitar exceder el límite
- Balance consolidado en USDC para simplificar contabilidad

### 3. Seguridad
- ReentrancyGuard en funciones críticas
- Custom errors para optimización de gas
- Validaciones exhaustivas en cada operación

## Arquitectura

```
┌─────────────┐
│   Usuario   │
└──────┬──────┘
       │ deposit(token, amount)
       ▼
┌─────────────────────────┐
│    KipuBankV3           │
│                         │
│  ┌──────────────────┐   │
│  │ 1. Validaciones  │   │
│  │ 2. Swap a USDC   │◄──┼─► Uniswap V2 Router
│  │ 3. Check BankCap │   │
│  │ 4. Actualizar    │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

## Despliegue

### Contrato Verificado

- **Red**: Sepolia Testnet
- **Dirección**: `0xB8634997588Fb56C0178A07fC358CC40E5cD5086`
- **Etherscan**: https://sepolia.etherscan.io/address/0xb8634997588fb56c0178a07fc358cc40e5cd5086
- **Owner**: `0x84F1208BE50eb8191Ff76FaEe230114ea18E28ac`

### Configuración

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Sepolia USDC |
| Bank Cap | 10,000 USDC | Límite máximo |
| Router | `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008` | Uniswap V2 Router |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | Wrapped ETH |
| Slippage | 1% (100 bps) | Tolerancia de slippage |
| Deadline | 300 seg | Tiempo límite para swaps |

### Instrucciones de Despliegue

```bash
# 1. Clonar repositorio
git clone https://github.com/Maty910/KipuBankV3.git
cd KipuBankV3

# 2. Instalar dependencias
forge install

# 3. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus claves

# 4. Compilar
forge build

# 5. Ejecutar tests
forge test -vvv

# 6. Verificar cobertura
forge coverage --report summary

# 7. Deploy
source .env
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv
```

## Interacción con el Contrato

### Depositar ETH
```solidity
// Enviar ETH directamente
kipuBank.deposit{value: 0.1 ether}(address(0), 0);
```

### Depositar USDC
```solidity
// 1. Aprobar
usdc.approve(address(kipuBank), 100e6); // 100 USDC

// 2. Depositar
kipuBank.deposit(address(usdc), 100e6);
```

### Depositar cualquier token ERC20
```solidity
// 1. Aprobar token
token.approve(address(kipuBank), amount);

// 2. Depositar (se swapeará a USDC automáticamente)
kipuBank.deposit(address(token), amount);
```

### Retirar fondos
```solidity
// Retirar 50 USDC
kipuBank.withdraw(50e6);
```

### Consultar balance
```solidity
uint256 balance = kipuBank.balances(msg.sender);
```

## Decisiones de Diseño

### 1. Consolidación en USDC
**Decisión**: Convertir todos los depósitos a USDC.
- ✅ **Pro**: Simplifica contabilidad, elimina exposición a volatilidad de múltiples tokens
- ⚠️ **Con**: Usuarios pagan gas del swap, posible slippage en conversiones

### 2. Bank Cap Pre-Swap
**Decisión**: Validar límite antes del swap con estimación.
- ✅ **Pro**: Previene exceder límite por swaps favorables
- ⚠️ **Con**: Puede rechazar depósitos válidos si el precio empeora durante el swap

### 3. Slippage Fijo
**Decisión**: 1% de slippage para todos los swaps.
- ✅ **Pro**: Simplicidad, protección contra MEV
- ⚠️ **Con**: Puede ser insuficiente para tokens de baja liquidez

### 4. Path Selection Automático
**Decisión**: Si no existe par directo Token-USDC, usar Token-WETH-USDC.
- ✅ **Pro**: Maximiza tokens compatibles
- ⚠️ **Con**: Mayor gas cost y slippage en ruta indirecta

## Testing

### Cobertura de Pruebas

```bash
forge coverage --report summary
```

**Objetivo**: ≥ 50% de cobertura de código

### Casos de Prueba Implementados

- ✅ Depósito de ETH nativo
- ✅ Depósito de USDC directo
- ✅ Depósito de token ERC20 con swap
- ✅ Retiro de fondos
- ✅ Validación de bank cap
- ✅ Control de acceso (onlyOwner)
- ✅ Manejo de errores (revert cases)
- ✅ Slippage protection

### Ejecutar Tests

```bash
# Tests básicos
forge test

# Tests con logs detallados
forge test -vvv

# Test específico
forge test --match-test testDepositETH -vvv

# Gas report
forge test --gas-report
```

## Métricas

- **Solidity**: 0.8.20
- **Framework**: Foundry
- **Gas Optimizado**: Custom errors, minimal storage
- **Test Coverage**: ≥50% (verificar con `forge coverage`)
- **Deployment Cost**: ~0.0012 ETH en Sepolia

## Dependencias

- OpenZeppelin Contracts 5.0.0
  - `Ownable`: Control de acceso
  - `ReentrancyGuard`: Protección contra reentrancy
- Uniswap V2 Core/Periphery
  - Router para swaps
  - Interfaces estándar

## Contribuciones

Este proyecto es parte del examen final del Curso de Desarrollador Ethereum de EthKipu.


---

**Desarrollado por**: Matías Chacón  
**Red**: Sepolia Testnet  
**Fecha**: Noviembre 2025
