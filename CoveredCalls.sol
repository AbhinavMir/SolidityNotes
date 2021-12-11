pragma solidity ^0.7.6;

// By Crypto Markets Pool

//This is a simple ownership contract
contract Owned {
    constructor() { owner = msg.sender; }
    address payable owner;

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function.");
        _; /* jumps to code of function using this modifier */
    }
}

//the contract Token inherits the Owned contract
//This contract is very basic
//Use ERC-20 standard for creating a token
contract Token is Owned {
    mapping(address => uint) public balanceOf;
    //use the constructor of the base class
    constructor() Owned() {}
    //This is an issuance function.  Add to the balance you are passing into the function
    //OnlyOwner modifier is used to make sure the person calling this function is the owner of the contract
    function issue(address recipient, uint amount) public onlyOwner {
        balanceOf[recipient] += amount;
    }
    //Make sure you have enough balance to send
    //Decrement and increment the balance of each address
    function transfer(address recipient, uint amount) public {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
    }
}

//This is a sample fully collateralized call Option.  Covered Call
//Alice creates a contract and transfers 100 tokens to contract
//At any time until expiration bob can send 1 eth to the contract
//After expiration Alice can terminate the contract and reclaim her tokens
//The contract below expands on the contract above.  
//It is the same but considers Bob paying Alice the premium for the contract and then the contract is live
contract CallOptionSeller is Owned {
    //input bobs address
    address buyer;
    //Alice funds with 100 tokens
    uint quantity; /* 100 */
    //Bob can send in 1 ether which is the strikePrice.  Lets say it is estimated at $1,000
    uint strikePrice; /* 1000000000000000000 (1 ether) */
    //Bob has to pay this much for the contract.
    uint purchasePrice; /* 100000000000000000 (0.1 ether) */
    //Expiration is the new years block number
    uint expiry; /* 9577836111 (New Years) */
    //indicates if the contract premium was paid
    bool wasPurchased; /* refactor as expression (buyer == 0x0)? */
    Token token;

    constructor(uint _quantity, uint _strikePrice, uint _purchasePrice, uint _expiry, address _tokenAddress) Owned() {
        quantity = _quantity;
        strikePrice = _strikePrice;
        purchasePrice = _purchasePrice;
        expiry = _expiry;
        token = Token(_tokenAddress);
        wasPurchased = false; /* added for clarity, false is default value */
    }
    //this function allows Bob to purchase the contract and pay the premium
    function purchase() public payable {
        //was the contract already purchased
        require(!wasPurchased, "Option already purchased");
        //did Bob send in the correct amount to purchase the contract
        require(msg.value == purchasePrice, "Incorrect purchase price");
        //ss this Bob trying to make the purchase
        buyer = msg.sender;
        //set the wasPurchased bool to true
        wasPurchased = true;
    }

    //first check that this contract is valid, then transfer out and clean up
    //Bob sends ether into contract to execute a trade
    //He is only going to do this if the value of the tokens is worth more then the ether
    function execute() public payable {
        //make sure the contract was purchased
        require(wasPurchased, "Option unpurchased");
        //make sure the person trying to execute the contract is Bob
        require(msg.sender == buyer, "Unauthorized");   
        //Contract was funded by Alice
        require(token.balanceOf(address(this)) == quantity, "Funding error");
        //make sure the amount of eth being payed/sent is == to the strikePrice of 1 ether
        require(msg.value == strikePrice, "Payment error");
        //make sure the contract has not expired
        require(block.timestamp < expiry, "Expired");
        
        //If the above is true send tokens to the buyer
        token.transfer(buyer, quantity);
        //Clean up the contract and remove from the blockchain
        selfdestruct(owner);
    }
    
    //refund and send funds back to the owner.  Contract is not worth executing
    //Can not refund if it was purchased and the contract has expired
    function refund() public {
        if(wasPurchased) {
            require(block.timestamp > expiry, "Not expired");
        }
        token.transfer(owner, quantity);
        selfdestruct(owner);
    }
    
     //contract can accept deposits
    receive()
        external
        payable {
    }
}
