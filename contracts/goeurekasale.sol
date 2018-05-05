pragma solididy ^0.4.23;


import "./openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./xClaimable.sol";
import "./Salvageable.sol";



contract GOeurekaSale is xClaimable,Salvageable,Pausable {

  using SafeMath for uint256;

  // The token being sold
  GOeureka public token;
  uint256 public decimals;
  uint256 public oneCoin;

  // start and end block where investments are allowed 
  uint256 public presaleStart;
  uint256 public privatePresaleEnd;
  uint256 public presaleEnd;

  uint256 public week1Start;
  uint256 public week1End;
  uint256 public week2End;
  uint256 public week3End;

  // Caps are in ETHER not tokens - need to back calclate to get token cap
  uint256 public presaleCap;
  uint256 public week1Cap;
  uint256 public week2Cap;
  uint256 public week3Cap;
  uint256[] public cap;

  // address where funds are collected
  address public multiSig;

  uint256 public minContribution = 0.0001 ether;  // minimum contributio to participate in tokensale
  uint256 public maxContribution = 200000 ether;  // default limit to tokens that the users can buy

  // amount of raised money in wei
  uint256 public weiRaised;

  // amount of raised tokens
  uint256 public tokensRaised;

  // maximum amount of tokens being created
  uint256 public maxTokens;

  // maximum amount of tokens for sale
  uint256 public tokensForSale;  

  // number of participants
  mapping(address => uint256) public contributions;
  uint256 public numberOfContributors = 0;

  //  for whitelist
  address public cs;
  //  for whitelist AND placement
  address public Admin;

  //  for rate
  uint public basicRate;
 

  // switch on/off the authorisation , default: false- off 
  bool    public freeForAll = false;

  mapping (address => bool) public authorised; // just to annoy the heck out of americans

  // EVENTS

  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event SaleClosed();

  // MODIFIERS

  modifier onlyCSorAdmin() {
    require((msg.sender == Admin) || (msg.sender==cs));
    _;
  }
  modifier onlyAdmin() {
    require(msg.sender == Admin);
    _;
  }

  modifier privateSaleValid(address beneficiary, uint256 amount) {
    require(now <= privatePresaleEnd);
    require(weiRaised < presaleCap);
    _;
  }

  // CONSTRUCTOR

  constructor() public {
    presaleStart = 1516896000;
    privatePresaleEnd = presaleStart + 2 weeks; 
    presaleEnd = privatePresaleEnd + 2 weeks;
    
    week1Start = presaleEnd;
    week1End = week1Start + 1 weeks;
    week2End = week1Start + 2 weeks; 
    week3End = week1Start + 3 weeks;

    basicRate = 3000;  
    calculateRates();

    // 1522468800 converts to Saturday March 31, 2018 12:00:00 (pm) in time zone Asia/Singapore (+08)
    multiSig = 0x90420B8aef42F856a0AFB4FFBfaA57405FB190f3;
    token = new GOeureka();
    decimals = token.decimals();
    oneCoin = 10 ** decimals;
    maxTokens = 500 * (10**6) * oneCoin;
    tokensForSale = 300 * (10**6) * oneCoin;
    
  }

  function setWallet(address _newWallet) public onlyOwner {
    multiSig = _newWallet;
  } 


  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    if (now > week3End)
      return true;
    if (tokensRaised >= tokensForSale)
      return true; // if we reach the tokensForSale
    return false;
 }

  /**
  * @dev throws if person sending is not authorised or sends nothing or we are out of time
  */
  modifier onlyAuthorised(address beneficiary) {
    require (authorised[beneficiary] || freeForAll);
    require (now >= presaleStart);
    require (!(hasEnded()));
    require (multiSig != 0x0);
    require (msg.value > 1 finney);
    require(tokensForSale > tokensRaised); // check we are not over the number of tokensForSale
    _;
  }

  /**
  * @dev authorise an account to participate
  */
  function authoriseAccount(address whom) onlyCSorAdmin public {
    authorised[whom] = true;
  }

  /**
  * @dev authorise a lot of accounts in one go
  */
  function authoriseManyAccounts(address[] many) onlyCSorAdmin public {
    for (uint256 i = 0; i < many.length; i++) {
      authorised[many[i]] = true;
    }
  }

  /**
  * @dev ban an account from participation (default)
  */
  function blockAccount(address whom) onlyCSorAdmin public {
    authorised[whom] = false;
  }

  /**
  * @dev set a new CS representative
  */
  function setCS(address newCS) onlyOwner public {
    cs = newCS;
  }

  /**
  * @dev set a new Admin representative
  */
  function setAdmin(address newAdmin) onlyOwner public {
          Admin = newAdmin;
  }

  function setNewRate(uint newRate) onlyAdmin public {
    require(tokensRaised == 0);
    require(0 < newRate && newRate < 5000);
    basicRate = newRate;
    calculateRates();
  }

  function calculateRates() internal {
    presaleCap = uint(150000000).div(basicRate);
    week1Cap = presaleCap.add(uint(100000000).div(basicRate));
    week2Cap = week1Cap.add(uint(100000000).div(basicRate));
    week3Cap = week2Cap.add(uint(200000000).div(basicRate));
    cap = [presaleCap,week1Cap,week2Cap,week3Cap];
  }

  
  uint phase = 0;
  function getTokens(uint256 amountInWei) 
    internal
    returns (uint256)
  {
    if (now < week1Start) {
        require(weiRaised < presaleCap);
        require(amountInWei >= 1 ether);
        return amountInWei.mul(basicRate).mul(115).div(100);
    }
    if ((now <= week1End) && (weiRaised < week1Cap)) {
          require(msg.value >= minContribution);
          phase = 1;
          return amountInWei.mul(basicRate).mul(110).div(100);
    }
    if ((now <= week2End) && (weiRaised < week2Cap)) {
          require(msg.value >= minContribution);
          phase = 2;
          return amountInWei.mul(basicRate).mul(105).div(100);
    }
    if ((now <= week3End) && (weiRaised < week3Cap)) { // no min cap to allow hitting target
          phase = 3;
          return amountInWei.mul(basicRate);
    }
    revert();
  }

  
  // low level token purchase function
  function buyTokens(address beneficiary, uint256 value)
    internal
    onlyAuthorised(beneficiary) 
  {

    uint256 thisPhase = value;
    uint256 nextPhase = 0;
    uint256 refund = 0;

    if (weiRaised.add(value) > cap[phase]) {
       thisPhase = cap[phase].sub(weiRaised);
       nextPhase = value.sub(thisPhase);
    }
    uint256 newTokens = getTokens(thisPhase);
    weiRaised = weiRaised.add(thisPhase);
    if (nextPhase > 0) {
        if (weiRaised.add(nextPhase) <= week3Cap) {
        	 weiRaised = weiRaised.add(nextPhase);
           newTokens = newTokens.add(getTokens(nextPhase));
        } else {
           refund = nextPhase;
           nextPhase = 0;
        }
    }
    if (contributions[beneficiary] == 0) {
      numberOfContributors++;
    }
    contributions[beneficiary] = contributions[beneficiary].add(thisPhase).add(nextPhase);
    tokensRaised = tokensRaised.add(newTokens);
    token.mint(beneficiary,newTokens);
    multiSig.transfer(thisPhase.add(nextPhase));
    if (refund > 0) {
    	beneficiary.transfer(refund);
    }
  }

  // placeTokens must be called before the sale starts
  // - beneficiary : teh address to receive the tokens
  // - 
  function placeTokens(address beneficiary, uint256 value) 
    public
	  privateSaleValid(beneficiary,value)
	  onlyOwner
  {
    uint256 refund = 0;
    uint256 contribution = value;
    if (weiRaised.add(value) > presaleCap) {
      contribution = presaleCap.sub(weiRaised);
      refund = value.sub(contribution);
    }
    uint tokens = getTokens(contribution);
    weiRaised = weiRaised.add(contribution);
    tokensRaised = tokensRaised.add(tokens);
    token.mint(beneficiary,tokens);
  }


  // transfer ownership of the token to the owner of the presale contract
  function finishSale() public onlyOwner {
    require(hasEnded());
    // assign the rest of the 500 M tokens to the reserve
    uint unassigned;
    if (maxTokens > tokensRaised) {
      unassigned = maxTokens.sub(tokensRaised);
      token.mint(multiSig,unassigned);
    }
    token.finishMinting();
    token.transferOwnership(owner);
    SaleClosed();
  }

  // fallback function can be used to buy tokens
  function () public payable whenNotPaused {
    buyTokens(msg.sender, msg.value);
  }

}



