## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/NFTMarket.s.sol:NFTMarket --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# TokenBank 智能合约

TokenBank是一个ERC20代币银行合约，用户可以在其中存款和取款ERC20代币。此项目包含了支持Permit2签名授权的功能，使用户能够在一个交易中完成授权和转账操作。

## 功能特点

- 支持多种ERC20代币
- 安全的存款和取款机制
- 支持Permit2签名授权存款，减少交易次数
- 紧急提款功能（仅限合约所有者）
- 代币白名单管理

## Permit2集成

TokenBank集成了Uniswap的Permit2协议，提供以下优势：

1. **单交易流程**: 用户可以在一个交易中完成授权和存款
2. **支持所有ERC20代币**: 无论代币是否原生支持EIP-2612的permit功能
3. **降低Gas成本**: 减少链上交易数量
4. **过期机制**: 授权有时间限制，增强安全性

## 使用指南

### 部署合约

1. 克隆仓库并安装依赖:
```bash
git clone <repository-url>
cd <repository-directory>
forge install
```

2. 准备环境变量:
```bash
cp .env.example .env
# 编辑.env文件，填入部署私钥和其他必要参数
```

3. 编译合约:
```bash
forge build
```

4. 部署合约:
```bash
forge script script/TokenBank.s.sol:TokenBankScript --rpc-url $RPC_URL --broadcast --verify -vvvv
```

### 使用Permit2存款

要使用Permit2功能进行存款，用户需要:

1. 首先批准Permit2合约(0x000000000022D473030F116dDEE9F6B43aC78BA3)操作其代币（一次性操作）
2. 生成一个包含授权数据的签名
3. 调用`depositWithPermit2`函数完成存款

前端示例代码:
```javascript
// 授权Permit2合约（一次性操作）
const permitContract = "0x000000000022D473030F116dDEE9F6B43aC78BA3";
await tokenContract.approve(permitContract, ethers.constants.MaxUint256);

// 为存款生成签名
const domain = {
  name: 'Permit2',
  chainId: chainId,
  verifyingContract: permitContract
};

const types = {
  PermitTransferFrom: [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
  ],
  TokenPermissions: [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' }
  ]
};

const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
const nonce = Math.floor(Math.random() * 1000000);

const value = {
  permitted: {
    token: tokenAddress,
    amount: depositAmount
  },
  nonce: nonce,
  deadline: deadline
};

const signature = await signer._signTypedData(domain, types, value);

// 调用depositWithPermit2函数
await tokenBankContract.depositWithPermit2(
  tokenAddress,
  depositAmount,
  nonce,
  deadline,
  signature
);
```

## 合约 ABI

生成ABI:
```bash
forge inspect TokenBank abi > TokenBank_abi.json
```

## 安全注意事项

- TokenBank使用OpenZeppelin的SafeERC20库和ReentrancyGuard防止重入攻击
- Permit2签名有时间限制，过期后签名将无效
- 考虑在生产环境中进行完整的安全审计

## Permit2相关资源

- [Uniswap Permit2文档](https://docs.uniswap.org/concepts/permit2)
- [Permit2 GitHub仓库](https://github.com/Uniswap/permit2)

## 许可证

MIT


forge script script/TokenBank.s.sol:TokenBankScript --rpc-url http://127.0.0.1:8545 --broadcast


forge create --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 src/MockToken.sol:MockToken --broadcast

forge create --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 src/esRNT.sol:esRNT --broadcast

# 可升级合约示例

这个项目展示了如何使用OpenZeppelin的可升级合约模式（UUPS代理模式）创建可升级的智能合约。

## 合约结构

- `UpgradeableBox.sol`: 初始版本的可升级合约，具有基本的存储和检索功能
- `UpgradeableBoxV2.sol`: 升级版本，增加了名称设置和值增加功能

## 测试

运行以下命令测试合约的功能和升级过程：

```bash
forge test -vvv
```

测试案例包括：
- 初始值设置和读取
- 存储功能测试
- 合约升级过程
- 新增功能测试
- 未授权升级尝试

## 部署

### 部署初始版本

1. 设置环境变量：

```bash
export PRIVATE_KEY=你的私钥
```

2. 运行部署脚本：

```bash
forge script script/DeployUpgradeableBox.s.sol:DeployUpgradeableBox --rpc-url <你的RPC_URL> --broadcast
```

3. 记录输出中的代理地址，用于后续升级

### 升级到V2版本

1. 设置环境变量：

```bash
export PRIVATE_KEY=你的私钥
export PROXY_ADDRESS=之前部署的代理地址
```

2. 运行升级脚本：

```bash
forge script script/UpgradeToV2.s.sol:UpgradeToV2 --rpc-url <你的RPC_URL> --broadcast
```

## 可升级合约的关键点

1. **代理模式**：使用了UUPS (Universal Upgradeable Proxy Standard) 代理模式
2. **状态分离**：逻辑和状态分离，使得可以升级逻辑而保留状态
3. **初始化函数**：使用`initialize`替代构造函数
4. **不可变量注意事项**：升级时需要保持存储布局兼容
5. **访问控制**：只有合约所有者可以升级合约