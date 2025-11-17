// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "contracts/interfaces/ITrap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title UltraHighTierLiquidityTrap
/// @notice Multi-pool, token-agnostic, safe liquidity trap with snapshot collection and rising-edge alerting.
contract UltraHighTierLiquidityTrap is ITrap, Ownable {
    // ----------------------------------------------------------------------
    // CONFIG
    // ----------------------------------------------------------------------
    struct PoolConfig {
        address lp;             // LP token address
        uint256 minDropBps;     // minimum drop in basis points (1% = 100 bps)
        uint256 lastBalance;    // last recorded LP balance
    }

    PoolConfig[] public pools;

    // Time-weighted parameters
    uint256 public checkInterval = 60; // seconds between trap checks
    uint256 public lastCheckTimestamp;

    // Alert thresholds
    uint256 public yellowBps = 1000; // 10% = 1000 bps
    uint256 public redBps    = 2500; // 25% = 2500 bps

    // Store last alert % to prevent duplicates (rising-edge)
    mapping(address => uint256) public lastAlertBps;

    // ----------------------------------------------------------------------
    // EVENTS
    // ----------------------------------------------------------------------
    event TrapArmed(uint256 poolIndex, uint256 initialBalance);
    event LiquidityAlert(
        uint256 poolIndex,
        address lp,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 percentBps,
        string severity,
        uint256 timestamp
    );
    event ThresholdsUpdated(uint256 newYellowBps, uint256 newRedBps);

    // ----------------------------------------------------------------------
    // CONSTRUCTOR
    // ----------------------------------------------------------------------
    constructor() {
        lastCheckTimestamp = block.timestamp;
    }

    // ----------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ----------------------------------------------------------------------
    function addPool(address _lp, uint256 _minDropBps) external onlyOwner {
        require(_lp != address(0), "invalid LP");
        require(_minDropBps > 0 && _minDropBps < 10000, "invalid bps");

        uint256 initialBalance = _safeBalance(_lp);
        pools.push(PoolConfig(_lp, _minDropBps, initialBalance));

        emit TrapArmed(pools.length - 1, initialBalance);
    }

    function setCheckInterval(uint256 _seconds) external onlyOwner {
        require(_seconds >= 10, "too short");
        checkInterval = _seconds;
    }

    function setAlertThresholds(uint256 _yellowBps, uint256 _redBps) external onlyOwner {
        require(_yellowBps < _redBps && _redBps <= 10000, "invalid thresholds");
        yellowBps = _yellowBps;
        redBps = _redBps;
        emit ThresholdsUpdated(_yellowBps, _redBps);
    }

    // ----------------------------------------------------------------------
    // VIEW FUNCTIONS
    // ----------------------------------------------------------------------
    /// @notice Collect current pool snapshots without reverting
    function collect() external view returns (bytes[] memory data) {
        data = new bytes[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            PoolConfig storage pool = pools[i];
            uint256 balance = _safeBalance(pool.lp);
            data[i] = abi.encode(pool.lp, balance, block.number, block.chainid);
        }
    }

    // ----------------------------------------------------------------------
    // CORE TRAP LOGIC
    // ----------------------------------------------------------------------
    function trap() external override returns (bool triggered) {
        if (block.timestamp < lastCheckTimestamp + checkInterval) return false;
        lastCheckTimestamp = block.timestamp;

        for (uint256 i = 0; i < pools.length; i++) {
            PoolConfig storage pool = pools[i];
            uint256 newBalance = _safeBalance(pool.lp);
            if (newBalance >= pool.lastBalance) continue; // no drop

            uint256 dropBps = ((pool.lastBalance - newBalance) * 10000) / pool.lastBalance;

            // Skip if already alerted last block
            if (dropBps <= lastAlertBps[pool.lp]) {
                pool.lastBalance = newBalance;
                continue;
            }

            lastAlertBps[pool.lp] = dropBps;

            string memory severity = "GREEN";
            bool alert = false;

            if (dropBps >= redBps) {
                severity = "RED";
                triggered = true;
                alert = true;
            } else if (dropBps >= yellowBps) {
                severity = "YELLOW";
                alert = true;
            }

            if (dropBps >= pool.minDropBps && alert) {
                emit LiquidityAlert(
                    i,
                    pool.lp,
                    pool.lastBalance,
                    newBalance,
                    dropBps,
                    severity,
                    block.timestamp
                );
            }

            pool.lastBalance = newBalance;
        }
    }

    // ----------------------------------------------------------------------
    // INTERNAL HELPERS
    // ----------------------------------------------------------------------
    function _safeBalance(address token) internal view returns (uint256) {
        if (token.code.length == 0) return 0;
        try IERC20(token).balanceOf(token) returns (uint256 b) {
            return b;
        } catch {
            return 0;
        }
    }
}        uint256 oldBalance,
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
