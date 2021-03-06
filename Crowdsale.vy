# IndividuallyCappedCrowdsale
# Contributors: Binod Nirvan
# This file is released under Apache 2.0 license.
# @dev Crowdsale with a limit for total contributions.
# Ported from Open Zeppelin
# https://github.com/OpenZeppelin
# 
# See https://github.com/OpenZeppelin
# Open Zeppelin tests ported: Crowdsale.test.js


#@dev ERC20/223 Features referenced by this contract
interface TokenContract:
    def transfer(_to: address, _value: uint256) -> bool: payable
    def getTotalSupply() -> uint256: view

# Event for token purchase logging
# @param _purchaser who paid for the tokens
# @param _beneficiary who got the tokens
# @param _value weis paid for purchase
# @param _amount amount of tokens purchased

event TokenPurchase: 
    _purchaser: address
    _beneficiary: address
    _value: uint256
    _amount: uint256

# Timed Crowdsale
#openingTime: public(uint256)
#closingTime: public(uint256)

# The token being sold
token: public(address)

#Address where funds are collected
wallet: public(address)

# How many token units a buyer gets per wei.
# The rate is the conversion between wei and the smallest and indivisible token unit.
# So, if you are using a rate of 1 with a DetailedERC20 token with 3 decimals called TOK
# 1 wei will give you 1 unit, or 0.001 TOK.
rate: public(uint256)

#Amount of wei raised
weiRaised: public(uint256)

#@external
#def hasClosed() -> bool:
#    return block.timestamp > self.closingTime

@external
def __init__(_rate: uint256, _wallet: address, _token: address):
    """
    @dev Initializes this contract
    @param _rate Number of token units a buyer gets per wei
    @param _wallet Address where collected funds will be forwarded to
    @param _token Address of the token being sold
    """

    #assert _openingTime >= block.timestamp, "Opening time not valid"
    #assert _closingTime >= _openingTime, "Closing time invalid"
    assert _rate > 0, "Invalid value supplied for the parameter \"_rate\"."
    assert _wallet != ZERO_ADDRESS, "Invalid wallet address."
    assert _token != ZERO_ADDRESS, "Invalid token address."

    #self.openingTime = block.timestamp + _openingTime
    #self.closingTime = block.timestamp + _closingTime
    self.rate = _rate
    self.wallet = _wallet
    self.token = _token

@internal
def getTokenAmount(_weiAmount: uint256) -> uint256:
    return _weiAmount * self.rate


@internal
def processTransaction(_sender: address, _beneficiary: address, _weiAmount: uint256):
    #pre validate
    assert _beneficiary != ZERO_ADDRESS, "Invalid address."
    assert _weiAmount != 0, "Invalid amount received."
    #assert block.timestamp >= self.openingTime, "Sale has not opened"
    #assert block.timestamp <= self.closingTime, "Sale has closed"

    #calculate the number of tokens for the Ether contribution.
    tokens: uint256 = self.getTokenAmount(as_wei_value(_weiAmount, "ether"))
    
    self.weiRaised += _weiAmount

    #process purchase
    success: bool = TokenContract(self.token).transfer(_beneficiary, tokens)
    if not success:
       raise "Could not forward funds due to an unknown error."
    log TokenPurchase(_sender, _beneficiary, _weiAmount, tokens)

    #forward funds to the receiving wallet address.
    send(self.wallet, _weiAmount)

    #post validate

@external
@payable
def buyTokens(_beneficiary: address):
    self.processTransaction(msg.sender, _beneficiary, msg.value)

@external
@payable
def __default__():
    self.processTransaction(msg.sender, msg.sender, msg.value)

@external
def getTotalSupply() -> uint256:
    return TokenContract(self.token).getTotalSupply()
