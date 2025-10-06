// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LimitOrderBook
 * @dev A contract for managing limit orders with off-chain execution
 * @dev This contract is designed to be used on HyperEVM
 * @notice Users can place limit orders which are executed by off-chain bots when price conditions are met
 * @notice Executors can be authorized to mark orders as executed
 */
contract LimitOrderBook is Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error LimitOrderBook_InvalidPrice();
    error LimitOrderBook_InvalidAmount();
    error LimitOrderBook_OrderNotFound();
    error LimitOrderBook_NotOrderOwner();
    error LimitOrderBook_OrderAlreadyExecuted();
    error LimitOrderBook_UnauthorizedExecutor();

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    struct Order {
        address user; // User who placed the order
        uint256 price; // Target price for execution
        uint256 amount; // Amount/quantity for the order
        bool executed; // Whether the order has been executed
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Order) public s_orders;
    uint256 public s_nextOrderId;

    // Access control for executors
    mapping(address => bool) public s_authorizedExecutors;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OrderPlaced(uint256 indexed orderId, address indexed user, uint256 indexed price, uint256 amount);
    event OrderExecuted(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event ExecutorAuthorized(address indexed executor);
    event ExecutorRevoked(address indexed executor);
    event ExecutorAuthRequirementChanged(bool indexed requireAuth);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorizedExecutor() {
        if (!s_authorizedExecutors[msg.sender]) revert LimitOrderBook_UnauthorizedExecutor();
        _;
    }

    modifier validOrder(uint256 orderId) {
        if (s_orders[orderId].user == address(0)) revert LimitOrderBook_OrderNotFound();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initialOwner) Ownable(initialOwner) {
        // Explicitly initialize state variables
        s_nextOrderId = 0;
        // Initially, allow anyone to execute (can be changed later)
        // This supports the permissionless bot execution model
        s_authorizedExecutors[address(0)] = true; // Flag to indicate permissionless execution
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Place a new limit order
     * @param price The target price for order execution
     * @param amount The amount/quantity for the order
     * @return orderId The unique identifier for the placed order
     */
    function placeOrder(uint256 price, uint256 amount) external nonReentrant returns (uint256 orderId) {
        // Validation
        if (price == 0) revert LimitOrderBook_InvalidPrice();
        if (amount == 0) revert LimitOrderBook_InvalidAmount();

        // Create order
        orderId = s_nextOrderId;
        s_orders[orderId] = Order({user: msg.sender, price: price, amount: amount, executed: false});

        emit OrderPlaced(orderId, msg.sender, price, amount);

        // Increment for next order
        s_nextOrderId++;
    }

    /**
     * @notice Cancel an existing order
     * @param orderId The ID of the order to cancel
     */
    function cancelOrder(uint256 orderId) external nonReentrant validOrder(orderId) {
        Order storage order = s_orders[orderId];

        // Verify ownership
        if (order.user != msg.sender) revert LimitOrderBook_NotOrderOwner();

        // Verify not already executed
        if (order.executed) revert LimitOrderBook_OrderAlreadyExecuted();

        // Delete the order
        delete s_orders[orderId];

        emit OrderCancelled(orderId);
    }

    /**
     * @notice Mark an order as executed (called by off-chain bots)
     * @param orderId The ID of the order to execute
     * @dev This function can be called by anyone initially, but access can be restricted
     */
    function markExecuted(uint256 orderId) external nonReentrant validOrder(orderId) {
        Order storage order = s_orders[orderId];

        // Verify not already executed
        if (order.executed) revert LimitOrderBook_OrderAlreadyExecuted();

        // If executor authorization is enabled, check permission
        // address(0) flag indicates if permissionless execution is allowed
        if (!s_authorizedExecutors[address(0)] && !s_authorizedExecutors[msg.sender]) {
            revert LimitOrderBook_UnauthorizedExecutor();
        }

        // Mark as executed
        order.executed = true;

        emit OrderExecuted(orderId);
    }

    /**
     * @notice Authorize an executor to mark orders as executed
     * @param executor The address to authorize
     */
    function authorizeExecutor(address executor) external onlyOwner {
        s_authorizedExecutors[executor] = true;
        emit ExecutorAuthorized(executor);
    }

    /**
     * @notice Revoke executor authorization
     * @param executor The address to revoke authorization from
     */
    function revokeExecutor(address executor) external onlyOwner {
        s_authorizedExecutors[executor] = false;
        emit ExecutorRevoked(executor);
    }

    /**
     * @notice Enable or disable executor authorization requirement
     * @param requireAuth True to require authorization, false for permissionless execution
     */
    function setExecutorAuthRequired(bool requireAuth) external onlyOwner {
        // Use address(0) as a flag for whether auth is required
        s_authorizedExecutors[address(0)] = !requireAuth;
        emit ExecutorAuthRequirementChanged(requireAuth);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get order details
     * @param orderId The ID of the order
     * @return order The order struct
     */
    function getOrder(uint256 orderId) external view validOrder(orderId) returns (Order memory order) {
        return s_orders[orderId];
    }

    /**
     * @notice Check if an order exists and is active (not executed)
     * @param orderId The ID of the order
     * @return isActive True if order exists and is not executed
     */
    function isOrderActive(uint256 orderId) external view returns (bool isActive) {
        Order storage order = s_orders[orderId];
        return order.user != address(0) && !order.executed;
    }

    /**
     * @notice Get the total number of orders placed
     * @return count The total count of orders
     */
    function getOrderCount() external view returns (uint256 count) {
        return s_nextOrderId;
    }
}
