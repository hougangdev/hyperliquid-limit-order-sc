// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../src/LimitOrderBook.sol";

/**
 * @title MockExecutorBot
 * @dev Mock contract for simulating off-chain executor bot behavior
 * @notice This mock can be used to test automated order execution scenarios
 */
contract MockExecutorBot {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    LimitOrderBook public immutable i_orderBook;
    bool public s_isActive;
    uint256 public s_executionCount;
    uint256 public s_failureCount;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MockExecutorBot_BotNotActive();
    error MockExecutorBot_ExecutionFailed(uint256 orderId, string reason);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OrderExecuted(uint256 indexed orderId, address indexed executor);
    event ExecutionFailed(uint256 indexed orderId, string reason);
    event BotStatusChanged(bool isActive);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(LimitOrderBook orderBook) {
        i_orderBook = orderBook;
        s_isActive = true;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Attempts to execute an order
     * @dev This function is used to test the order execution functionality
     * @param orderId The ID of the order to execute
     */
    function executeOrder(uint256 orderId) external {
        if (!s_isActive) {
            revert MockExecutorBot_BotNotActive();
        }

        try i_orderBook.markExecuted(orderId) {
            s_executionCount++;
            emit OrderExecuted(orderId, address(this));
        } catch Error(string memory reason) {
            s_failureCount++;
            emit ExecutionFailed(orderId, reason);
            revert MockExecutorBot_ExecutionFailed(orderId, reason);
        } catch {
            s_failureCount++;
            emit ExecutionFailed(orderId, "Unknown error");
            revert MockExecutorBot_ExecutionFailed(orderId, "Unknown error");
        }
    }

    /**
     * @notice Batch execute multiple orders
     * @param orderIds Array of order IDs to execute
     */
    function batchExecuteOrders(uint256[] calldata orderIds) external {
        if (!s_isActive) {
            revert MockExecutorBot_BotNotActive();
        }

        for (uint256 i = 0; i < orderIds.length; i++) {
            try i_orderBook.markExecuted(orderIds[i]) {
                s_executionCount++;
                emit OrderExecuted(orderIds[i], address(this));
            } catch Error(string memory reason) {
                s_failureCount++;
                emit ExecutionFailed(orderIds[i], reason);
                // Continue with next order instead of reverting
            } catch {
                s_failureCount++;
                emit ExecutionFailed(orderIds[i], "Unknown error");
                // Continue with next order instead of reverting
            }
        }
    }

    /**
     * @notice Simulates bot going offline
     */
    function goOffline() external {
        s_isActive = false;
        emit BotStatusChanged(false);
    }

    /**
     * @notice Simulates bot coming back online
     */
    function goOnline() external {
        s_isActive = true;
        emit BotStatusChanged(true);
    }

    /**
     * @notice Resets execution statistics
     */
    function resetStats() external {
        s_executionCount = 0;
        s_failureCount = 0;
    }

    /**
     * @notice Checks if an order can be executed (without actually executing)
     * @param orderId The ID of the order to check
     * @return canExecute True if the order can be executed
     * @return reason Reason why execution would fail (if any)
     */
    function canExecuteOrder(uint256 orderId) external view returns (bool canExecute, string memory reason) {
        if (!s_isActive) {
            return (false, "Bot is not active");
        }

        try i_orderBook.getOrder(orderId) returns (LimitOrderBook.Order memory order) {
            if (order.executed) {
                return (false, "Order already executed");
            }
            if (order.user == address(0)) {
                return (false, "Order does not exist");
            }
            return (true, "");
        } catch {
            return (false, "Order not found");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the bot's execution statistics
     * @return executionCount Number of successful executions
     * @return failureCount Number of failed executions
     * @return successRate Success rate as a percentage (0-100)
     */
    function getExecutionStats()
        external
        view
        returns (uint256 executionCount, uint256 failureCount, uint256 successRate)
    {
        executionCount = s_executionCount;
        failureCount = s_failureCount;

        uint256 totalAttempts = executionCount + failureCount;
        if (totalAttempts == 0) {
            successRate = 0;
        } else {
            successRate = (executionCount * 100) / totalAttempts;
        }
    }

    /**
     * @notice Checks if the bot is currently active
     * @return True if the bot is active
     */
    function isActive() external view returns (bool) {
        return s_isActive;
    }

    /**
     * @notice Gets the associated order book contract
     * @return The LimitOrderBook contract address
     */
    function getOrderBook() external view returns (LimitOrderBook) {
        return i_orderBook;
    }
}
