# 多签名智能合约项目

这是一个基于 Hardhat 3 Beta 的智能合约项目，包含一个简单的计数器合约和一个专门用于管理该计数器合约的多签名合约。

## 项目概述

本项目包含以下功能：

- **Counter.sol**: 简单的计数器智能合约
- **MultiSigCounter.sol**: 专门用于管理Counter合约的多签名合约
- 完整的测试套件（Solidity和TypeScript）
- 部署脚本和使用示例
- 支持本地测试和Sepolia测试网部署

## 多签名合约功能

MultiSigCounter合约提供以下功能：

### 核心功能
- **提案管理**: 创建、投票、执行和取消提案
- **多签名验证**: 需要指定数量的签名才能执行操作
- **Counter合约管理**: 专门用于管理Counter合约的操作
- **签名者管理**: 添加、移除签名者和更新签名要求

### 主要函数
- `createProposal()`: 创建新提案
- `vote()`: 对提案进行投票
- `executeProposal()`: 执行获得足够投票的提案
- `addOwner()` / `removeOwner()`: 管理签名者
- `getCounterValue()`: 获取Counter合约当前值

### 安全特性
- 提案有效期限制
- 防止重复投票
- 防止重复执行
- 只有签名者可以操作

## 开发流程

### 推荐的开发顺序

智能合约开发的最佳实践是：**先测试，再部署**。这样可以确保代码质量并节省成本。

#### 1. 快速开发流程

使用我们提供的自动化脚本：

```shell
# 启动本地网络（在一个终端）
npx hardhat node

# 在另一个终端运行完整流程
node scripts/dev-workflow.js
```

#### 2. 手动开发流程

如果你想手动控制每个步骤：

**步骤 1: 编译合约**
```shell
npx hardhat compile
```

**步骤 2: 运行测试**
```shell
# 运行所有测试
npx hardhat test

# 分别运行Solidity或TypeScript测试
npx hardhat test solidity
npx hardhat test mocha
```

**步骤 3: 本地部署测试**
```shell
# 启动本地网络
npx hardhat node

# 在另一个终端部署到本地网络
npx hardhat run scripts/deploy-multisig.js --network localhost
```

**步骤 4: 测试网部署**（可选）
```shell
npx hardhat run scripts/deploy-multisig.js --network sepolia
```

### 为什么先测试？

- ✅ **快速反馈**：立即发现代码问题
- ✅ **节省成本**：本地测试免费，链上测试需要gas费
- ✅ **迭代开发**：快速修改和重新测试
- ✅ **确保质量**：通过测试验证合约逻辑正确性
- ✅ **安全第一**：避免在链上部署有问题的合约

## 使用方法

#### 本地部署

部署到本地网络：

```shell
npx hardhat run scripts/deploy-multisig.js --network localhost
```

#### 部署到Sepolia测试网

1. 设置私钥（使用hardhat-keystore插件）：

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

2. 部署合约：

```shell
npx hardhat run scripts/deploy-multisig.js --network sepolia
```

### 使用示例

运行多签名合约使用示例：

```shell
# 首先修改 scripts/multisig-example.js 中的合约地址
npx hardhat run scripts/multisig-example.js --network <network>
```

### 合约交互

#### 创建提案
```javascript
const data = counter.interface.encodeFunctionData("inc");
await multiSig.createProposal(data, "增加计数器", 3600);
```

#### 投票
```javascript
await multiSig.vote(proposalId, true); // 赞成
await multiSig.vote(proposalId, false); // 反对
```

#### 执行提案
```javascript
await multiSig.executeProposal(proposalId);
```

#### 管理签名者
```javascript
await multiSig.addOwner(newOwnerAddress);
await multiSig.removeOwner(ownerToRemove);
await multiSig.updateRequiredSignatures(newRequiredCount);
```
