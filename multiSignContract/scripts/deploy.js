// scripts/deploy.js
import hre from "hardhat"; // <-- 更改点 1: 导入整个 Hardhat Runtime Environment

async function main() {
  // 从 hre 中解构出 ethers 对象
  const { ethers } = hre; // <-- 更改点 2: 从 hre 中获取 ethers

  // 获取你的合约工厂
  const Counter = await ethers.getContractFactory("Counter");

  // 部署合约
  console.log("部署 Counter 合约...");
  const counter = await Counter.deploy();

  // 等待合约部署完成并获取部署地址
  await counter.waitForDeployment();
  console.log(`Counter 合约已部署到地址: ${counter.target}`);
}

// Node.js 中 ES 模块的常见运行模式
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});