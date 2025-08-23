```
# Hardhat 脚本与智能合约交互解析

本文档整理了在使用 Hardhat 脚本时，与智能合约进行交互的一些核心概念和常见问题。

---

## 1. Hardhat 中的账户（Signer）

**问：** `const [owner1, owner2, owner3, nonOwner] = await ethers.getSigners();` 这样的代码可以获取账户地址吗？为什么？

**答：** 是的，这行代码可以获取账户。`ethers.getSigners()` 是一个异步方法，它返回一个由 **Signer** 对象组成的数组。这些对象代表了 Hardhat 本地网络中的测试账户。`[owner1, owner2, ...]` 是 JavaScript 的**数组解构赋值**语法，它将数组中的前几个元素按顺序赋值给对应的变量。

`nonOwner` 这样的命名是为了在测试中明确其角色，例如用来测试合约的权限控制。

**问：** `console.log("签名者1:", owner1.address);` 难道 `owner1` 不是地址吗？为什么是 `owner1.address`？`owner1` 里面有哪些属性？

**答：** `owner1` **不是地址，而是一个功能强大的 Signer 对象**。它代表了区块链上的一个账户，并提供了多种与该账户交互的方法和属性。

`owner1.address` 是访问这个 **Signer 对象**所代表的账户地址的属性。

一个 **Signer 对象**包含许多重要的属性和方法，例如：
* `.address`: 获取账户地址。
* `.getBalance()`: 获取账户的 ETH 余额。
* `.sendTransaction()`: 发送一笔交易。
* `.signMessage()`: 对数据进行签名。

---

## 2. 连接已部署的合约

**问：** `const counter = Counter.attach(counterAddress);` 这行代码是什么意思？

**答：** `Counter.attach(counterAddress)` 的作用是将一个**合约工厂（Contract Factory）**与一个**已部署在区块链上的真实合约地址**连接起来。

* `ethers.getContractFactory("Counter")` 获取的是合约的“蓝图”或“类”。
* `.attach()` 方法将这个“蓝图”绑定到一个已存在的“实例”（即链上地址 `counterAddress`），从而使 `counter` 变量成为一个可以直接调用链上合约函数的对象。

---

## 3. 函数调用数据编码与事件解析

**问：** `const incData = counter.interface.encodeFunctionData("inc");` 这段代码是什么意思？这算是调用 `inc` 函数吗？

**答：** 这行代码的作用是**对函数调用进行编码，但不发送交易**。它将函数名和参数转换为以太坊虚拟机（EVM）可以理解的、用于发起交易的十六进制数据。这个过程是**纯粹的本地计算**，没有与区块链网络交互。

这**不算是调用** `inc` 函数，真正的调用需要将这段编码好的数据发送到网络上。这种编码方式常用于多签名合约，将“调用指令”作为数据传递给多签合约创建提案。

**问：** `createReceipt.logs.find(...)` 是用来找到名为 `ProposalCreated` 的事件吗？

**答：** 是的，你的理解完全正确。当一笔交易成功执行后，`createReceipt`（交易收据）会包含一个 `logs` 数组，存储了这笔交易触发的所有事件。`find` 方法会遍历这个数组，并使用 `multiSig.interface.parseLog(log)` 将原始日志数据解析成可读的事件对象，从而找到我们关心的 `ProposalCreated` 事件。

**问：** `createEvent` 就是为了拿到 `proposalId` 对吗？`createReceipt` 是什么？

**答：** 是的，**`createEvent` 的主要目的就是为了获取 `proposalId`**。`proposalId` 是创建提案后生成的唯一标识，是后续所有操作（如投票、执行）的必需参数。

`createReceipt` 是一个**交易收据（TransactionReceipt）**对象，它包含了交易被打包进区块后的所有详细信息，例如交易哈希、区块号、Gas 消耗以及最重要的**日志（`logs`）数组**。我们通过解析 `logs` 数组来获取事件数据。

---

## 4. 交易与同步

**问：** `const createTx = await multiSig.connect(owner1).createProposal(...);` 之后的 `createTx.wait()` 是什么意思？

**答：** `.wait()` 是一个关键的操作，它让你的脚本**等待**一笔交易被成功打包进区块链。

* `multiSig.connect(owner1).createProposal(...)` 这部分代码只是将交易发送到待处理交易池。
* `.wait()` 方法会暂停脚本执行，直到这笔交易被确认并返回一个**交易收据（TransactionReceipt）**。

使用 `.wait()` 是为了确保脚本中的操作是同步的，即在一个链上操作完成后，再执行下一步依赖它的操作。

**问：** 为什么 `owner2` 投票没有获取事件？`owner1` 是多签名合约地址吗？

**答：**
1.  **关于事件：** `owner2` 投票不需要获取事件，因为投票操作的输入（`proposalId`）在之前创建提案时已经获取到了。只有当一个操作的结果是另一个操作的必需输入时，才需要获取并解析事件。
2.  **关于地址：** `owner1` **不是多签名合约的地址**。`owner1` 是一个 **Signer 对象**，代表一个独立的外部账户（EOA），它是多签名合约的**所有者之一**。`multiSig` 才是多签名合约的实例，代表它的地址。`multiSig.connect(owner1)` 语法用于指定这笔交易的发送者是 `owner1` 这个账户。
