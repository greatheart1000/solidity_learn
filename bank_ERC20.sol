// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyFirstToken is ERC20{
    constructor(string memory name_, string memory symbol_) ERC20(name_,symbol_) {
        _mint(msg.sender, 10000*10**18);
        //10000000000000000000000

    }

}



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Bank{
    mapping(address=>uint) public deposited;//存款

    //
    address public immutable  token; //合约地址

    constructor(address _token){
        token =_token;
    }
    //查询自己的余额
    function myBalance() public view returns(uint balance){
        balance = deposited[msg.sender]/(10**18);
    }

    //转账存款函数
    function deposit(uint amount) public {
        amount = amount*10**18;
        require(IERC20(token).transferFrom(msg.sender, address(this), amount),
        "dont success");

        deposited[msg.sender]+=amount;
    }

        //取款
    function withdraw(uint amount) external {
        amount = amount*10**18;
         require(amount<=deposited[msg.sender],"dont have enlogh token");
        SafeERC20.safeTransfer(IERC20(token),msg.sender,amount);
           deposited[msg.sender]-=amount;     
    }

      //转账 银行与银行之间的转账
    function bankTransfer(address to, uint amount) public {
        amount = amount*10**18;
        //转的金额不能超过在银行里的存款
        require(amount<=deposited[msg.sender],"dont have enlogh token");
        deposited[msg.sender]-=amount;
        deposited[to]+=amount;
    }
}
//0xa813Ac34745571A3feD248D5dE03d8101C011e4F
