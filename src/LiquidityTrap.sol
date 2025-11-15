// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "contracts/interfaces/ITrap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title HighTierLiquidityTrap
/// @notice Multi-pool, time-weighted, configurable liquidity trap.
contract HighTierLiquidityTrap is ITrap, Ownable {
    // ----------------------------------------------------------------------
    // CONFIG
    // ----------------------------------------------------------------------
    struct PoolConfig {
        address lp;            // LP token address
        uint256 minDropPercent; // minimum drop % to trigger trap
        uint256 lastBalance;    // last recorded LP balance
    }

    // Pools being monitored
    PoolConfig[] public pools;

    // Time-weighted parameters
    uint256 public checkInterval = 60; // seconds between trap checks
    uint256 public lastCheckTimestamp;

    // Alert thresholds
    uint256 public yellowThreshold = 10; // % drop for yellow alert
    uint256 public redThreshold = 25;    // % drop for red alert

    // ----------------------------------------------------------------------
    // EVENTS
    // ----------------------------------------------------------------------
    event TrapArmed(uint256 poolIndex, uint256 initialBalance);
    event LiquidityAlert(
        uint256 poolIndex,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 percentDrop,
        string severity,
        uint256 timestamp
    );
    event ThresholdsUpdated(uint256 newYellow, uint256 newRed);

    // ----------------------------------------------------------------------
    // CONSTRUCTOR
    // ----------------------------------------------------------------------
    constructor() {
        lastCheckTimestamp = block.timestamp;
    }

    // ----------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ----------------------------------------------------------------------
    function addPool(address _lp, uint256 _minDropPercent) external onlyOwner {
        require(_lp != address(0), "invalid LP");
        require(_minDropPercent > 0 && _minDropPercent < 100, "invalid percent");

        uint256 initialBalance = IERC20(_lp).balanceOf(_lp);
        pools.push(PoolConfig(_lp, _minDropPercent, initialBalance));

        emit TrapArmed(pools.length - 1, initialBalance);
    }

    function setCheckInterval(uint256 _seconds) external onlyOwner {
        require(_seconds >= 10, "too short");
        checkInterval = _seconds;
    }

    function setAlertThresholds(uint256 _yellow, uint256 _red) external onlyOwner {
        require(_yellow < _red && _red <= 100, "invalid thresholds");
        yellowThreshold = _yellow;
        redThreshold = _red;
        emit ThresholdsUpdated(_yellow, _red);
    }

    // ----------------------------------------------------------------------
    // CORE TRAP LOGIC
    // ----------------------------------------------------------------------
    function trap() external override returns (bool triggered) {
        if (block.timestamp < lastCheckTimestamp + checkInterval) {
            return false; // skip if interval not reached
        }

        lastCheckTimestamp = block.timestamp;

        for (uint256 i = 0; i < pools.length; i++) {
            PoolConfig storage pool = pools[i];
            uint256 newBalance = IERC20(pool.lp).balanceOf(pool.lp);

            if (newBalance < pool.lastBalance) {
                uint256 drop = pool.lastBalance - newBalance;
                uint256 percentDrop = (drop * 100) / pool.lastBalance;

                string memory severity;

                if (percentDrop >= redThreshold) {
                    severity = "RED";
                    triggered = true;
                } else if (percentDrop >= yellowThreshold) {
                    severity = "YELLOW";
                    triggered = false;
                } else {
                    severity = "GREEN";
                }

                if (percentDrop >= pool.minDropPercent) {
                    emit LiquidityAlert(
                        i,
                        pool.lastBalance,
                        newBalance,
                        percentDrop,
                        severity,
                        block.timestamp
                    );
                }

                // Update last balance for next check
                pool.lastBalance = newBalance;
            }
        }
    }
}
