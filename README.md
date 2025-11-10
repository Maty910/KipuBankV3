# ENTREGA PROYECTO FINAL - KipuBankV3

Mensaje para el profesor Jimy: Estoy teniendo un problema que no me deja realizar la transacción por falta de gas. Pero en mi cuenta de Metamask si tengo fondos SepoliaEth, pero al ver al solicitar el balance me devuelve 0. No sé si será un problema con la Private Key, porque la copio directamente desde Metamask a mi archivo .env . O si será un problema de mi código. Igualmente, seguiré intentando solucionarlo durante la semana. Espero se me tenga en cuenta y se me de de baja del curso ya que es un curso que me está gustando mucho y lo veo muy útil. Desde ya muchas gracias!

Repositorio: https://github.com/Maty910/KipuBankV3

## Descripción general

KipuBankV3 es una evolución de versiones anteriores del contrato KipuBank.
Esta versión mejora la seguridad, escalabilidad y flexibilidad del sistema.
Las principales mejoras incluyen:

Soporte para múltiples tokens ERC20.

Conversión automática a USDC al depositar, respetando límites en USD.

Control de acceso más claro (roles y ownership).

Lógica de seguridad reforzada (reentrancy guard, pausabilidad).

Tests ampliados con Foundry.

El objetivo es lograr un contrato más robusto y adaptable, manteniendo las buenas prácticas de desarrollo seguro en Solidity.

## Despliegue e interacción
Requisitos

Foundry instalado.

RPC de red (por ejemplo, Sepolia o testnet elegida).

Clave privada con fondos de gas.

Pasos
git clone https://github.com/Maty910/KipuBankV3.git
cd KipuBankV3
forge build
forge test
forge script script/DeployKipuBankV3.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast


Una vez desplegado, verificar el contrato en Etherscan/Blockscout y copiar la URL de verificación.

## Decisiones de diseño

Se priorizó la seguridad y claridad del código sobre micro-optimizaciones de gas.

El uso de USDC como token de reserva simplifica la gestión del valor.

Se implementó pausabilidad para responder ante incidentes.

Se mantuvo un solo owner/admin para reducir complejidad (futuro: multisig).

## Análisis de amenazas

Debilidades detectadas:

Riesgo de reentrancy si se amplían funciones sin cuidado.

Dependencia de oráculos para la conversión a USDC.

Rol del admin centralizado.


Cobertura de pruebas: ~80 % (principalmente depósitos, retiros y pausabilidad).
Método: forge test con escenarios positivos y negativos.
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
# ENTREGA PROYECTO FINAL - KipuBankV3

Repositorio: https://github.com/Maty910/KipuBankV3

## Descripción general

KipuBankV3 es una evolución de versiones anteriores del contrato KipuBank.
Esta versión mejora la seguridad, escalabilidad y flexibilidad del sistema.
Las principales mejoras incluyen:

Soporte para múltiples tokens ERC20.

Conversión automática a USDC al depositar, respetando límites en USD.

Control de acceso más claro (roles y ownership).

Lógica de seguridad reforzada (reentrancy guard, pausabilidad).

Tests ampliados con Foundry.

El objetivo es lograr un contrato más robusto y adaptable, manteniendo las buenas prácticas de desarrollo seguro en Solidity.

## Despliegue e interacción
Requisitos

Foundry instalado.

RPC de red (por ejemplo, Sepolia o testnet elegida).

Clave privada con fondos de gas.

Pasos
git clone https://github.com/Maty910/KipuBankV3.git
cd KipuBankV3
forge build
forge test
forge script script/DeployKipuBankV3.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast


Una vez desplegado, verificar el contrato en Etherscan/Blockscout y copiar la URL de verificación.

## Decisiones de diseño

Se priorizó la seguridad y claridad del código sobre micro-optimizaciones de gas.

El uso de USDC como token de reserva simplifica la gestión del valor.

Se implementó pausabilidad para responder ante incidentes.

Se mantuvo un solo owner/admin para reducir complejidad (futuro: multisig).

## Análisis de amenazas

Debilidades detectadas:

Riesgo de reentrancy si se amplían funciones sin cuidado.

Dependencia de oráculos para la conversión a USDC.

Rol del admin centralizado.


Cobertura de pruebas: ~80 % (principalmente depósitos, retiros y pausabilidad).
Método: forge test con escenarios positivos y negativos.
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
