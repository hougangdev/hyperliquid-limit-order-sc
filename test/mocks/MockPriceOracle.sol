// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MockPriceOracle
 * @dev Mock contract for simulating price feeds in tests
 * @notice This mock can be used to test price-based order execution logic
 */
contract MockPriceOracle {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_price;
    uint8 private s_decimals;
    string private s_description;
    bool private s_isValid;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PriceUpdated(uint256 newPrice, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 initialPrice, uint8 _decimals, string memory _description) {
        s_price = initialPrice;
        s_decimals = _decimals;
        s_description = _description;
        s_isValid = true;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the mock price
     * @param newPrice The new price to set
     */
    function updatePrice(uint256 newPrice) external {
        s_price = newPrice;
        emit PriceUpdated(newPrice, block.timestamp);
    }

    /**
     * @notice Sets whether the oracle is valid/online
     * @param _isValid True if oracle should be considered valid
     */
    function setIsValid(bool _isValid) external {
        s_isValid = _isValid;
    }

    /**
     * @notice Simulates a price feed failure
     */
    function simulateFailure() external {
        s_isValid = false;
    }

    /**
     * @notice Restores the oracle to working condition
     */
    function restore() external {
        s_isValid = true;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the latest price (Chainlink-style interface)
     * @return roundId The round ID (always 1 for this mock)
     * @return answer The price
     * @return startedAt The timestamp (current block timestamp)
     * @return updatedAt The timestamp (current block timestamp)
     * @return answeredInRound The round ID (always 1 for this mock)
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(s_isValid, "MockPriceOracle: Oracle is not valid");
        return (
            1, // roundId
            int256(s_price), // answer
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );
    }

    /**
     * @notice Gets the current price
     * @return The current price
     */
    function getPrice() external view returns (uint256) {
        require(s_isValid, "MockPriceOracle: Oracle is not valid");
        return s_price;
    }

    /**
     * @notice Gets the number of decimals
     * @return The number of decimals
     */
    function decimals() external view returns (uint8) {
        return s_decimals;
    }

    /**
     * @notice Gets the description
     * @return The description
     */
    function description() external view returns (string memory) {
        return s_description;
    }

    /**
     * @notice Checks if the oracle is valid
     * @return True if the oracle is valid
     */
    function isValid() external view returns (bool) {
        return s_isValid;
    }
}
