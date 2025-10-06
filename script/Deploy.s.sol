// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "lib/forge-std/src/Script.sol";
import "../src/LimitOrderBook.sol";

/**
 * @title Deploy Script
 * @dev Script to deploy LimitOrderBook contract to HyperEVM
 * @notice Run with: forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
 */
contract DeployScript is Script {
    function run() external {
        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Log deployment info
        console.log("Deploying LimitOrderBook...");
        console.log("Deployer address:", deployer);

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy LimitOrderBook with deployer as initial owner
        LimitOrderBook orderBook = new LimitOrderBook(deployer);

        // Stop broadcasting
        vm.stopBroadcast();

        // Log deployment results
        console.log("LimitOrderBook deployed to:", address(orderBook));
        console.log("Owner:", orderBook.owner());
        console.log("Initial state:");
        console.log("- Permissionless execution:", orderBook.s_authorizedExecutors(address(0)));
        console.log("- Next order ID:", orderBook.s_nextOrderId());
    }
}
