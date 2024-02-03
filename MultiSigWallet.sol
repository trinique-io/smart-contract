// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        uint func,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event ChangeRequiredConfirmations(uint requiredConfirmations);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public requiredConfirmations;

    // Define transaction structure
    // func: is number to identify function to call
    //   1xx: internal function
    //       101: addOwner
    //       102: 
    //   2xx: external function 
    struct Transaction{
        address to;
        uint value;
        uint func;
        bytes data;
        bool executed;
        uint confirmations;
    }
    mapping(uint => mapping(address=>bool)) public isConfirmed;
    Transaction[] public transactions;

    //****************************
    modifier onlyWallet() {
        require(msg.sender != address(this), "invalid owner");
        _;
    }

    modifier  onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exists");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed,"tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender],"tx already confirmed");
        _;
    }

    //*********************************
    constructor(address[] memory _owners, uint _requiredConfirmations){
        require(_owners.length >0,"owners required");
        require(
            _requiredConfirmations >0 &&
            _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        for(uint i=0; i<_owners.length; i++){
            address owner = _owners[i];
            require(owner != address(0),"Invalid owner");
            require(!isOwner[owner],"owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    fallback() external payable { 
        if(msg.value >0){
            emit Deposit(msg.sender, msg.value, address(this).balance);
        }
    }
    receive() external payable { 
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    //func: 101
    function addOwner(address _owner)
        public
        onlyOwner
    {
        require(!isOwner[_owner],"owner already exists");
        submitTransaction(_owner, 0, 101, bytes(""));
    }

    function _executeAddOwner(address _owner) internal {
        isOwner[_owner] = true;
        owners.push(_owner);
        emit OwnerAddition(_owner);
    }

    //func: 102
    function removeOwner(address _owner) 
        public
        onlyOwner
    {
        require(isOwner[_owner],"owner not exists");
        submitTransaction(_owner, 0, 102, bytes(""));
    }

    function _executeRemoveOwner(address _owner) internal {
        isOwner[_owner] = false;
        for (uint i=0; i<owners.length - 1; i++){
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
        if (requiredConfirmations > owners.length)
            _executeChangeRequiredConfirmations(owners.length);
        
        emit OwnerRemoval(_owner);
    }

    //func: 103
    function changeRequiredConfirmations(uint _requiredConfirmations) public onlyOwner{
        require(
            _requiredConfirmations >0 &&
            _requiredConfirmations <= owners.length,
            "Invalid number of required confirmations"
        );

        submitTransaction(msg.sender, _requiredConfirmations, 103, bytes(""));
    }

    function _executeChangeRequiredConfirmations(uint _requiredConfirmations) internal {
        requiredConfirmations = _requiredConfirmations;
        emit ChangeRequiredConfirmations(_requiredConfirmations);
    }


    function submitTransaction(
        address _to,
        uint _value,
        uint _func,
        bytes memory _data
    ) public onlyOwner{
        
        //require func >0
        require(_func >0,"invalid func");
        uint txIndex = transactions.length;
        transactions.push(
            Transaction({
                to:_to,
                value:_value,
                func: _func,
                data: _data,
                executed: false,
                confirmations:0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _func, _data);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.confirmations >= requiredConfirmations,
            "cannot execute tx"
        );
        transaction.executed = true;
        if(transaction.func >= 200){
            _executeExternalTransaction(_txIndex);
        }

        if(transaction.func == 101){
            _executeAddOwner(transaction.to);
        }
        if(transaction.func == 102){
            _executeRemoveOwner(transaction.to);
        }
        if(transaction.func == 103){
            _executeChangeRequiredConfirmations(transaction.value);
        }
        
    }

    function _executeExternalTransaction(uint _txIndex) internal{
        Transaction storage transaction = transactions[_txIndex];

        
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.confirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }
    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            uint func,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.func,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }
}
