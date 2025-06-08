下面分别给出四个主题的示例代码及详细说明，每个示例均用中文注释说明核心原理和用法。

─────────────────────────────  
【1. 委托调用 (Delegatecall) 示例】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

// 定义一个库合约，提供加法运算
library MathLib {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
}

// 委托调用示例合约：通过 delegatecall 调用库中的函数
contract DelegatecallExample {
    // 存放库合约地址（实际上存放的是库合约的代码逻辑）
    address public libraryAddress;
    
    // 存储运算结果
    uint256 public result;

    // 构造函数中传入库合约地址
    constructor(address _libraryAddress) {
        libraryAddress = _libraryAddress;
    }

    // 调用库中 add 函数进行计算，值将存在本合约的上下文中
    function calculate(uint256 a, uint256 b) public {
        // 使用 abi.encodeWithSignature 对要调用的函数及参数进行编码
        bytes memory data = abi.encodeWithSignature("add(uint256,uint256)", a, b);
        
        // 执行 delegatecall，此时 MathLib 中 add 方法以本合约的上下文执行，结果存储在本合约的 storage 中
        (bool success, bytes memory returnData) = libraryAddress.delegatecall(data);
        require(success, "Delegatecall 失败");

        // 解码返回数据，赋值给 result 变量
        result = abi.decode(returnData, (uint256));
    }
}
------------------------------------------------

说明：  
此示例中，主合约 DelegatecallExample 通过 delegatecall 调用 MathLib 库中的 add 函数。由于 delegatecall 在本合同上下文中运行，所以库合约中的代码修改的是主合约的存储数据。

─────────────────────────────  
【2. 签名验证 (Signature Verification) 示例】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

contract SignatureVerification {
    // 对传入字符串做哈希后返回
    function getMessageHash(string memory _message) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_message));
    }
    
    // 验证签名，参数包括消息哈希、签名及预期签名者地址
    function verifySignature(
        bytes32 messageHash,
        bytes memory signature,
        address expectedSigner
    ) public pure returns (bool) {
        // 构建前缀（符合以太坊标准签名）
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        // 计算带前缀的哈希
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, messageHash));
        // 使用 ecrecover 恢复签名者地址
        address recoveredSigner = recover(prefixedHash, signature);
        // 验证恢复的地址与预期地址是否一致
        return recoveredSigner == expectedSigner;
    }
    
    // 内部函数：通过拆分签名数据并调用 ecrecover 恢复地址
    function recover(bytes32 _hash, bytes memory _signature) internal pure returns (address) {
        require(_signature.length == 65, "无效的签名长度");
        bytes32 r;
        bytes32 s;
        uint8 v;
        // 利用 assembly 提取 r, s, v 参数
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        // 兼容 v 值调整：27 或 28
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "无效的 v 值");
        return ecrecover(_hash, v, r, s);
    }
}
------------------------------------------------

说明：  
该示例展示了如何利用 ecrecover 来验证给定签名是否由预期的地址生成。首先通过 getMessageHash 函数计算消息的哈希，再在 verifySignature 函数中对消息进行标准前缀处理后恢复签名者地址，从而完成签名验证。

─────────────────────────────  
【3. Multi Call 示例】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

contract MultiCall {
    // 允许在同一事务中一次性调用多个函数调用
    function multiCall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // 利用 delegatecall 调用本合约内的函数（当然也可以改为 call 调用外部合约）
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "调用失败");
            results[i] = result;
        }
        return results;
    }

    // 示例函数 1：返回一个常量值
    function getConstant() public pure returns (uint256) {
        return 42;
    }
    
    // 示例函数 2：返回调用者地址
    function getCaller() public view returns (address) {
        return msg.sender;
    }
}
------------------------------------------------

说明：  
此示例中，multiCall 函数接受一个 bytes 数组，每个 bytes 元素代表一个函数调用的编码数据。合约遍历该数组，并用 delegatecall 按序调用，从而一次性执行多个操作，并收集返回数据。

─────────────────────────────  
【4. 多维数组 (Multidimensional Arrays) 示例】

代码示例：
------------------------------------------------
pragma solidity ^0.8.0;

contract MultiDimensionalArray {
    // 声明一个固定长度二维数组：3 行 2 列
    uint256[2][3] public fixedArray;
    
    // 声明一个动态二维数组
    uint256[][] public dynamicArray;
    
    // 初始化固定二维数组的示例函数
    function initFixedArray() public {
        // 手动赋值
        fixedArray[0] = [uint256(1), 2];
        fixedArray[1] = [uint256(3), 4];
        fixedArray[2] = [uint256(5), 6];
    }
    
    // 添加新的一维数组到动态数组中
    function addDynamicRow(uint256[] memory newRow) public {
        dynamicArray.push(newRow);
    }
    
    // 获取动态数组中指定行长度的函数
    function getDynamicRowLength(uint256 rowIndex) public view returns (uint256) {
        require(rowIndex < dynamicArray.length, "索引越界");
        return dynamicArray[rowIndex].length;
    }
}
------------------------------------------------

说明：  
此示例展示了固定尺寸和动态尺寸的二维数组。在固定数组中，每行列数确定；而动态数组可以自由 push 新的数组，并在需要时查询各行的长度。

─────────────────────────────  
【总结】

以上示例展示了 Solidity 中的四个不同主题用法：  
1. 利用 delegatecall 调用外部库函数；  
2. 利用 ecrecover 实现签名验证；  
3. 通过 multiCall 函数实现一次性调用多个函数；  
4. 定义和操作固定尺寸以及动态的多维数组。  

可以根据具体业务需求，进一步扩展和修改这些示例代码。
