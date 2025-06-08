下面提供两个 Solidity 事件的例子，并附上详细说明。

─────────────────────────────  
【例子 1：简单的转账事件】

代码示例：

------------------------------------------------
pragma solidity ^0.8.0;

contract SimpleToken {
    // 记录每个账户的余额
    mapping(address => uint256) public balances;
    uint256 public totalSupply = 1000000;

    // 定义转账事件，from 和 to 为索引字段，便于日志筛选
    event Transfer(address indexed from, address indexed to, uint256 value);

    // 构造函数中将全部代币分配给部署合约的账户，并发出初始转账事件
    constructor() {
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    // 转账函数，检验余额足够后变更余额并发出转账事件
    function transfer(address _to, uint256 _value) public {
        require(balances[msg.sender] >= _value, "余额不足");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }
}
------------------------------------------------

【解释】

• 定义了一个 Transfer 事件，用来记录转账的起始地址、目标地址以及转账金额。  
• 使用 indexed 关键字可以把 from 和 to 设置为索引，方便在区块链日志中快速查找相关记录。  
• 在合约初始化和每次转账时，通过 emit 关键字发出该事件，记录操作信息。

─────────────────────────────  
【例子 2：拍卖合约中的投标事件】

代码示例：

------------------------------------------------
pragma solidity ^0.8.0;

contract Auction {
    // 定义结构体存储投标信息
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    // 当有新的出价时发出事件，auctionId 为索引字段，便于筛选
    event NewBid(uint256 indexed auctionId, address bidder, uint256 amount);
    // 拍卖结束时发出事件，记录拍卖编号、获胜者和中标价格
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);

    // 存储每个拍卖的所有出价
    mapping(uint256 => Bid[]) public bids;

    // 投标函数，msg.value 为出价金额
    function placeBid(uint256 _auctionId) public payable {
        require(msg.value > 0, "出价金额必须大于0");

        Bid memory newBid = Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        bids[_auctionId].push(newBid);
        emit NewBid(_auctionId, msg.sender, msg.value);
    }

    // 结束拍卖函数，选取出价最高的投标者，并发出拍卖结束事件
    function endAuction(uint256 _auctionId) public {
        require(bids[_auctionId].length > 0, "当前拍卖没有任何出价");

        Bid memory highestBid = bids[_auctionId][0];
        for (uint256 i = 1; i < bids[_auctionId].length; i++) {
            if (bids[_auctionId][i].amount > highestBid.amount) {
                highestBid = bids[_auctionId][i];
            }
        }

        emit AuctionEnded(_auctionId, highestBid.bidder, highestBid.amount);
    }
}
------------------------------------------------

【解释】

• 定义了两个事件：NewBid 用于记录每次新出价的信息，AuctionEnded 用于记录拍卖结束时获胜的信息。  
• 在投标函数 placeBid 中，通过 msg.value 表示出价金额，每次投标都将出价信息记录到 bids 映射，并通过 emit NewBid 发出事件。  
• 在结束拍卖函数 endAuction 中，遍历某个拍卖的所有投标，找到最高出价后，发出 AuctionEnded 事件，记录拍卖结果。

─────────────────────────────  
【总结】

• 使用 event 关键字来定义合约事件，事件能够帮你在交易日志中记录重要信息。  
• 通过 emit 关键字来触发事件，这样合约执行时就会在区块链上留下可供追踪的日志。  
• 索引参数（indexed）能提高对事件的查询效率，有助于快速过滤出感兴趣的事件。

以上两个例子展示了如何在 Solidity 合约中定义和使用事件，以便在合约状态发生改变时记录相关信息。
