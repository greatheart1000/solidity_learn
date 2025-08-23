import { expect } from "chai";
import { network } from "hardhat";
import { Counter, MultiSigCounter } from "../typechain-types";

const { ethers } = await network.connect();

describe("MultiSigCounter", function () {
  let counter: Counter;
  let multiSig: MultiSigCounter;
  let owner1: any, owner2: any, owner3: any, nonOwner: any;

  
  beforeEach(async function () {
    // 获取测试账户
    [owner1, owner2, owner3, nonOwner] = await ethers.getSigners();

    // 部署Counter合约
    const CounterFactory = await ethers.getContractFactory("Counter");
    counter = await CounterFactory.deploy();

    // 部署MultiSigCounter合约
    const MultiSigFactory = await ethers.getContractFactory("MultiSigCounter");
    const owners = [owner1.address, owner2.address, owner3.address];
    const requiredSignatures = 2; // 需要2个签名
    multiSig = await MultiSigFactory.deploy(owners, requiredSignatures, await counter.getAddress());
  });

  describe("部署", function () {
    it("应该正确设置初始签名者", async function () {
      expect(await multiSig.isOwner(owner1.address)).to.be.true;
      expect(await multiSig.isOwner(owner2.address)).to.be.true;
      expect(await multiSig.isOwner(owner3.address)).to.be.true;
      expect(await multiSig.isOwner(nonOwner.address)).to.be.false;
    });

    it("应该正确设置需要的签名数量", async function () {
      expect(await multiSig.requiredSignatures()).to.equal(2);
    });

    it("应该正确设置Counter合约地址", async function () {
      expect(await multiSig.counterContract()).to.equal(await counter.getAddress());
    });
  });

  describe("提案管理", function () {
    it("签名者应该能够创建提案", async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600; // 1小时

      await expect(multiSig.connect(owner1).createProposal(data, description, duration))
        .to.emit(multiSig, "ProposalCreated")
        .withArgs(0, owner1.address, data, description);

      expect(await multiSig.proposalCount()).to.equal(1);
    });

    it("非签名者不能创建提案", async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600;

      await expect(
        multiSig.connect(nonOwner).createProposal(data, description, duration)
      ).to.be.revertedWith("MultiSigCounter: caller is not an owner");
    });
  });

  describe("投票", function () {
    let proposalId: number;

    beforeEach(async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600;

      const tx = await multiSig.connect(owner1).createProposal(data, description, duration);
      const receipt = await tx.wait();
      const event = receipt?.logs.find((log: any) => 
        multiSig.interface.parseLog(log as any)?.name === "ProposalCreated"
      );
      proposalId = multiSig.interface.parseLog(event as any)?.args[0];
    });

    it("签名者应该能够投票", async function () {
      await expect(multiSig.connect(owner1).vote(proposalId, true))
        .to.emit(multiSig, "VoteCast")
        .withArgs(proposalId, owner1.address, true);

      expect(await multiSig.hasVoted(proposalId, owner1.address)).to.be.true;
      expect(await multiSig.getVote(proposalId, owner1.address)).to.be.true;
    });

    it("签名者不能重复投票", async function () {
      await multiSig.connect(owner1).vote(proposalId, true);

      await expect(
        multiSig.connect(owner1).vote(proposalId, false)
      ).to.be.revertedWith("MultiSigCounter: already voted");
    });

    it("非签名者不能投票", async function () {
      await expect(
        multiSig.connect(nonOwner).vote(proposalId, true)
      ).to.be.revertedWith("MultiSigCounter: caller is not an owner");
    });
  });

  describe("提案执行", function () {
    let proposalId: number;

    beforeEach(async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600;

      const tx = await multiSig.connect(owner1).createProposal(data, description, duration);
      const receipt = await tx.wait();
      const event = receipt?.logs.find((log: any) => 
        multiSig.interface.parseLog(log as any)?.name === "ProposalCreated"
      );
      proposalId = multiSig.interface.parseLog(event as any)?.args[0];
    });

    it("应该能够执行获得足够投票的提案", async function () {
      // 投票
      await multiSig.connect(owner1).vote(proposalId, true);
      await multiSig.connect(owner2).vote(proposalId, true);

      // 执行提案
      await expect(multiSig.connect(owner3).executeProposal(proposalId))
        .to.emit(multiSig, "ProposalExecuted")
        .withArgs(proposalId);

      // 验证Counter合约的值已增加
      expect(await counter.x()).to.equal(1);
    });

    it("不能执行投票不足的提案", async function () {
      // 只有一个人投票
      await multiSig.connect(owner1).vote(proposalId, true);

      await expect(
        multiSig.connect(owner2).executeProposal(proposalId)
      ).to.be.revertedWith("MultiSigCounter: insufficient votes");
    });

    it("不能重复执行提案", async function () {
      // 投票并执行
      await multiSig.connect(owner1).vote(proposalId, true);
      await multiSig.connect(owner2).vote(proposalId, true);
      await multiSig.connect(owner3).executeProposal(proposalId);

      // 尝试再次执行
      await expect(
        multiSig.connect(owner1).executeProposal(proposalId)
      ).to.be.revertedWith("MultiSigCounter: proposal already executed");
    });
  });

  describe("Counter合约操作", function () {
    it("应该能够通过多签名合约调用inc()函数", async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600;

      const tx = await multiSig.connect(owner1).createProposal(data, description, duration);
      const receipt = await tx.wait();
      const event = receipt?.logs.find((log: any) => 
        multiSig.interface.parseLog(log as any)?.name === "ProposalCreated"
      );
      const proposalId = multiSig.interface.parseLog(event as any)?.args[0];

      // 投票
      await multiSig.connect(owner1).vote(proposalId, true);
      await multiSig.connect(owner2).vote(proposalId, true);

      // 执行
      await multiSig.connect(owner3).executeProposal(proposalId);

      expect(await counter.x()).to.equal(1);
    });

    it("应该能够通过多签名合约调用incBy()函数", async function () {
      const incrementValue = 5;
      const data = counter.interface.encodeFunctionData("incBy", [incrementValue]);
      const description = "增加计数器5";
      const duration = 3600;

      const tx = await multiSig.connect(owner1).createProposal(data, description, duration);
      const receipt = await tx.wait();
      const event = receipt?.logs.find((log: any) => 
        multiSig.interface.parseLog(log as any)?.name === "ProposalCreated"
      );
      const proposalId = multiSig.interface.parseLog(event as any)?.args[0];

      // 投票
      await multiSig.connect(owner1).vote(proposalId, true);
      await multiSig.connect(owner2).vote(proposalId, true);

      // 执行
      await multiSig.connect(owner3).executeProposal(proposalId);

      expect(await counter.x()).to.equal(incrementValue);
    });

    it("应该能够获取Counter合约的当前值", async function () {
      // 直接调用Counter合约增加值
      await counter.inc();
      await counter.incBy(3);

      // 通过多签名合约获取值
      expect(await multiSig.getCounterValue()).to.equal(4);
    });
  });

  describe("签名者管理", function () {
    it("应该能够添加新的签名者", async function () {
      await expect(multiSig.connect(owner1).addOwner(nonOwner.address))
        .to.emit(multiSig, "OwnerAdded")
        .withArgs(nonOwner.address);

      expect(await multiSig.isOwner(nonOwner.address)).to.be.true;
    });

    it("应该能够移除签名者", async function () {
      await expect(multiSig.connect(owner1).removeOwner(owner3.address))
        .to.emit(multiSig, "OwnerRemoved")
        .withArgs(owner3.address);

      expect(await multiSig.isOwner(owner3.address)).to.be.false;
    });

    it("应该能够更新需要的签名数量", async function () {
      await multiSig.connect(owner1).updateRequiredSignatures(3);
      expect(await multiSig.requiredSignatures()).to.equal(3);
    });
  });

  describe("提案查询", function () {
    it("应该能够获取提案详情", async function () {
      const data = counter.interface.encodeFunctionData("inc");
      const description = "增加计数器";
      const duration = 3600;

      const tx = await multiSig.connect(owner1).createProposal(data, description, duration);
      const receipt = await tx.wait();
      const event = receipt?.logs.find((log: any) => 
        multiSig.interface.parseLog(log as any)?.name === "ProposalCreated"
      );
      const proposalId = multiSig.interface.parseLog(event as any)?.args[0];

      const proposal = await multiSig.getProposal(proposalId);
      expect(proposal.proposer).to.equal(owner1.address);
      expect(proposal.description).to.equal(description);
      expect(proposal.executed).to.be.false;
      expect(proposal.cancelled).to.be.false;
    });
  });
}); 