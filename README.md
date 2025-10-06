# HyperEVM Limit Order Book

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.25-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Test Coverage](https://img.shields.io/badge/Test%20Coverage-95.35%25-brightgreen.svg)](#testing)

A decentralized limit order book smart contract designed for HyperEVM, enabling users to place limit orders that are executed by off-chain bots when price conditions are met.

## 🌟 Features

- **On-chain Order Management**: Secure storage of limit orders on the blockchain
- **Off-chain Execution**: Permissionless bot execution with optional authorization controls
- **Flexible Authorization**: Support for both permissionless and authorized executor models
- **Comprehensive Testing**: 95%+ test coverage with unit and fuzz tests
- **Gas Optimized**: Efficient storage patterns and minimal gas consumption
- **Reentrancy Protection**: Built-in security against reentrancy attacks

## 🏗️ Architecture

### User Flow

1. **Order Placement**: Users place limit orders on-chain → emits `OrderPlaced` event
2. **Off-chain Monitoring**: Bots listen to events and track order conditions
3. **Price Monitoring**: Bots monitor price feeds (Hyperliquid or custom oracles)
4. **Order Execution**: When price conditions are met, bots call `markExecuted(orderId)`
5. **Failure Handling**: Failed transactions revert with appropriate error messages
6. **Success Confirmation**: Successful execution emits `OrderExecuted` event

### Contract Design

- **placeOrder**: Create new limit orders with price and amount validation
- **cancelOrder**: Cancel existing orders (owner-only)
- **markExecuted**: Mark orders as executed (bot/executor function)
- **Access Control**: Owner-controlled executor authorization system

## 🌐 HyperEVM Network

- **Mainnet Chain ID**: 999
- **Mainnet RPC**: `https://rpc.hyperliquid.xyz/evm`
- **Testnet Chain ID**: 998
- **Testnet RPC**: `https://rpc.hyperliquid-testnet.xyz/evm`
- **Hardfork**: Cancun (without blobs)

## 📋 Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- [Git](https://git-scm.com/)
- Node.js (for optional tooling)

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/hougangdev/limit-order-sc.git
cd hyperliquid-limit-order-sc

# Install dependencies
forge install

# Build the project
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run tests with coverage
forge coverage --no-match-coverage "test/mocks/"

# Run specific test file
forge test --match-path test/unit/LimitOrderBook.t.sol

# Run fuzz tests with more iterations
forge test --match-path test/fuzz/ --fuzz-runs 1000
```

### Deployment

```bash
# Deploy to HyperEVM testnet
forge script script/Deploy.s.sol --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --broadcast

# Deploy to HyperEVM mainnet (replace with your key)
forge script script/Deploy.s.sol --rpc-url https://rpc.hyperliquid.xyz/evm --broadcast --private-key $PRIVATE_KEY
```

## 📖 Usage Examples

### Basic Order Operations

```solidity
// Deploy the contract
LimitOrderBook orderBook = new LimitOrderBook(owner);

// Place a limit order
uint256 orderId = orderBook.placeOrder(1000e18, 100e18); // Price: 1000, Amount: 100

// Check order details
LimitOrderBook.Order memory order = orderBook.getOrder(orderId);

// Cancel an order (owner only)
orderBook.cancelOrder(orderId);

// Execute an order (bot/executor)
orderBook.markExecuted(orderId);
```

### Executor Authorization

```solidity
// Authorize an executor (owner only)
orderBook.authorizeExecutor(executorAddress);

// Require authorization for execution
orderBook.setExecutorAuthRequired(true);

// Revoke executor authorization
orderBook.revokeExecutor(executorAddress);
```

## 🔧 API Reference

### Core Functions

#### `placeOrder(uint256 price, uint256 amount) → uint256 orderId`

Creates a new limit order.

- **Parameters**: `price` - Target execution price, `amount` - Order quantity
- **Returns**: Unique order ID
- **Events**: `OrderPlaced(orderId, user, price, amount)`

#### `cancelOrder(uint256 orderId)`

Cancels an existing order.

- **Parameters**: `orderId` - Order to cancel
- **Requirements**: Must be order owner, order must not be executed
- **Events**: `OrderCancelled(orderId)`

#### `markExecuted(uint256 orderId)`

Marks an order as executed.

- **Parameters**: `orderId` - Order to execute
- **Requirements**: Order must exist and not be executed
- **Events**: `OrderExecuted(orderId)`

### View Functions

- `getOrder(uint256 orderId) → Order` - Get order details
- `isOrderActive(uint256 orderId) → bool` - Check if order is active
- `getOrderCount() → uint256` - Get total number of orders
- `s_authorizedExecutors(address) → bool` - Check executor authorization

### Admin Functions

- `authorizeExecutor(address executor)` - Authorize an executor
- `revokeExecutor(address executor)` - Revoke executor authorization
- `setExecutorAuthRequired(bool requireAuth)` - Toggle authorization requirement

## 🧪 Testing

The project includes comprehensive testing:

- **Unit Tests**: 26 tests covering all functionality
- **Fuzz Tests**: 10 fuzz tests with 256 iterations each
- **Coverage**: 95.35% line coverage, 95.12% statement coverage
- **Mock Contracts**: Test utilities for executor bots and price oracles

### Test Structure

```
test/
├── unit/           # Unit tests for core functionality
├── fuzz/           # Fuzz tests for edge cases
└── mocks/          # Mock contracts for testing
    ├── MockExecutorBot.sol
    └── MockPriceOracle.sol
```

### Known Risks

- **Centralization**: Owner has admin privileges (intended design)
- **Oracle Dependency**: Relies on external price feeds for execution

### Development Guidelines

- Follow Solidity style guide
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure 100% test coverage for new code

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Hyperliquid](https://hyperliquid.xyz/) for the HyperEVM network
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://getfoundry.sh/) for the development framework

---

**⚠️ Disclaimer**: This software is provided "as is" without warranty. Use at your own risk. Always conduct thorough testing before deploying to mainnet.
