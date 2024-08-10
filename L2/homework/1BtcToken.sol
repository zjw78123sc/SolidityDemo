// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BtcToken {
    //1 创建合约并定义状态变量：
    // 1-1 定义代币名称、符号、总供应量等变量。
    string private _name;
    string private _symbol; //代币符号。
    uint256 private _totalSupply; //代币总供应量。
    //1-2 定义账户余额和授权额度的映射。
    mapping(address => uint256) private _balances; //账户余额映射。
    mapping(address => mapping(address => uint256)) private _allowances; //授权额度映射。
    address public owner; //合约所有者。

    event Transfer(address indexed from, address indexed to, uint256 value); //转账事件。
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    ); //授权事件。

    //2 实现构造函数和权限修饰符：
    //2-1 在构造函数中初始化代币名称、符号和合约所有者。
    constructor(string memory name, string memory symbol) {
        _name = name;
        _symbol = symbol;
        owner = msg.sender;
    }

    //2-2 使用onlyOwner修饰符限制某些函数只能由合约所有者调用。
    modifier isOwner() {
        require(msg.sender == owner, "only owner can do this");
        _;
    }

    //3 实现基本信息函数：
    // 实现返回代币名称、符号、小数点位数和总供应量的函数。

    function name() public view returns (string memory) {
        //返回代币名称。
        return _name;
    }

    function symbol() public view returns (string memory) {
        //返回代币符号。
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        //返回代币小数点位数（固定为18）。
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        //返回代币总供应量。
        return _totalSupply;
    }

    //4 实现账户查询和授权函数：
    // 4-1 实现查询账户余额和授权额度的函数。

    function balanceOf(address account)
        public
        view
        returns (
            uint256 //返回指定地址的代币余额。
        )
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        returns (
            uint256 //返回指定地址允许另一地址支配的代币数量。
        )
    {
        return _allowances[owner][spender];
    }

    // 4-2 实现设置授权额度的函数。

    function approve(
        address spender,
        uint256 amount //允许第三方账户支配自己一定数量的代币。
    ) public {
        _allowances[msg.sender][spender] += amount;
        emit Approval(msg.sender, spender, amount);
    }

    //5 实现转账函数：
    //5-1 实现从调用者地址向另一个地址转移代币的函数。
    function transfer(
        address to,
        uint256 amount //从调用者地址向另一个地址转移代币。
    ) public {
        require(_balances[msg.sender] >= amount, "balance not enough");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;

      emit  Transfer(msg.sender, to, amount);
    }

    //5-2 实现从一个地址向另一个地址转移代币的函数（需要事先授权）。
    function transferFrom(
        address from,
        address to,
        uint256 amount //从一个地址向另一个地址转移代币（需要事先授权）。
    ) public {
        uint256 allow = _allowances[from][msg.sender]; //检查调用者是否有足够的授权额度
        require(_balances[msg.sender] >= amount, "balance not enough");
        require(allow >= amount, "allowance not enough");

        _balances[from] += amount;
        _balances[to] -= amount;
        _allowances[from][msg.sender] -= amount;

       emit Transfer(from, to, amount);
    }


    //6 实现代币增发和销毁函数：
//6-1 实现合约所有者可以增加代币供应量的函数。

function mint(address account, uint256 amount) public isOwner//增加指定地址的代币数量。
{
    _balances[account] += amount;
    _totalSupply += amount;
    emit Transfer(address(0), account, amount);
}

//6-2 实现合约所有者可以销毁代币的函数。

function burn(address account, uint256 amount) public isOwner{//销毁指定地址的代币数量。
    require(_balances[account] >= amount,"balance not enough");
     _balances[account] -= amount;
    _totalSupply -= amount;
    emit Transfer(account, address(0), amount);
}

}