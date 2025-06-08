下面分别给出图片中涉及到的 Solidity 知识点的示例代码，每个示例都包含详细注释说明：

─────────────────────────────  
【1. 映射类型 (Mapping Types)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

contract MappingExample {
    // 定义从地址到 uint256 的映射，表示每个地址对应的余额
    mapping(address => uint256) public balances;

    // 更新指定地址的余额
    function updateBalance(address _addr, uint256 _newBalance) public {
        balances[_addr] = _newBalance;
    }

    // 查询指定地址的余额
    function getBalance(address _addr) public view returns (uint256) {
        return balances[_addr];
    }
}
------------------------------------------------

说明：
• 声明了一个公共映射 balances，可以直接通过自动生成的 getter 查询各地址余额。  
• 提供了修改余额的函数 updateBalance，以及获取余额的函数 getBalance。

─────────────────────────────  
【2. 枚举与常量 (Enums and Constants)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

contract EnumConstantExample {
    // 枚举表示任务的状态
    enum TaskStatus { Pending, InProgress, Completed }
    
    // 定义常量，表示最大任务ID
    uint256 public constant MAX_TASK_ID = 100;

    // 状态变量，保存当前任务状态
    TaskStatus public currentStatus;

    // 更新任务状态
    function updateStatus(TaskStatus _status) public {
        currentStatus = _status;
    }

    // 查看常量值
    function getMaxTaskId() public pure returns (uint256) {
        return MAX_TASK_ID;
    }
}
------------------------------------------------

说明：
• 使用枚举 TaskStatus 定义了多个状态，便于管理状态逻辑；  
• 定义常量 MAX_TASK_ID，值在编译后不可改变，且节省 gas 开销。

─────────────────────────────  
【3. 接口与继承 (Interfaces and Inheritance)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

// 定义接口 IToken，声明了代币常用的三个函数
interface IToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// 合约 MyToken 继承接口 IToken，实现接口中定义的函数
contract MyToken is IToken {
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // 构造函数中设置初始供应量，并全部分配给部署者
    constructor(uint256 initialSupply) {
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
    }

    // 返回代币总供应量
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    // 返回账户余额
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    // 实现代币转账逻辑
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(_balances[msg.sender] >= amount, "余额不足");
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        return true;
    }
}
------------------------------------------------

说明：
• 接口 IToken 定义了代币的基本功能；  
• 合约 MyToken 通过继承，实现了接口规定的方法，从而保证合约满足 ERC20 部分标准。

─────────────────────────────  
【4. 多态与抽象 (Polymorphism and Abstraction)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

// 抽象合约 Animal 中声明抽象函数 makeSound
abstract contract Animal {
    // 抽象函数，没有函数体，子合约必须实现该函数
    function makeSound() public virtual pure returns (string memory);
}

// Dog 合约继承 Animal，实现具体的 makeSound
contract Dog is Animal {
    function makeSound() public override pure returns (string memory) {
        return "Woof!";
    }
}

// Cat 合约继承 Animal，实现具体的 makeSound
contract Cat is Animal {
    function makeSound() public override pure returns (string memory) {
        return "Meow!";
    }
}

// AnimalSounds 合约通过多态调用传入的 Animal 合约实例的方法
contract AnimalSounds {
    // 多态调用，传入的参数可以是任一 Animal 的子合约
    function getSound(Animal animal) public view returns (string memory) {
        return animal.makeSound();
    }
}
------------------------------------------------

说明：
• 抽象合约 Animal 定义了一个接口，要求所有子合约实现 makeSound();  
• Dog、Cat 合约分别实现不同的声音；  
• AnimalSounds 合约通过多态调用，实现统一接口操作不同实例的效果。

─────────────────────────────  
【5. 工厂合约 (Factory 合约)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

// 被工厂合约部署的简单合约，称为 Child 合约
contract Child {
    uint256 public value;
    address public owner;

    constructor(uint256 _value, address _owner) {
        value = _value;
        owner = _owner;
    }
}

// 工厂合约，用于批量创建 Child 合约实例
contract Factory {
    // 保存所有已经创建的合约地址
    address[] public children;

    // 部署 Child 合约，并保存其地址
    function createChild(uint256 _value) public {
        Child child = new Child(_value, msg.sender);
        children.push(address(child));
    }

    // 获取部署的 Child 数量
    function getChildrenCount() public view returns (uint256) {
        return children.length;
    }
}
------------------------------------------------

说明：
• 工厂合约 Factory 中，通过 new 关键字部署 Child 合约；  
• 每次部署完成后，将新合约地址存入数组 children，方便后续查询或交互。

─────────────────────────────  
【6. 类库 (Libraries)】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

// 定义一个数学库 MathLib，包含常用数学运算
library MathLib {
    // 求两个数的和
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    // 求两个数的乘积
    function multiply(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
}

// 使用库的合约
contract LibraryUsage {
    // 直接使用 MathLib 的函数，注意库函数为 internal，因此会插入到合约中
    function computeSum(uint256 a, uint256 b) public pure returns (uint256) {
        return MathLib.add(a, b);
    }

    function computeProduct(uint256 a, uint256 b) public pure returns (uint256) {
        return MathLib.multiply(a, b);
    }
}
------------------------------------------------

说明：
• MathLib 定义了一组常用的数学函数，通过 library 关键词声明；  
• 合约 LibraryUsage 直接调用库中定义的函数，达到代码复用和节省 gas 的目的。

─────────────────────────────  
总结

以上示例分别涵盖了映射类型、枚举与常量、接口与继承、多态与抽象、工厂合约以及类库等 Solidity 的基础知识点。每个示例均配有中文注释，便于理解各个概念的实现原理与具体用法。
