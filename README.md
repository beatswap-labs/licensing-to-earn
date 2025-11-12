# Licensing-to-Earn

A decentralized **IP licensing and reward distribution DApp** built on **opBNB Mainnet (BNB Smart Chain Layer 2)**.  
It tokenizes intellectual property rights, automates licensing rewards, and optimizes gas costs through efficient on-chain minting and accounting.

---

## Technology Stack

- **Blockchain**: opBNB Mainnet (BNB Smart Chain Layer 2, EVM compatible)  
- **Smart Contracts**: Solidity ^0.8.27 (OpenZeppelin ERC-20 base)  
- **Backend**: Node.js + TypeScript + Express.js  
- **Blockchain Library**: ethers.js v5.7.2  
- **Tools**: Hardhat + TypeScript  

---

## Supported Network

- **opBNB Mainnet** (Chain ID: 204)

---

## Contract Information

| Network       | Contract Name    | Address                                                                 |
|----------------|------------------|--------------------------------------------------------------------------|
| opBNB Mainnet  | IPLicensingIndex | [0xdEB3FC49eb63765CDAbCD0917ae4D90b75847001](https://opbnb.bscscan.com/token/0xdEB3FC49eb63765CDAbCD0917ae4D90b75847001) |

**Token Name:** IP Licensing Index  
**Token Symbol:** IPL  

---

## Core Features

- **Licensing-to-Earn Model** – Users earn rewards by participating in verified IP licensing events.  
- **Whitelist-based Minting** – Secure, authorized minting with multiple reward classifications.  
- **Monthly Snapshots** – On-chain balance freezing for verifiable reward calculations.  
- **Authorized Roles** – Role-based access control for operators and automated services.  
- **Event Transparency** – Rich event logs for analytics and distribution tracking.  
- **Gas-Optimized Design** – Low-cost operation using opBNB Layer 2 scalability.

---

## System Architecture

```plaintext
licensing-to-earn/
├── ipl-contracts/              # Smart contracts (Solidity)
│   └── IPLicensingIndex.sol
├── ipl-middleware/             # Backend API & blockchain integration
│   ├── features/
│   │   ├── contracts/          # Contract management endpoints
│   │   └── minting/            # Minting API and worker logic
│   └── shared/
│       ├── blockchain/         # Web3 provider and event listeners
│       └── config/             # opBNB RPC configuration
└── vault-proxy-middleware/     # Proxy routing layer
```
---

## Configuration

### Environment Variables

```bash
# Network Configuration
OP_BNB_RPC_URL=https://opbnb-mainnet-rpc.bnbchain.org

# Contract Addresses
IP_LICENSING_INDEX_CONTRACT_ADDRESS=0xdEB3FC49eb63765CDAbCD0917ae4D90b75847001
```

---

## Why opBNB

**Fast & Scalable** – Optimized for high-frequency minting and data writes.  
**Low Gas Fees** – Ideal for recurring licensing and reward distributions.  
**Secure** – Inherits BNB Smart Chain validator security.  
**Ecosystem Access** – Compatible with BNB wallets, DeFi tools, and SDKs.  

---

## License

Licensed under the **MIT License**.

---

## Support

- Open an issue on **GitHub** for questions or bug reports.  
- Contact the development team for partnership or integration inquiries.  

---

**Repository Name:** `licensing-to-earn`  
**Primary Network:** opBNB Mainnet (Chain ID: 204)  
**Verified Contract:** `0xdEB3FC49eb63765CDAbCD0917ae4D90b75847001`  
**Token Name:** IP Licensing Index  
**Token Symbol:** IPL  

---

**© 2025 Licensing-to-Earn | Built for the opBNB Mainnet Ecosystem**
