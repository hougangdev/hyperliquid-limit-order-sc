// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/LimitOrderBook.sol";

contract LimitOrderBookTest is Test {
    LimitOrderBook public orderBook;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public executor = address(0x3);
    address public unauthorizedUser = address(0x4);

    event OrderPlaced(uint256 indexed orderId, address indexed user, uint256 indexed price, uint256 amount);
    event OrderExecuted(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);

    function setUp() public {
        orderBook = new LimitOrderBook(address(this)); // Deploy with test contract as initial owner
    }

    function test_PlaceOrder() public {
        vm.prank(user1);

        // Expect the OrderPlaced event
        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(0, user1, 1000, 100);

        uint256 orderId = orderBook.placeOrder(1000, 100);

        assertEq(orderId, 0);
        assertEq(orderBook.s_nextOrderId(), 1);

        // Check order details
        LimitOrderBook.Order memory order = orderBook.getOrder(0);
        assertEq(order.user, user1);
        assertEq(order.price, 1000);
        assertEq(order.amount, 100);
        assertEq(order.executed, false);
    }

    function test_PlaceOrder_InvalidPrice() public {
        vm.prank(user1);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_InvalidPrice.selector);
        orderBook.placeOrder(0, 100);
    }

    function test_PlaceOrder_InvalidAmount() public {
        vm.prank(user1);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_InvalidAmount.selector);
        orderBook.placeOrder(1000, 0);
    }

    function test_CancelOrder() public {
        // Place order first
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Cancel order
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit OrderCancelled(orderId);

        orderBook.cancelOrder(orderId);

        // Order should be deleted
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.getOrder(orderId);
    }

    function test_CancelOrder_NotOwner() public {
        // Place order as user1
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Try to cancel as user2
        vm.prank(user2);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_NotOrderOwner.selector);
        orderBook.cancelOrder(orderId);
    }

    function test_CancelOrder_AlreadyExecuted() public {
        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Execute order
        vm.prank(executor);
        orderBook.markExecuted(orderId);

        // Try to cancel executed order
        vm.prank(user1);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderAlreadyExecuted.selector);
        orderBook.cancelOrder(orderId);
    }

    function test_CancelOrder_InvalidOrderId() public {
        // Try to cancel non-existent order
        vm.prank(user1);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.cancelOrder(999);
    }

    function test_MarkExecuted() public {
        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Execute order
        vm.prank(executor);
        vm.expectEmit(true, false, false, true);
        emit OrderExecuted(orderId);

        orderBook.markExecuted(orderId);

        // Check order is marked as executed
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertEq(order.executed, true);
    }

    function test_MarkExecuted_AlreadyExecuted() public {
        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Execute order
        vm.prank(executor);
        orderBook.markExecuted(orderId);

        // Try to execute again
        vm.prank(executor);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderAlreadyExecuted.selector);
        orderBook.markExecuted(orderId);
    }

    function test_MarkExecuted_InvalidOrderId() public {
        // Try to execute non-existent order
        vm.prank(executor);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.markExecuted(999);
    }

    function test_IsOrderActive() public {
        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Should be active initially
        assertTrue(orderBook.isOrderActive(orderId));

        // Execute order
        vm.prank(executor);
        orderBook.markExecuted(orderId);

        // Should not be active after execution
        assertFalse(orderBook.isOrderActive(orderId));
    }

    function test_IsOrderActive_NonExistentOrder() public view {
        // Non-existent order should not be active
        assertFalse(orderBook.isOrderActive(999));
    }

    function test_GetOrderCount() public {
        assertEq(orderBook.getOrderCount(), 0);

        vm.prank(user1);
        orderBook.placeOrder(1000, 100);
        assertEq(orderBook.getOrderCount(), 1);

        vm.prank(user2);
        orderBook.placeOrder(2000, 200);
        assertEq(orderBook.getOrderCount(), 2);
    }

    function test_GetOrder_InvalidOrderId() public {
        // Try to get non-existent order
        vm.expectRevert(LimitOrderBook.LimitOrderBook_OrderNotFound.selector);
        orderBook.getOrder(999);
    }

    function test_AuthorizeExecutor() public {
        address owner = orderBook.owner();

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit LimitOrderBook.ExecutorAuthorized(executor);

        orderBook.authorizeExecutor(executor);
        assertTrue(orderBook.s_authorizedExecutors(executor));
    }

    function test_RevokeExecutor() public {
        address owner = orderBook.owner();

        // First authorize
        vm.prank(owner);
        orderBook.authorizeExecutor(executor);

        // Then revoke
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit LimitOrderBook.ExecutorRevoked(executor);

        orderBook.revokeExecutor(executor);
        assertFalse(orderBook.s_authorizedExecutors(executor));
    }

    function test_SetExecutorAuthRequired_RequireAuth() public {
        address owner = orderBook.owner();

        // Initially permissionless (address(0) should be true)
        assertTrue(orderBook.s_authorizedExecutors(address(0)));

        // Set to require authorization
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(true);

        // Now should require authorization (address(0) should be false)
        assertFalse(orderBook.s_authorizedExecutors(address(0)));
    }

    function test_SetExecutorAuthRequired_PermissionlessExecution() public {
        address owner = orderBook.owner();

        // First set to require authorization
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(true);
        assertFalse(orderBook.s_authorizedExecutors(address(0)));

        // Then set back to permissionless
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(false);

        // Should be permissionless again
        assertTrue(orderBook.s_authorizedExecutors(address(0)));
    }

    function test_MarkExecuted_WithAuthorizationRequired_AuthorizedExecutor() public {
        address owner = orderBook.owner();

        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Set to require authorization
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(true);

        // Authorize executor
        vm.prank(owner);
        orderBook.authorizeExecutor(executor);

        // Execute order with authorized executor
        vm.prank(executor);
        orderBook.markExecuted(orderId);

        // Verify execution
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertEq(order.executed, true);
    }

    function test_MarkExecuted_WithAuthorizationRequired_UnauthorizedExecutor() public {
        address owner = orderBook.owner();

        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // Set to require authorization
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(true);

        // Try to execute with unauthorized user
        vm.prank(unauthorizedUser);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_UnauthorizedExecutor.selector);
        orderBook.markExecuted(orderId);
    }

    function test_MarkExecuted_PermissionlessMode() public {
        // Place order
        vm.prank(user1);
        uint256 orderId = orderBook.placeOrder(1000, 100);

        // In permissionless mode (default), anyone can execute
        vm.prank(unauthorizedUser);
        orderBook.markExecuted(orderId);

        // Verify execution
        LimitOrderBook.Order memory order = orderBook.getOrder(orderId);
        assertEq(order.executed, true);
    }

    function test_OnlyOwnerFunctions() public {
        vm.prank(user1);
        vm.expectRevert(); // OpenZeppelin's Ownable will revert with OwnableUnauthorizedAccount
        orderBook.authorizeExecutor(executor);

        vm.prank(user1);
        vm.expectRevert(); // OpenZeppelin's Ownable will revert with OwnableUnauthorizedAccount
        orderBook.revokeExecutor(executor);

        vm.prank(user1);
        vm.expectRevert(); // OpenZeppelin's Ownable will revert with OwnableUnauthorizedAccount
        orderBook.transferOwnership(user2);

        vm.prank(user1);
        vm.expectRevert(); // OpenZeppelin's Ownable will revert with OwnableUnauthorizedAccount
        orderBook.setExecutorAuthRequired(true);
    }

    function test_AuthorizationFlow_Complete() public {
        address owner = orderBook.owner();

        // Test complete authorization flow

        // 1. Initially permissionless
        assertTrue(orderBook.s_authorizedExecutors(address(0)));

        // 2. Place an order
        vm.prank(user1);
        uint256 orderId1 = orderBook.placeOrder(1000, 100);

        // 3. Anyone can execute in permissionless mode
        vm.prank(unauthorizedUser);
        orderBook.markExecuted(orderId1);

        // 4. Place another order
        vm.prank(user1);
        uint256 orderId2 = orderBook.placeOrder(2000, 200);

        // 5. Switch to authorization required
        vm.prank(owner);
        orderBook.setExecutorAuthRequired(true);

        // 6. Unauthorized user cannot execute
        vm.prank(unauthorizedUser);
        vm.expectRevert(LimitOrderBook.LimitOrderBook_UnauthorizedExecutor.selector);
        orderBook.markExecuted(orderId2);

        // 7. Authorize executor
        vm.prank(owner);
        orderBook.authorizeExecutor(executor);

        // 8. Authorized executor can execute
        vm.prank(executor);
        orderBook.markExecuted(orderId2);

        // 9. Verify both orders executed
        assertTrue(orderBook.getOrder(orderId1).executed);
        assertTrue(orderBook.getOrder(orderId2).executed);
    }

    function test_MultipleOrders() public {
        // Place multiple orders
        vm.prank(user1);
        uint256 orderId1 = orderBook.placeOrder(1000, 100);

        vm.prank(user2);
        uint256 orderId2 = orderBook.placeOrder(2000, 200);

        vm.prank(user1);
        uint256 orderId3 = orderBook.placeOrder(1500, 150);

        assertEq(orderId1, 0);
        assertEq(orderId2, 1);
        assertEq(orderId3, 2);
        assertEq(orderBook.getOrderCount(), 3);

        // Check all orders exist and are active
        assertTrue(orderBook.isOrderActive(orderId1));
        assertTrue(orderBook.isOrderActive(orderId2));
        assertTrue(orderBook.isOrderActive(orderId3));

        // Execute one order
        vm.prank(executor);
        orderBook.markExecuted(orderId2);

        assertTrue(orderBook.isOrderActive(orderId1));
        assertFalse(orderBook.isOrderActive(orderId2));
        assertTrue(orderBook.isOrderActive(orderId3));

        // Cancel one order
        vm.prank(user1);
        orderBook.cancelOrder(orderId1);

        assertFalse(orderBook.isOrderActive(orderId1));
        assertFalse(orderBook.isOrderActive(orderId2));
        assertTrue(orderBook.isOrderActive(orderId3));
    }

    function test_Constructor_InitialState() public {
        // Deploy a new contract to test constructor
        LimitOrderBook newOrderBook = new LimitOrderBook(user1);

        // Check initial state
        assertEq(newOrderBook.owner(), user1);
        assertEq(newOrderBook.s_nextOrderId(), 0);
        assertTrue(newOrderBook.s_authorizedExecutors(address(0))); // Should be permissionless initially
        assertFalse(newOrderBook.s_authorizedExecutors(user2)); // Random address should not be authorized
    }

    function test_AuthorizeAndRevokeMultipleExecutors() public {
        address owner = orderBook.owner();
        address executor1 = address(0x10);
        address executor2 = address(0x11);

        // Authorize multiple executors
        vm.prank(owner);
        orderBook.authorizeExecutor(executor1);
        vm.prank(owner);
        orderBook.authorizeExecutor(executor2);

        assertTrue(orderBook.s_authorizedExecutors(executor1));
        assertTrue(orderBook.s_authorizedExecutors(executor2));

        // Revoke one
        vm.prank(owner);
        orderBook.revokeExecutor(executor1);

        assertFalse(orderBook.s_authorizedExecutors(executor1));
        assertTrue(orderBook.s_authorizedExecutors(executor2));
    }
}
