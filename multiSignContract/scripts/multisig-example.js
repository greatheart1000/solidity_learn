import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
  console.log("🚀 多签名合约使用示例");
  console.log("========================\n");

  // 获取账户
  const [owner1, owner2, owner3, nonOwner] = await ethers.getSigners();
  
  // 使用刚刚部署的合约地址
  const counterAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"; // Counter合约地址
  const multiSigAddress = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"; // MultiSigCounter合约地址
  
  console.log("📋 账户信息:");
  console.log("签名者1:", owner1.address);
  console.log("签名者2:", owner2.address);
  console.log("签名者3:", owner3.address);
  console.log("非签名者:", nonOwner.address);
  console.log("Counter合约:", counterAddress);
  console.log("MultiSig合约:", multiSigAddress);
  console.log("");

  // 连接到合约
  const Counter = await ethers.getContractFactory("Counter");
  const MultiSigCounter = await ethers.getContractFactory("MultiSigCounter");
  
  const counter = Counter.attach(counterAddress);
  const multiSig = MultiSigCounter.attach(multiSigAddress);

  try {
    // 1. 查看当前Counter值
    console.log("1️⃣ 查看当前Counter值");
    const currentValue = await counter.x();
    console.log("当前Counter值:", currentValue.toString());
    console.log("");

    // 2. 创建提案 - 调用inc()函数
    console.log("2️⃣ 创建提案 - 调用inc()函数");
    const incData = counter.interface.encodeFunctionData("inc");
    const description = "增加计数器1";
    const duration = 3600; // 1小时有效期

    const createTx = await multiSig.connect(owner1).createProposal(incData, description, duration);
    const createReceipt = await createTx.wait();
    
    // 从事件中获取提案ID
    const createEvent = createReceipt.logs.find(log => {
      try {
        return multiSig.interface.parseLog(log)?.name === "ProposalCreated";
      } catch {
        return false;
      }
    });
    
    const proposalId = multiSig.interface.parseLog(createEvent).args[0];
    console.log("提案已创建，ID:", proposalId.toString());
    console.log("提案描述:", description);
    console.log("");

    // 3. 投票
    console.log("3️⃣ 进行投票");
    
    // 签名者1投票赞成
    console.log("签名者1投票赞成...");
    await multiSig.connect(owner1).vote(proposalId, true);
    console.log("✅ 签名者1投票完成");
    
    // 签名者2投票赞成
    console.log("签名者2投票赞成...");
    await multiSig.connect(owner2).vote(proposalId, true);
    console.log("✅ 签名者2投票完成");
    
    // 签名者3投票反对（可选）
    console.log("签名者3投票反对...");
    await multiSig.connect(owner3).vote(proposalId, false);
    console.log("✅ 签名者3投票完成");
    console.log("");

    // 4. 查看投票结果
    console.log("4️⃣ 查看投票结果");
    const proposal = await multiSig.getProposal(proposalId);
    console.log("赞成票数:", proposal.yesVotes.toString());
    console.log("反对票数:", proposal.noVotes.toString());
    console.log("提案状态:", proposal.executed ? "已执行" : "未执行");
    console.log("");

    // 5. 执行提案
    console.log("5️⃣ 执行提案");
    if (proposal.yesVotes >= 2) { // 假设需要2个签名
      console.log("赞成票数足够，执行提案...");
      await multiSig.connect(owner1).executeProposal(proposalId);
      console.log("✅ 提案执行成功");
      
      // 验证结果
      const newValue = await counter.x();
      console.log("执行后Counter值:", newValue.toString());
    } else {
      console.log("❌ 赞成票数不足，无法执行提案");
    }
    console.log("");

    // 6. 创建另一个提案 - 调用incBy()函数
    console.log("6️⃣ 创建提案 - 调用incBy(5)函数");
    const incrementValue = 5;
    const incByData = counter.interface.encodeFunctionData("incBy", [incrementValue]);
    const description2 = `增加计数器${incrementValue}`;

    const createTx2 = await multiSig.connect(owner2).createProposal(incByData, description2, duration);
    const createReceipt2 = await createTx2.wait();
    
    const createEvent2 = createReceipt2.logs.find(log => {
      try {
        return multiSig.interface.parseLog(log)?.name === "ProposalCreated";
      } catch {
        return false;
      }
    });
    
    const proposalId2 = multiSig.interface.parseLog(createEvent2).args[0];
    console.log("新提案已创建，ID:", proposalId2.toString());
    console.log("提案描述:", description2);
    console.log("");

    // 7. 快速投票和执行
    console.log("7️⃣ 快速投票和执行");
    await multiSig.connect(owner1).vote(proposalId2, true);
    await multiSig.connect(owner2).vote(proposalId2, true);
    await multiSig.connect(owner3).executeProposal(proposalId2);
    console.log("✅ 第二个提案执行完成");
    
    const finalValue = await counter.x();
    console.log("最终Counter值:", finalValue.toString());
    console.log("");

    // 8. 查看所有提案
    console.log("8️⃣ 查看所有提案");
    const totalProposals = await multiSig.proposalCount();
    console.log("总提案数:", totalProposals.toString());
    
    for (let i = 0; i < totalProposals; i++) {
      const prop = await multiSig.getProposal(i);
      console.log(`提案 ${i}:`);
      console.log(`  描述: ${prop.description}`);
      console.log(`  赞成票: ${prop.yesVotes}`);
      console.log(`  反对票: ${prop.noVotes}`);
      console.log(`  状态: ${prop.executed ? "已执行" : prop.cancelled ? "已取消" : "待处理"}`);
    }
    console.log("");

    // 9. 签名者管理示例
    console.log("9️⃣ 签名者管理示例");
    console.log("当前签名者:");
    const owners = await multiSig.getOwners();
    owners.forEach((owner, index) => {
      console.log(`  签名者 ${index + 1}: ${owner}`);
    });
    
    const requiredSigs = await multiSig.requiredSignatures();
    console.log("需要的签名数量:", requiredSigs.toString());
    console.log("");

    console.log("🎉 示例执行完成!");

  } catch (error) {
    console.error("❌ 执行过程中出现错误:", error.message);
  }
}

// 使用说明
console.log("📖 使用说明:");
console.log("1. 请先运行 deploy-multisig.js 部署合约");
console.log("2. 将脚本中的合约地址替换为实际部署的地址");
console.log("3. 确保账户有足够的ETH支付gas费用");
console.log("4. 运行: npx hardhat run scripts/multisig-example.js --network <network>");
console.log("");

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("脚本执行失败:", error);
    process.exit(1);
  }); 