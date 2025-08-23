const { execSync } = require('child_process');
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 开始智能合约开发流程...\n");

  try {
    // 1. 编译合约
    console.log("📦 步骤 1: 编译合约...");
    execSync('npx hardhat compile', { stdio: 'inherit' });
    console.log("✅ 编译完成\n");

    // 2. 运行测试
    console.log("🧪 步骤 2: 运行测试...");
    execSync('npx hardhat test', { stdio: 'inherit' });
    console.log("✅ 测试完成\n");

    // 3. 检查是否有本地网络运行
    console.log("🌐 步骤 3: 检查本地网络...");
    try {
      const provider = new ethers.JsonRpcProvider("http://localhost:8545");
      await provider.getBlockNumber();
      console.log("✅ 本地网络正在运行\n");
    } catch (error) {
      console.log("⚠️  本地网络未运行，请先运行: npx hardhat node");
      console.log("然后在另一个终端运行此脚本\n");
      return;
    }

    // 4. 部署到本地网络
    console.log("🚀 步骤 4: 部署到本地网络...");
    execSync('npx hardhat run scripts/deploy-multisig.js --network localhost', { stdio: 'inherit' });
    console.log("✅ 本地部署完成\n");

    console.log("🎉 开发流程完成！");
    console.log("\n📋 下一步建议:");
    console.log("1. 使用 scripts/multisig-example.js 测试合约功能");
    console.log("2. 如果需要，可以部署到测试网进行进一步测试");
    console.log("3. 进行安全审计和优化");

  } catch (error) {
    console.error("❌ 流程执行失败:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 脚本执行失败:", error);
    process.exit(1);
  }); 