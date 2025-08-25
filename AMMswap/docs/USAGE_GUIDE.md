# AMM Swap 合约使用指南

## 快速开始

### 1. 启动本地区块链网络

```bash
# 启动 Hardhat 本地网络
npx hardhat node
```

这会启动一个本地以太坊网络，并显示 20 个预配置的账户及其私钥。

### 2. 部署合约

在新的终端窗口中：

```bash
# 部署合约到本地网络
npm run deploy:local
```

部署完成后，您会看到类似以下的输出：
```
Token A: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Token B: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
AMM Swap: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

请记录这些地址，后续会用到。

### 3. 运行交互演示

```bash
# 运行完整的交互演示
npm run interact
```

这个脚本会演示：
- 添加流动性
- 代币交换
- 价格影响分析
- 移除流动性
- 手续费收益

## 交互方式

### 方式一：命令行交互

#### 使用 Hardhat Console

```bash
# 启动 Hardhat Console
npx hardhat console --network localhost
```

在 console 中进行交互：

```javascript
// 获取账户
const [deployer, user1, user2] = await ethers.getSigners();

// 部署合约（如果还没有部署）
const TestToken = await ethers.getContractFactory("TestToken");
const tokenA = await TestToken.deploy("Token A", "TKA", 18, 1000000);
const tokenB = await TestToken.deploy("Token B", "TKB", 18, 1000000);

const AMMSwap = await ethers.getContractFactory("AMMSwap");
const ammSwap = await AMMSwap.deploy(tokenA.address, tokenB.address);

// 为测试用户铸造代币
await tokenA.mint(user1.address, ethers.utils.parseEther("10000"));
await tokenB.mint(user1.address, ethers.utils.parseEther("10000"));

// 添加流动性
await tokenA.connect(user1).approve(ammSwap.address, ethers.utils.parseEther("1000"));
await tokenB.connect(user1).approve(ammSwap.address, ethers.utils.parseEther("1000"));
await ammSwap.connect(user1).addLiquidity(
    ethers.utils.parseEther("1000"), 
    ethers.utils.parseEther("1000"), 
    0
);

// 查看流动性池状态
const [reserve0, reserve1] = await ammSwap.getReserves();
console.log("流动性池:", ethers.utils.formatEther(reserve0), "TokenA,", ethers.utils.formatEther(reserve1), "TokenB");

// 执行交换
await tokenA.connect(user2).approve(ammSwap.address, ethers.utils.parseEther("100"));
await ammSwap.connect(user2).swap(
    tokenA.address, 
    ethers.utils.parseEther("100"), 
    ethers.utils.parseEther("95")
);
```

#### 使用交互脚本

```bash
# 运行预配置的交互脚本
npm run interact
```

### 方式二：图形界面交互

#### 启动前端服务器

```bash
# 启动前端服务器
npm run serve
```

然后在浏览器中访问 `http://localhost:3000`

#### 使用前端界面

1. **连接钱包**
   - 点击"连接 MetaMask"按钮
   - 确保 MetaMask 连接到本地网络（localhost:8545）

2. **配置合约地址**
   - 在"合约地址配置"部分输入部署时获得的地址：
     - Token A 地址
     - Token B 地址
     - AMM Swap 合约地址
   - 点击"加载合约"

3. **查看信息**
   - 点击"刷新池信息"查看流动性池状态
   - 点击"刷新余额"查看代币余额

4. **添加流动性**
   - 输入要添加的 Token A 和 Token B 数量
   - 点击"添加流动性"

5. **执行交换**
   - 选择交换方向（A→B 或 B→A）
   - 输入交换数量和最小输出量
   - 点击"执行交换"

6. **移除流动性**
   - 输入要移除的 LP 代币数量
   - 点击"移除流动性"

## 常用操作示例

### 1. 添加流动性

```javascript
// 批准代币
await tokenA.approve(ammSwap.address, ethers.utils.parseEther("1000"));
await tokenB.approve(ammSwap.address, ethers.utils.parseEther("1000"));

// 添加流动性
const tx = await ammSwap.addLiquidity(
    ethers.utils.parseEther("1000"), 
    ethers.utils.parseEther("1000"), 
    0
);
await tx.wait();
```

### 2. 执行代币交换

```javascript
// 计算预期输出量
const [reserve0, reserve1] = await ammSwap.getReserves();
const expectedOutput = await ammSwap.getAmountOut(
    ethers.utils.parseEther("100"), 
    reserve0, 
    reserve1
);

// 设置滑点保护（5%）
const minAmountOut = expectedOutput.mul(95).div(100);

// 批准代币
await tokenA.approve(ammSwap.address, ethers.utils.parseEther("100"));

// 执行交换
const tx = await ammSwap.swap(
    tokenA.address, 
    ethers.utils.parseEther("100"), 
    minAmountOut
);
await tx.wait();
```

### 3. 移除流动性

```javascript
// 获取 LP 代币余额
const lpBalance = await ammSwap.balanceOf(userAddress);

// 移除流动性
const tx = await ammSwap.removeLiquidity(lpBalance, 0, 0);
await tx.wait();
```

### 4. 查看价格影响

```javascript
// 计算价格影响
const swapAmount = ethers.utils.parseEther("100");
const [reserve0, reserve1] = await ammSwap.getReserves();
const priceImpact = swapAmount.mul(100).div(reserve0);
console.log("价格影响:", priceImpact.toString(), "%");
```

## 重要概念

### 1. 滑点保护

滑点保护是防止因价格波动导致意外损失的重要机制：

```javascript
// 计算预期输出量
const expectedOutput = await ammSwap.getAmountOut(amountIn, reserveIn, reserveOut);

// 设置滑点保护（例如 5%）
const minAmountOut = expectedOutput.mul(95).div(100);

// 如果实际输出量小于 minAmountOut，交易会失败
await ammSwap.swap(tokenIn, amountIn, minAmountOut);
```

### 2. 价格影响

价格影响随着交易量增加而增大：

```javascript
// 价格影响 = (交易量 / 储备量) * 100%
const priceImpact = (amountIn / reserveIn) * 100;
```

### 3. 手续费

每次交易收取 0.3% 手续费：

```javascript
// 手续费从输入代币中扣除
const fee = amountIn * 0.003;
const actualInput = amountIn - fee;
```

## 故障排除

### 1. 交易失败

**错误**: `AMMSwap: INSUFFICIENT_OUTPUT_AMOUNT`

**解决方案**: 降低 `minAmountOut` 参数，或减少交易量

### 2. 余额不足

**错误**: `ERC20: transfer amount exceeds balance`

**解决方案**: 确保账户有足够的代币余额

### 3. 批准不足

**错误**: `ERC20: transfer amount exceeds allowance`

**解决方案**: 先调用 `approve` 函数批准足够的代币

### 4. 流动性不足

**错误**: `AMMSwap: INSUFFICIENT_LIQUIDITY`

**解决方案**: 先添加流动性到池子中

## 高级功能

### 1. 批量操作

```javascript
// 批量添加流动性
for (let i = 0; i < 5; i++) {
    await ammSwap.addLiquidity(
        ethers.utils.parseEther("100"), 
        ethers.utils.parseEther("100"), 
        0
    );
}
```

### 2. 监控价格变化

```javascript
// 监听 Swap 事件
ammSwap.on("Swap", (user, tokenIn, tokenOut, amountIn, amountOut) => {
    console.log("交换事件:", {
        user,
        tokenIn,
        tokenOut,
        amountIn: ethers.utils.formatEther(amountIn),
        amountOut: ethers.utils.formatEther(amountOut)
    });
});
```

### 3. 计算收益率

```javascript
// 计算流动性提供者的收益率
const initialValue = ethers.utils.parseEther("2000"); // 初始投入
const currentValue = reserve0.add(reserve1); // 当前池子价值
const yield = currentValue.sub(initialValue);
const yieldRate = yield.mul(100).div(initialValue);
console.log("收益率:", ethers.utils.formatEther(yieldRate), "%");
```

## 安全注意事项

1. **私钥安全**: 永远不要在生产环境中使用测试私钥
2. **滑点保护**: 始终设置合理的滑点保护参数
3. **测试**: 在测试网络上充分测试后再部署到主网
4. **审计**: 在生产环境使用前进行专业安全审计
5. **监控**: 实时监控合约状态和异常交易

## 扩展阅读

- [AMM 原理详解](./TECHNICAL_DETAILS.md)
- [Uniswap V2 白皮书](https://uniswap.org/whitepaper-v2.pdf)
- [DeFi 安全最佳实践](https://consensys.net/diligence/best-practices/) 