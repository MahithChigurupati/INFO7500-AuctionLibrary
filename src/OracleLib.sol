// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title OracleLib
 * @author Mahith Chigurupati
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, functions will revert, and render the Avatar Nft Me unusable - this is by design.
 * We want the Avatar Nft Me to freeze if prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad.
 */
library OracleLib {
    error OracleLib__StalePrice();

    /**
     * constant variables
     */
    // decimal point adjustments
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    // timeout for stale data feed
    uint256 private constant TIMEOUT = 3 hours;

    /**
     * function call to check the Price feed oracle for latest ETH / USD conversion
     * @custom:assumption Assuming ETH as any token here
     *
     * @param _chainlinkFeed: chainlink price feed address
     *
     * @return roundId: current Round ID
     * @return answer: price feed conversion price in the format of 10 ** 8 format
     * @return startedAt: start time of the round
     * @return updatedAt: time at which answer was provided (round end time)
     * @return answeredInRound: round at which price feed answer was provided
     */
    function staleCheckLatestRoundData(AggregatorV3Interface _chainlinkFeed)
        internal
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            _chainlinkFeed.latestRoundData();

        // additional checks to verify that data is not stale
        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /**
     * a function call to check usd equivalent of ETH _amount
     *
     * @param _priceFeed: chainlink pricefeed address for ETH/USD conversion
     * @param _amount: ETH amount for which USD equivalent is needed
     *
     */
    function getUsdValue(AggregatorV3Interface _priceFeed, uint256 _amount) external view returns (uint256) {
        (, int256 price,,,) = staleCheckLatestRoundData(_priceFeed);
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

    /**
     * a function call to return _usdAmount equivalent of ETH
     *
     * @param _priceFeed: chainlink pricefeed address for ETH/USD conversion
     * @param _usdAmount: USD Amount for which ETH equivalent is needed
     */
    function getEthAmountFromUsd(AggregatorV3Interface _priceFeed, uint256 _usdAmount)
        external
        view
        returns (uint256)
    {
        (, int256 ethPrice,,,) = staleCheckLatestRoundData(_priceFeed);
        uint256 ethAmount = (_usdAmount) / uint256(ethPrice) * FEED_PRECISION;
        // the actual ETH amount equivalent to the given USD amount.
        return ethAmount;
    }

    /**
     * function that returns TIMEOUT set to check whether data is stale
     */
    function getTimeout(AggregatorV3Interface /* chainlinkFeed */ ) external pure returns (uint256) {
        return TIMEOUT;
    }
}
