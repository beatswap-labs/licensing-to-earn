// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/*
 * IPL (IPLicensingIndex)
 * - Non-transferable ERC-20 “index token” via per-index whitelist.
 * - Monthly snapshots store a block to compute proportional shares.
 *
 * Overview:
 * 1) Token transfers are entirely disabled; minting only. It functions as an analytical index token, not a tradable asset.
 * 2) Each index can be minted only once, enforcing one-to-one mapping between verified records and minted entries.
 * 3) Monthly snapshots are taken once per (year, month) to freeze a specific block number for verifiable accounting.
 * 4) Authorized operators can mint on behalf of users (delegated minting). Only the whitelisted account or authorized operator can call `mint`.
 * 5) Batch add/remove functions ensure strict input validation: no zero address, no zero amount, no duplicate index, and proper enum range.
 * 6) Checkpoints record balances and total supply to allow historical queries at specific block numbers.
 * 7) Events provide complete off-chain traceability for indexing, analytics, and transparency.
 */

contract IPLicensingIndex is ERC20, Ownable, ReentrancyGuard {
    // Fixed order for external mappings. Sequence must remain stable.
    enum MintType {
        RoyaltyReward,
        StreamReward, 
        UnlockReward,
        BonusReward 
    }

    // Whitelist entry structure: one unique record per index.
    // account: receiver of the mint
    // amount: amount to be minted
    // mintType: classification for reporting and reward categorization
    struct Whitelist {
        address account;
        uint256 amount;
        uint8   mintType;
    }

    // Compact checkpoint for historical queries.
    // fromBlock is compressed to uint48 for gas and storage efficiency.
    struct Checkpoint {
        uint48  fromBlock; 
        uint208 value;
    }
    
    // Mapping of index → whitelist entry.
    mapping(uint256 => Whitelist) public whitelistByIndex;

    // Marks whether an index has been minted; enforces one-time mint.
    mapping(uint256 => bool) public hasMintedByIndex;

    // Next available index (informational).
    uint256 public nextIndex = 1;

    // Counter for batch operations (for traceability).
    uint256 private batchCounter = 0;

    // Mapping (year, month) → snapshot block number.
    // One snapshot per month only.
    mapping(uint16 => mapping(uint8 => uint256)) public monthlySnapshotBlock;

    // Historical checkpoints for account balances.
    mapping(address => Checkpoint[]) private _balanceCheckpoints;

    // List of authorized operators allowed to mint on behalf of users.
    mapping(address => bool) public authorizedUsers;

    // Historical checkpoints for total supply.
    Checkpoint[] private _totalSupplyCheckpoints;
    
    // Custom errors for gas-efficient reverts.
    error ArrayLengthMismatch();
    error EmptyArray();
    error ZeroAccount();
    error ZeroAmount();
    error AmountOverflow();
    error InvalidType();
    error AlreadyMinted();
    error WhitelistAlreadyExists();
    error AccountMismatch();
    error TransfersDisabled();
    error SnapshotAlreadyTaken();
    error InvalidMonth();
    error UserAlreadyAuthorized();
    error UserNotAuthorized();

    // Events for complete off-chain traceability and indexing.
    event MintOccurred(address indexed minter, uint256 indexed index, uint256 amount, uint8 indexed mintType, string rewardType);
    event WhitelistAdded(uint256 indexed index, address indexed account, uint256 amount, uint8 indexed mintType);
    event WhitelistRemoved(uint256 indexed index, address indexed account, uint256 canceledAmount);
    event BatchAddToWhitelistCompleted(uint256 indexed batchId,uint256 count,uint256 startIndex,uint256 endIndex);
    event MonthlySnapshot(uint16 indexed year, uint8 indexed month, uint256 snapshotBlock, uint256 timestamp);
    event AuthorizedUserAdded(address indexed user);
    event AuthorizedUserRemoved(address indexed user);

    // Constructor: requires a valid owner address.
    // The token name and symbol are constant for compatibility and traceability.
    constructor(address initialOwner)
        ERC20("IPLicensingIndex", "IPL")
        Ownable(_assertNonZero(initialOwner))
    {}

    // Utility: revert if address is zero.
    function _assertNonZero(address a) internal pure returns (address) {
        if (a == address(0)) revert ZeroAccount();
        return a;
    }

    // Compress current block number into uint48.
    function _currBlock48() internal view returns (uint48) {
        return uint48(block.number);
    }

    // Push a new checkpoint or overwrite if same block.
    function _pushCheckpoint(Checkpoint[] storage cps, uint208 newValue) internal {
        uint48 b = _currBlock48();
        uint256 len = cps.length;
        if (len != 0 && cps[len - 1].fromBlock == b) {
            cps[len - 1].value = newValue;
        } else {
            cps.push(Checkpoint({fromBlock: b, value: newValue}));
        }
    }

    // Binary search to get historical value at a given block number.
    function _getAtBlock(Checkpoint[] storage cps, uint256 blockNumber) internal view returns (uint256) {
        uint256 len = cps.length;
        if (len == 0) return 0;
        if (blockNumber >= cps[len - 1].fromBlock) {
            return cps[len - 1].value;
        }
        uint256 low = 0;
        uint256 high = len - 1;
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            uint48 fb = cps[mid].fromBlock;
            if (fb == blockNumber) {
                return cps[mid].value;
            } else if (fb < blockNumber) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (cps[low].fromBlock > blockNumber) {
            if (low == 0) return 0;
            return cps[low - 1].value;
        } else {
            return cps[low].value;
        }
    }

    // Record balance checkpoint after minting.
    function _writeBalanceCheckpoint(address account) internal {
        uint256 bal = balanceOf(account);
        if (bal > type(uint208).max) revert AmountOverflow();
        _pushCheckpoint(_balanceCheckpoints[account], uint208(bal));
    }

    // Record total supply checkpoint after minting.
    function _writeTotalSupplyCheckpoint() internal {
        uint256 ts = totalSupply();
        if (ts > type(uint208).max) revert AmountOverflow();
        _pushCheckpoint(_totalSupplyCheckpoints, uint208(ts));
    }

    // Transfers are fully disabled; minting (from == 0) only.
    // This ensures token integrity as a non-transferable index measure.
    function _update(address from, address to, uint256 value) internal virtual override{
        if (from != address(0)) revert TransfersDisabled();
        super._update(from, to, value);
        _writeBalanceCheckpoint(to);
        _writeTotalSupplyCheckpoint();
    }

    // Add an authorized operator (delegated minter).
    function addAuthorizedUser(address user) external onlyOwner {
        if (user == address(0)) revert ZeroAccount();
        if (authorizedUsers[user]) revert UserAlreadyAuthorized();
        authorizedUsers[user] = true;
        emit AuthorizedUserAdded(user);
    }

    // Batch add multiple authorized operators.
    // Validates non-empty and non-zero addresses.
    function batchAddAuthorizedUsers(address[] calldata users) external onlyOwner {
        uint256 length = users.length;
        if (length == 0) revert EmptyArray();

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                address user = users[i];
                
                if (user == address(0)) revert ZeroAccount();
                if (authorizedUsers[user]) continue;
                
                authorizedUsers[user] = true;
                emit AuthorizedUserAdded(user);
            }
        }
    }

    // Remove an authorized operator.
    function removeAuthorizedUser(address user) external onlyOwner {
        if (!authorizedUsers[user]) revert UserNotAuthorized();
        authorizedUsers[user] = false;
        emit AuthorizedUserRemoved(user);
    }

    // Batch whitelist insert.
    // Enforces one entry per unique index, non-zero amount, valid type.
    function batchAddToWhitelist(uint256[] calldata indices, address[] calldata accounts, uint256[] calldata amounts, uint8[] calldata types) external onlyOwner {
        uint256 length = indices.length;
        if (length == 0) revert EmptyArray();
        if (indices.length != accounts.length || indices.length != amounts.length || indices.length != types.length) revert ArrayLengthMismatch();

        batchCounter++;
        uint256 currentBatchId = batchCounter;
        uint256 maxIndex = 0;
        uint256 minIndex = type(uint256).max;

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                uint256 index = indices[i];
                address account = accounts[i];
                uint256 amount = amounts[i];
                uint8 typeValue = types[i];

                if (account == address(0)) revert ZeroAccount();
                if (amount == 0) revert ZeroAmount();
                if (typeValue > uint8(MintType.BonusReward)) revert InvalidType();

                Whitelist memory existing = whitelistByIndex[index];
                if (hasMintedByIndex[index]) revert AlreadyMinted();
                if (existing.account != address(0)) revert WhitelistAlreadyExists();

                whitelistByIndex[index] = Whitelist({
                    account: account,
                    amount: amount,
                    mintType: typeValue
                });

                emit WhitelistAdded(index, account, amount, typeValue);

                if (index > maxIndex) {
                    maxIndex = index;
                }
                if (index < minIndex) {
                    minIndex = index;
                }
            }
        }

        nextIndex = maxIndex + 1;
        emit BatchAddToWhitelistCompleted(currentBatchId, length, minIndex, maxIndex);
    }

    // Batch removal; optionally revert if any were already minted.
    function batchRemoveFromWhitelist(uint256[] calldata indices, bool revertOnMinted) external onlyOwner {
        uint256 length = indices.length; 
        if (length == 0) revert EmptyArray();

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                uint256 index = indices[i]; 

                Whitelist memory wl = whitelistByIndex[index];
                if (wl.account == address(0)) { 
                    continue;
                }

                if (hasMintedByIndex[index]) { 
                    if (revertOnMinted) revert AlreadyMinted();
                    else continue;
                }

                delete whitelistByIndex[index]; 
                emit WhitelistRemoved(index, wl.account, uint256(wl.amount));
            }
        }
    }

    // Mint once per index.
    // The `to` address must match the whitelisted account.
    // Only the listed user or an authorized operator can execute.
    function mint(uint256 index, address to, string calldata rewardType) external nonReentrant {
        if (hasMintedByIndex[index]) revert AlreadyMinted();

        Whitelist memory wl = whitelistByIndex[index];

        if (wl.account == address(0)) revert AccountMismatch();
        if (to != wl.account) revert AccountMismatch();
        if (msg.sender != wl.account) {
            if (!authorizedUsers[msg.sender]) revert UserNotAuthorized();
        }
        if (wl.amount == 0) revert ZeroAmount();

        hasMintedByIndex[index] = true;
        _mint(to, wl.amount);
        emit MintOccurred(to, index, wl.amount, wl.mintType, rewardType);
    }

    // Take monthly snapshot (year, month) → block number.
    // Only one snapshot allowed per month.
    // Typically executed around mid-month UTC to align with accounting cycles.
    function takeMonthlySnapshot(uint16 year, uint8 month) external onlyOwner returns (uint256 snapshotBlock) {
        if (month == 0 || month > 12) revert InvalidMonth();
        if (monthlySnapshotBlock[year][month] != 0) revert SnapshotAlreadyTaken();

        snapshotBlock = block.number; 
        monthlySnapshotBlock[year][month] = snapshotBlock;

        emit MonthlySnapshot(year, month, snapshotBlock, block.timestamp);
    }

    // Retrieve account balance at a given block.
    function balanceOfAtBlock(address account, uint256 blockNumber) public view returns (uint256) {
        return _getAtBlock(_balanceCheckpoints[account], blockNumber);
    }

    // Retrieve total supply at a given block.
    function totalSupplyAtBlock(uint256 blockNumber) public view returns (uint256) {
        return _getAtBlock(_totalSupplyCheckpoints, blockNumber);
    }

    // Get share ratio (scaled by 1e18) for a specific snapshot.
    function getMonthlySnapshotShare(uint16 year, uint8 month, address account) external view returns (uint256 balAt, uint256 totalAt, uint256 shareRay) {
        uint256 snapBlock = monthlySnapshotBlock[year][month];
        if (snapBlock == 0) {
            return (0, 0, 0);  
        }
        balAt = balanceOfAtBlock(account, snapBlock); 
        totalAt = totalSupplyAtBlock(snapBlock);
        shareRay = (totalAt == 0) ? 0 : Math.mulDiv(balAt, 1e18, totalAt);
    }

    // Preview proportional reward for a given month based on allocation.
    function previewMonthlyReward(uint16 year, uint8 month, address account, uint256 monthlyAllocation) external view returns (uint256 reward) {
        uint256 snapBlock = monthlySnapshotBlock[year][month];
        if (snapBlock == 0) return 0; 

        uint256 balAt = balanceOfAtBlock(account, snapBlock);
        uint256 totalAt = totalSupplyAtBlock(snapBlock); 
        reward = (totalAt == 0) ? 0 : Math.mulDiv(monthlyAllocation, balAt, totalAt);
    }

    // Get whitelist entry info for a given index.
    // Returns account, amount, type, and whether it was minted.
    function getWhitelistInfo(uint256 index) external view returns (address account, uint256 amount, MintType mintType, bool isMinted) {
        Whitelist memory wl = whitelistByIndex[index];
        return (
            wl.account,    
            uint256(wl.amount),     
            MintType(wl.mintType),  
            hasMintedByIndex[index]   
        );
    }
}
