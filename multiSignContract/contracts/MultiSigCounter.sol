// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Counter.sol";

/**
 * @title MultiSigCounter
 * @dev 专门用于管理Counter合约的多签名合约
 */
contract MultiSigCounter {
    // 事件定义
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, bytes data, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);

    // 状态变量
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public requiredSignatures;
    uint256 public proposalCount;
    
    // Counter合约地址
    Counter public counterContract;
    
    // 提案结构
    struct Proposal {
        address proposer;
        bytes data;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedFor;
        uint256 deadline;
    }
    
    mapping(uint256 => Proposal) public proposals;

    // 修饰符
    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultiSigCounter: caller is not an owner");
        _;
    }
    
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "MultiSigCounter: proposal does not exist");
        _;
    }
    
    modifier proposalNotExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "MultiSigCounter: proposal already executed");
        _;
    }
    
    modifier proposalNotCancelled(uint256 proposalId) {
        require(!proposals[proposalId].cancelled, "MultiSigCounter: proposal already cancelled");
        _;
    }
    
    modifier proposalNotExpired(uint256 proposalId) {
        require(block.timestamp < proposals[proposalId].deadline, "MultiSigCounter: proposal expired");
        _;
    }

    /**
     * @dev 构造函数
     * @param _owners 初始签名者地址数组
     * @param _requiredSignatures 需要的签名数量
     * @param _counterContract Counter合约地址
     */
    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures,
        address _counterContract
    ) {
        require(_owners.length > 0, "MultiSigCounter: owners array cannot be empty");
        require(_requiredSignatures > 0 && _requiredSignatures <= _owners.length, 
                "MultiSigCounter: invalid required signatures");
        require(_counterContract != address(0), "MultiSigCounter: invalid counter contract address");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "MultiSigCounter: invalid owner address");
            require(!isOwner[owner], "MultiSigCounter: duplicate owner");
            
            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }
        
        requiredSignatures = _requiredSignatures;
        counterContract = Counter(_counterContract);
    }

    /**
     * @dev 创建提案
     * @param data 要执行的函数调用数据
     * @param description 提案描述
     * @param duration 提案有效期（秒）
     */
    function createProposal(
        bytes calldata data,
        string calldata description,
        uint256 duration
    ) external onlyOwner returns (uint256) {
        require(data.length > 0, "MultiSigCounter: empty proposal data");
        require(duration > 0, "MultiSigCounter: invalid duration");
        
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.proposer = msg.sender;
        proposal.data = data;
        proposal.description = description;
        proposal.deadline = block.timestamp + duration;
        
        emit ProposalCreated(proposalId, msg.sender, data, description);
        
        return proposalId;
    }

    /**
     * @dev 投票
     * @param proposalId 提案ID
     * @param support 是否支持
     */
    function vote(uint256 proposalId, bool support) 
        external 
        onlyOwner 
        proposalExists(proposalId)
        proposalNotExecuted(proposalId)
        proposalNotCancelled(proposalId)
        proposalNotExpired(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "MultiSigCounter: already voted");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.votedFor[msg.sender] = support;
        
        if (support) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        
        emit VoteCast(proposalId, msg.sender, support);
    }

    /**
     * @dev 执行提案
     * @param proposalId 提案ID
     */
    function executeProposal(uint256 proposalId) 
        external 
        onlyOwner 
        proposalExists(proposalId)
        proposalNotExecuted(proposalId)
        proposalNotCancelled(proposalId)
        proposalNotExpired(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.yesVotes >= requiredSignatures, "MultiSigCounter: insufficient votes");
        
        proposal.executed = true;
        
        // 执行对Counter合约的调用
        (bool success, ) = address(counterContract).call(proposal.data);
        require(success, "MultiSigCounter: execution failed");
        
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev 取消提案
     * @param proposalId 提案ID
     */
    function cancelProposal(uint256 proposalId) 
        external 
        onlyOwner 
        proposalExists(proposalId)
        proposalNotExecuted(proposalId)
        proposalNotCancelled(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "MultiSigCounter: only proposer can cancel");
        
        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @dev 添加新的签名者
     * @param newOwner 新签名者地址
     */
    function addOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MultiSigCounter: invalid owner address");
        require(!isOwner[newOwner], "MultiSigCounter: owner already exists");
        
        isOwner[newOwner] = true;
        owners.push(newOwner);
        
        emit OwnerAdded(newOwner);
    }

    /**
     * @dev 移除签名者
     * @param ownerToRemove 要移除的签名者地址
     */
    function removeOwner(address ownerToRemove) external onlyOwner {
        require(isOwner[ownerToRemove], "MultiSigCounter: owner does not exist");
        require(owners.length > requiredSignatures, "MultiSigCounter: cannot remove owner");
        
        isOwner[ownerToRemove] = false;
        
        // 从owners数组中移除
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == ownerToRemove) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        
        emit OwnerRemoved(ownerToRemove);
    }

    /**
     * @dev 更新需要的签名数量
     * @param newRequiredSignatures 新的签名数量
     */
    function updateRequiredSignatures(uint256 newRequiredSignatures) external onlyOwner {
        require(newRequiredSignatures > 0 && newRequiredSignatures <= owners.length, 
                "MultiSigCounter: invalid required signatures");
        
        requiredSignatures = newRequiredSignatures;
    }

    /**
     * @dev 获取所有签名者
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev 获取提案详情
     * @param proposalId 提案ID
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (
            address proposer,
            bytes memory data,
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            bool executed,
            bool cancelled,
            uint256 deadline
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.data,
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.executed,
            proposal.cancelled,
            proposal.deadline
        );
    }

    /**
     * @dev 检查地址是否已对提案投票
     * @param proposalId 提案ID
     * @param voter 投票者地址
     */
    function hasVoted(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId)
        returns (bool)
    {
        return proposals[proposalId].hasVoted[voter];
    }

    /**
     * @dev 获取投票者的投票选择
     * @param proposalId 提案ID
     * @param voter 投票者地址
     */
    function getVote(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId)
        returns (bool)
    {
        require(proposals[proposalId].hasVoted[voter], "MultiSigCounter: voter has not voted");
        return proposals[proposalId].votedFor[voter];
    }

    /**
     * @dev 获取当前Counter合约的值
     */
    function getCounterValue() external view returns (uint256) {
        return counterContract.x();
    }
} 