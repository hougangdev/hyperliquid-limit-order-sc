// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/LimitOrderBook.sol";

contract LimitOrderBookFuzzTest is Test {
    LimitOrderBook public orderBook;
    address public owner = address(0x1337);

    function setUp() public {
        orderBook = new LimitOrderBook(owner);
    }

    /// @notice Fuzz test for placeOrder with valid inputs
    function testFuzz_PlaceOrder(uint256 price, uint256 amount, address user) public {
        // Bound inputs to valid ranges
        price = bound(price, 1, type(uint128).max); // Avoid 0 price
        amount = bound(amount, 1, type(uint128).max); // Avoid 0 amount
        vm.assume(user != address(0)); // Avoid zero address

        vm.prank(user);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // Verify order was created correctly
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertEq(order.user, user);
        assertEq(order.price, price);
        assertEq(order.amount, amount);
        assertEq(order.executed, false);
        assertEq(orderBook.s_nextOrderId(), orderId + 1);
    }

    /// @notice Fuzz test for placing multiple orders
    function testFuzz_PlaceMultipleOrders(uint256[5] memory prices, uint256[5] memory amounts, address[5] memory users)
        public
    {
        uint256 expectedOrderId = 0;

        for (uint256 i = 0; i < 5; i++) {
            // Bound inputs
            prices[i] = bound(prices[i], 1, type(uint128).max);
            amounts[i] = bound(amounts[i], 1, type(uint128).max);
            vm.assume(users[i] != address(0));

            vm.prank(users[i]);
            uint256 orderId = orderBook.placeOrder(prices[i], amounts[i]);

            assertEq(orderId, expectedOrderId);
            expectedOrderId++;
        }

        assertEq(orderBook.getOrderCount(), 5);
    }

    /// @notice Fuzz test for cancelOrder functionality
    function testFuzz_CancelOrder(uint256 price, uint256 amount, address user) public {
        // Bound inputs
        price = bound(price, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(user != address(0));

        // Place order
        vm.prank(user);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // Verify order is active
        assertTrue(orderBook.isOrderActive(orderId));

        // Cancel order
        vm.prank(user);
        orderBook.cancelOrder(orderId);

        // Verify order is no longer active
        assertFalse(orderBook.isOrderActive(orderId));
    }

    /// @notice Fuzz test for markExecuted functionality
    function testFuzz_MarkExecuted(uint256 price, uint256 amount, address user, address executor) public {
        // Bound inputs
        price = bound(price, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(user != address(0));
        vm.assume(executor != address(0));

        // Place order
        vm.prank(user);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // Verify order is active
        assertTrue(orderBook.isOrderActive(orderId));

        // Execute order (in permissionless mode by default)
        vm.prank(executor);
        orderBook.markExecuted(orderId);

        // Verify order is executed
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertTrue(order.executed);
        assertFalse(orderBook.isOrderActive(orderId));
    }

    /// @notice Fuzz test for authorization system
    function testFuzz_AuthorizationSystem(
        uint256 price,
        uint256 amount,
        address user,
        address executor,
        bool requireAuth
    ) public {
        // Bound inputs
        price = bound(price, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(user != address(0));
        vm.assume(executor != address(0));
        vm.assume(executor != owner); // Avoid conflicts with owner

        // Place order
        vm.prank(user);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // Set authorization requirement
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(requireAuth);

        if (requireAuth) {
            // Should fail if authorization required but executor not authorized
            vm.prank(executor);
            vm.expectRevert(LimitOrderBook.LimitOrderBook_UnauthorizedExecutor.selector);
            orderBook.markExecuted(orderId);

            // Authorize executor
            vm.prank(owner);
            orderBook.authorizeExecutor(executor);

            // Should succeed now
            vm.prank(executor);
            orderBook.markExecuted(orderId);
        } else {
            // Should succeed in permissionless mode
            vm.prank(executor);
            orderBook.markExecuted(orderId);
        }

        // Verify execution
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertTrue(order.executed);
    }

    /// @notice Fuzz test for invalid price/amount should revert
    function testFuzz_InvalidInputsRevert(uint256 price, uint256 amount, address user) public {
        vm.assume(user != address(0));

        vm.prank(user);

        if (price == 0) {
            vm.expectRevert(LimitOrderBook.LimitOrderBook_InvalidPrice.selector);
            orderBook.placeOrder(price, amount);
        } else if (amount == 0) {
            vm.expectRevert(LimitOrderBook.LimitOrderBook_InvalidAmount.selector);
            orderBook.placeOrder(price, amount);
        } else {
            // Both valid, should succeed
            uint256 orderId = orderBook.placeOrder(price, amount);
            assertTrue(orderBook.isOrderActive(orderId));
        }
    }

    /// @notice Fuzz test for order ownership protection
    function testFuzz_OrderOwnershipProtection(uint256 price, uint256 amount, address orderOwner, address attacker)
        public
    {
        // Bound inputs
        price = bound(price, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(orderOwner != address(0));
        vm.assume(attacker != address(0));
        vm.assume(orderOwner != attacker); // Different users

        // Place order as orderOwner
        vm.prank(orderOwner);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // Attacker tries to cancel order - should fail
        vm.prank(attacker);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_NotOrderOwner.selector);
        orderBook.cancelOrder(orderId);

        // Order owner can cancel - should succeed
        vm.prank(orderOwner);
        orderBook.cancelOrder(orderId);

        // Verify order is cancelled
        assertFalse(orderBook.isOrderActive(orderId));
    }

    /// @notice Fuzz test for non-existent order IDs
    function testFuzz_NonExistentOrderId(uint256 invalidOrderId, address user) public {
        vm.assume(user != address(0));
        // Ensure we're testing with an invalid order ID (greater than current next ID)
        invalidOrderId = bound(invalidOrderId, orderBook.s_nextOrderId(), type(uint256).max);

        vm.prank(user);

        // All operations on non-existent orders should revert
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.getOrder(invalidOrderId);

        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.cancelOrder(invalidOrderId);

        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.markExecuted(invalidOrderId);

        // isOrderActive should return false (doesn't revert)
        assertFalse(orderBook.isOrderActive(invalidOrderId));
    }

    /// @notice Fuzz test for double execution protection
    function testFuzz_DoubleExecutionProtection(
        uint256 price,
        uint256 amount,
        address user,
        address executor1,
        address executor2
    ) public {
        // Bound inputs
        price = bound(price, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(user != address(0));
        vm.assume(executor1 != address(0));
        vm.assume(executor2 != address(0));

        // Place order
        vm.prank(user);
        uint256 orderId = orderBook.placeOrder(price, amount);

        // First execution should succeed
        vm.prank(executor1);
        orderBook.markExecuted(orderId);

        // Second execution should fail (same or different executor)
        vm.prank(executor2);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderAlreadyExecuted.selector);
        orderBook.markExecuted(orderId);

        // Verify order is still executed (not corrupted)
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertTrue(order.executed);
    }

    /// @notice Fuzz test for executor authorization edge cases
    function testFuzz_ExecutorAuthorizationEdgeCases(address executor, bool authorize, bool revoke) public {
        vm.assume(executor != address(0));

        // Initial state should be false for random address
        assertFalse(orderBook.s_authorizedExecutors(executor));

        if (authorize) {
            vm.prank(owner);
            orderBook.authorizeExecutor(executor);
            assertTrue(orderBook.s_authorizedExecutors(executor));

            if (revoke) {
                vm.prank(owner);
                orderBook.revokeExecutor(executor);
                assertFalse(orderBook.s_authorizedExecutors(executor));
            }
        }
    }
}
