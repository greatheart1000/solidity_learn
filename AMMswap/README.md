# AMM Swap 智能合约项目

这是一个基于恒定乘积公式 (x * y = k) 的自动化做市商 (AMM) Swap 智能合约项目，参考了 Uniswap V2 的设计理念。

## 项目结构

```
├── contracts/
│   ├── AMMSwap.sol          # 核心 AMM Swap 合约
│   └── TestToken.sol        # 测试用 ERC20 代币
├── scripts/
│   └── deploy.js            # 部署脚本
├── test/
│   └── AMMSwap.test.js      # 测试文件
├── hardhat.config.js        # Hardhat 配置
├── package.json             # 项目依赖
└── README.md               # 项目说明
```

## 核心功能

### 1. 代币交换 (Swap)
- 支持两种代币之间的交换
- 使用恒定乘积公式计算交换比率
- 包含 0.3% 的交易手续费
- 支持滑点保护

### 2. 流动性管理
- **添加流动性**: 用户可以添加两种代币来提供流动性
- **移除流动性**: 流动性提供者可以移除流动性并取回代币
- **LP 代币**: 流动性提供者获得 LP 代币作为凭证

### 3. 价格计算
- **getAmountOut**: 计算给定输入量的输出量
- **getAmountIn**: 计算获得期望输出量所需的输入量

## 技术实现

### 恒定乘积公式 (x * y = k)

这是 AMM 的核心算法，确保：
- 储备量的乘积在每次交易后保持不变
- 价格随着交易量自动调整
- 提供无限流动性（理论上）

**公式推导**：
```
(x + Δx) * (y - Δy) = x * y
```

### 手续费机制

- 手续费率：0.3%
- 手续费从输入代币中扣除
- 手续费留在流动性池中，增加 LP 的价值

### 安全性特性

1. **重入攻击防护**: 使用 OpenZeppelin 的 `ReentrancyGuard`
2. **滑点保护**: 用户可设置最小输出量
3. **输入验证**: 严格的参数检查
4. **数学安全**: 使用 SafeMath 防止溢出

## 安装和运行

### 1. 安装依赖
```bash
npm install
```

### 2. 编译合约
```bash
npm run compile
```

### 3. 运行测试
```bash
npm test
```

### 4. 部署合约
```bash
# 部署到本地网络
npx hardhat node
npm run deploy:local

# 部署到测试网
npm run deploy
```

## 使用示例

### 添加流动性
```javascript
// 批准代币
await tokenA.approve(ammSwap.address, amount0);
await tokenB.approve(ammSwap.address, amount1);

// 添加流动性
await ammSwap.addLiquidity(amount0, amount1, minLiquidity);
```

### 执行交换
```javascript
// 批准输入代币
await tokenA.approve(ammSwap.address, amountIn);

// 执行交换
await ammSwap.swap(tokenA.address, amountIn, minAmountOut);
```

### 移除流动性
```javascript
// 移除流动性
await ammSwap.removeLiquidity(lpBalance, minAmount0, minAmount1);
```

## 核心算法详解

### 1. 交换输出量计算

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
    public pure returns (uint256 amountOut) {
    
    uint256 amountInWithFee = amountIn.mul(FEE_DENOMINATOR.sub(FEE_NUMERATOR));
    uint256 numerator = amountInWithFee.mul(reserveOut);
    uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
    amountOut = numerator.div(denominator);
}
```

**数学原理**：
- 扣除手续费后的实际输入量：`amountIn * (1 - fee)`
- 根据恒定乘积公式：`(reserveIn + amountInWithFee) * (reserveOut - amountOut) = reserveIn * reserveOut`
- 解得：`amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee)`

### 2. 流动性计算

**首次添加流动性**：
```solidity
liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY
```

**后续添加流动性**：
```solidity
liquidity = min(
    amount0 * totalSupply / reserve0,
    amount1 * totalSupply / reserve1
)
```

### 3. 价格影响

价格影响随着交易量增加而增大：
- 小额交易：价格影响小
- 大额交易：价格影响大
- 这是 AMM 的固有特性，提供滑点保护

## 扩展功能建议

1. **多跳路由**: 支持通过多个池子进行代币交换
2. **价格预言机**: 集成 Chainlink 等价格预言机
3. **治理代币**: 添加治理功能
4. **费用管理**: 动态调整手续费率
5. **流动性挖矿**: 激励流动性提供者

## 安全考虑

1. **审计**: 在生产环境使用前进行专业审计
2. **测试**: 全面的单元测试和集成测试
3. **监控**: 实时监控合约状态和异常交易
4. **升级**: 考虑可升级合约设计
5. **保险**: 为流动性提供者提供保险机制

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 免责声明

本项目仅供学习和研究使用，在生产环境使用前请进行充分的安全审计和测试。 