import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
  console.log("开始部署合约...");

  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");

  // 部署Counter合约
  console.log("\n1. 部署Counter合约...");
  const Counter = await ethers.getContractFactory("Counter");
  const counter = await Counter.deploy();
  await counter.waitForDeployment();
  const counterAddress = await counter.getAddress();
  console.log("Counter合约已部署到:", counterAddress);

  // 设置多签名合约的签名者
  // 这里使用前3个账户作为签名者，你也可以根据需要修改
  const signers = await ethers.getSigners();
  const owners = [
    signers[0].address,  // 部署者
    signers[1].address,  // 第二个签名者
    signers[2].address   // 第三个签名者
  ];
  const requiredSignatures = 2; // 需要2个签名才能执行操作

  console.log("\n2. 部署MultiSigCounter合约...");
  console.log("签名者地址:");
  owners.forEach((owner, index) => {
    console.log(`  签名者 ${index + 1}: ${owner}`);
  });
  console.log("需要的签名数量:", requiredSignatures);

  // 部署MultiSigCounter合约
  const MultiSigCounter = await ethers.getContractFactory("MultiSigCounter");
  const multiSig = await MultiSigCounter.deploy(owners, requiredSignatures, counterAddress);
  await multiSig.waitForDeployment();
  const multiSigAddress = await multiSig.getAddress();
  console.log("MultiSigCounter合约已部署到:", multiSigAddress);

  // 验证部署
  console.log("\n3. 验证部署...");
  console.log("Counter合约地址:", await multiSig.counterContract());
  console.log("签名者数量:", (await multiSig.getOwners()).length);
  console.log("需要的签名数量:", await multiSig.requiredSignatures());

  // 验证签名者
  for (let i = 0; i < owners.length; i++) {
    const isOwner = await multiSig.isOwner(owners[i]);
    console.log(`签名者 ${i + 1} (${owners[i]}) 是否有效:`, isOwner);
  }

  console.log("\n✅ 部署完成!");
  console.log("\n📋 部署摘要:");
  console.log("Counter合约:", counterAddress);
  console.log("MultiSigCounter合约:", multiSigAddress);
  console.log("签名者:", owners.join(", "));
  console.log("需要的签名数量:", requiredSignatures);

  console.log("\n🔧 使用说明:");
  console.log("1. 只有签名者可以创建提案");
  console.log("2. 需要足够的签名才能执行提案");
  console.log("3. 可以通过提案调用Counter合约的inc()和incBy()函数");
  console.log("4. 使用multiSig.createProposal()创建提案");
  console.log("5. 使用multiSig.vote()进行投票");
  console.log("6. 使用multiSig.executeProposal()执行提案");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  }); 