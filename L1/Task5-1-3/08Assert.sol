
// Here is another example
contract Account {
 

    event Log(uint256);

    

    function splitEther(address payable addr1, address payable addr2)
        public
        payable
    {
        require(msg.value % 2 == 0, "Even value required."); // 检查传入的ether是不是偶数_
        uint256 balanceBeforeTransfer = address(this).balance;
        addr1.transfer(msg.value / 2);
        addr2.transfer(msg.value / 2);
        emit Log(address(this).balance);
        emit Log(balanceBeforeTransfer); 
        assert(address(this).balance == balanceBeforeTransfer); // 检查分账前后，本合约的balance不受影响_
    }
}