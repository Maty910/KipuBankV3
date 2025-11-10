ENTREGA PROYECTO FINAL - KipuBankV3

Repositorio: https://github.com/Maty910/KipuBankV3

Contratos implementados:
- src/KipuBankV3.sol (Integración Uniswap V2)
- src/KipuBankV2Corrected.sol (Correcciones del profesor aplicadas)

Tests:
- test/KipuBankV3.t.sol

Script de deployment:
- script/Deploy.s.sol (Listo para Sepolia)

Deployment:
- Simulación exitosa en dirección: 0xfC680769076358E7151d8152ccC5983E1aCc2c14
- Deployment real pendiente: esperando fondos de faucet de Sepolia
- Comando de deployment: forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

Funcionalidades implementadas:
✅ Depósito de ETH (convertido a USDC)
✅ Depósito de USDC directo
✅ Depósito de tokens ERC20 (swap automático a USDC)
✅ Retiros en USDC
✅ Bank Cap respetado
✅ Slippage protection
✅ ReentrancyGuard
✅ Access Control (owner)

Correcciones V2 aplicadas:
✅ withdrawLimit immutable
✅ bankCap considera USD con oracle
✅ Funciones private implementadas
✅ depositToken sigue CEI pattern
✅ ReentrancyGuard presente
