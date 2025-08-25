const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("使用账户部署:", deployer.address);
    console.log("账户余额:", (await deployer.getBalance()).toString());

    // 部署测试代币
    console.log("\n部署测试代币...");
    
    const TestToken = await ethers.getContractFactory("TestToken");
    const tokenA = await TestToken.deploy("Token A", "TKA", 18, 1000000); // 100万代币
    await tokenA.deployed();
    console.log("Token A 已部署到:", tokenA.address);

    const tokenB = await TestToken.deploy("Token B", "TKB", 18, 1000000); // 100万代币
    await tokenB.deployed();
    console.log("Token B 已部署到:", tokenB.address);

    // 部署 AMM Swap 合约
    console.log("\n部署 AMM Swap 合约...");
    const AMMSwap = await ethers.getContractFactory("AMMSwap");
    const ammSwap = await AMMSwap.deploy(tokenA.address, tokenB.address);
    await ammSwap.deployed();
    console.log("AMM Swap 合约已部署到:", ammSwap.address);

    // 为测试用户铸造代币
    console.log("\n为测试用户铸造代币...");
    const testUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; // Hardhat 默认账户
    
    await tokenA.mint(testUser, ethers.utils.parseEther("10000"));
    await tokenB.mint(testUser, ethers.utils.parseEther("10000"));
    console.log("已为测试用户铸造 10000 个 Token A 和 Token B");

    // 为部署者铸造代币
    await tokenA.mint(deployer.address, ethers.utils.parseEther("50000"));
    await tokenB.mint(deployer.address, ethers.utils.parseEther("50000"));
    console.log("已为部署者铸造 50000 个 Token A 和 Token B");

    console.log("\n部署完成！");
    console.log("=== 合约地址 ===");
    console.log("Token A:", tokenA.address);
    console.log("Token B:", tokenB.address);
    console.log("AMM Swap:", ammSwap.address);
    console.log("==================");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 