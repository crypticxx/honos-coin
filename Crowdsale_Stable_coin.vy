# @dev Implementation of a Stable Coin, with an attached timed crowdsale based on the ERC20 standard
# @author Chris Scott
# https://github.com/superman-scottca/honos-coin

from vyper.interfaces import ERC20

implements: ERC20

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Payment:
    _buyer: indexed(address)
    _value: uint256

event Freeze:
    _account: indexed(address)
    _freeze: bool

name: public(String[10])
symbol: public(String[3])
totalSupply: public(uint256)
maxSupply: public(uint256)
decimals: public(uint256)

# NOTE: By declaring `balanceOf` as public, vyper automatically generates a 'balanceOf()' getter
#       method to allow access to account balances.
#       The _KeyType will become a required parameter for the getter and it will return _ValueType.
#       See: https://vyper.readthedocs.io/en/v0.1.0-beta.8/types.html?highlight=getter#mappings
balances: public(HashMap[address, uint256])
ethBalances: public(HashMap[address, uint256])
allowed: HashMap[address, HashMap[address, uint256]]
frozenBalances: public(HashMap[address, bool])
owner: public(address)
cap: public(uint256)

minFundingGoal: public(uint256)
maxFundingGoal: public(uint256)
amountRaised: public(uint256)
deadline: public(uint256)
price: public(uint256)
fundingGoalReached: public(bool)
crowdsaleClosed: public(bool)


@external
def __init__():
    _initialSupply: uint256 = 800000000
    _decimals: uint256 = 0
    self.totalSupply = _initialSupply * 10 ** _decimals
    self.name = 'Honos Coin'
    self.symbol = 'HON'
    self.decimals = _decimals
    self.owner = msg.sender
    self.balances[msg.sender] = self.totalSupply
    self.cap = 100000000
    self.maxSupply = 20000000000
    self.minFundingGoal = as_wei_value(1, "ether")
    self.maxFundingGoal = as_wei_value(20, "ether")
    self.amountRaised = 0
    self.deadline = block.timestamp + 3600 * 24  # 1 day (24 hours)
    self.price = as_wei_value(1, "ether") / 240000
    self.fundingGoalReached = False
    self.crowdsaleClosed = False

    log Transfer(ZERO_ADDRESS, msg.sender, self.totalSupply)

@external
@payable
def __default__():
    assert msg.sender != self.owner
    assert self.crowdsaleClosed == False, "Sorry, the ICO for Honos Oficium has closed!"
    assert self.amountRaised + msg.value < self.maxFundingGoal, "Sorry, max goal for ICO reached!"
    assert msg.value >= as_wei_value(0.1, "ether")
    tokenAmount: uint256 = as_wei_value(msg.value, "ether") / self.price
    assert self.balances[msg.sender] + tokenAmount <= self.cap, "Sorry, you've reached the Honos buyer's cap!"
    self.ethBalances[msg.sender] += msg.value
    self.amountRaised += msg.value
    self.balances[msg.sender] += tokenAmount
    self.balances[self.owner] -= tokenAmount
    log Payment(msg.sender, msg.value)

@view
@external
def getTotalSupply() -> uint256:
    """
    @dev Total number of tokens in existence.
    """
    return self.totalSupply

@external
def checkGoalReached():
    assert block.timestamp > self.deadline
    if self.amountRaised >= self.minFundingGoal:
        self.fundingGoalReached = True
        
    self.crowdsaleClosed = True

@external
def safeWithdrawal():
    assert self.crowdsaleClosed == True
    if self.fundingGoalReached == False:
        if msg.sender != self.owner:
            if self.ethBalances[msg.sender] > 0:
                send(msg.sender, self.ethBalances[msg.sender])
                self.ethBalances[msg.sender] = 0
                self.balances[self.owner] += self.balances[msg.sender]
                self.balances[msg.sender] = 0
                
    if self.fundingGoalReached == True:
        if msg.sender == self.owner:
            if self.balance > 0:
                send(msg.sender, self.balance)

@external
def freezeBalance(_target: address, _freeze: bool) -> bool:
    assert msg.sender == self.owner or msg.sender == self
    self.frozenBalances[_target] = _freeze
    log Freeze(_target, _freeze)
    return True

@external
def mintToken(_to: address, _value: uint256):
    """
    @dev Mint an amount of the token and assigns it to an account.
         This encapsulates the modification of balances such that the
         proper events are emitted.
    @param _to The account that will receive the created tokens.
    @param _value The amount that will be created.
    """
    assert self.crowdsaleClosed == True
    assert msg.sender == self.owner or msg.sender == self
    assert _to != ZERO_ADDRESS
    assert self.totalSupply + _value <= self.maxSupply
    self.totalSupply += _value
    self.balances[_to] += _value
    log Transfer(ZERO_ADDRESS, _to, _value)

@internal
def burn(_to: address, _value: uint256):
    """
    @dev Internal function that burns an amount of the token of a given
         account.
    @param _to The account whose tokens will be burned.
    @param _value The amount that will be burned.
    """
    assert _to != ZERO_ADDRESS
    assert self.balances[_to] >= _value
    self.totalSupply -= _value
    self.balances[_to] -= _value
    log Transfer(_to, ZERO_ADDRESS, _value)

@external
def burnToken(_value: uint256):
    """
    @dev Burn an amount of the token of msg.sender.
    @param _value The amount that will be burned.
    """
    assert self.crowdsaleClosed == True
    assert msg.sender == self.owner or msg.sender == self
    self.burn(msg.sender, _value)

@external
def burnTokenFrom(_to: address, _value: uint256):
    """
    @dev Burn an amount of the token from a given account.
    @param _to The account whose tokens will be burned.
    @param _value The amount that will be burned.
    """
    assert self.allowed[_to][msg.sender] >= _value
    self.allowed[_to][msg.sender] -= _value
    self.burn(_to, _value)    

@external
def balanceOf(_owner: address) -> uint256:
    tokentotal: uint256 = self.balances[_owner]
    return tokentotal

@external
def transfer(_to: address, _amount: uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _amount The amount to be transferred.
    """
    assert self.crowdsaleClosed == True
    assert self.balances[msg.sender] >= _amount
    assert self.frozenBalances[msg.sender] == False

    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    
    self.balances[msg.sender] -= _amount
    self.balances[_to] += _amount
    log Transfer(msg.sender, _to, _amount)

    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    """
     @dev Transfer tokens from one address to another.
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    assert self.crowdsaleClosed == True
    assert _value <= self.allowed[_from][msg.sender]
    assert _value <= self.balances[_from]
    assert self.frozenBalances[msg.sender] == False

    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balances[_from] -= _value
    self.allowed[_from][msg.sender] -= _value
    self.balances[_to] += _value
    log Transfer(_from, _to, _value)

    return True

@external
def approve(_spender: address, _amount: uint256) -> bool:
    """
    @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
         Beware that changing an allowance with this method brings the risk that someone may use both the old
         and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
         race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds.
    @param _value The amount of tokens to be spent.
    """
    assert self.crowdsaleClosed == True
    self.allowed[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)

    return True

@external
def allowance(_owner: address, _spender: address) -> uint256:
    """
    @dev Function to check the amount of tokens that an owner allowed to a spender.
    @param _owner The address which owns the funds.
    @param _spender The address which will spend the funds.
    @return An uint256 specifying the amount of tokens still available for the spender.
    """
    assert self.crowdsaleClosed == True
    return self.allowed[_owner][_spender]
