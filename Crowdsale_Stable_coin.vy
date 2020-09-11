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
balances: HashMap[address, uint256]
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
    _initialSupply: uint256 = 6000
    _decimals: uint256 = 6
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
    self.price = as_wei_value(1, "ether") / 200000
    self.fundingGoalReached = False
    self.crowdsaleClosed = False

    log Transfer(ZERO_ADDRESS, msg.sender, self.totalSupply)

@external
@payable
def __default__():
    assert msg.sender != self.owner
    assert self.crowdsaleClosed == False, "Sorry, the ICO for Honos Oficium has closed!"
    assert self.amountRaised + msg.value < self.maxFundingGoal, "Sorry, max goal for ICO reached!"
    assert msg.value >= as_wei_value(0.2, "ether")
    tokenAmount: uint256 = msg.value / self.price
    assert self.balances[msg.sender] + tokenAmount <= self.cap, "Sorry, you've reached the Honos buyer's cap!"
    self.ethBalances[msg.sender] += msg.value
    self.amountRaised += msg.value
    self.balances[msg.sender] += tokenAmount
    self.balances[self.owner] -= tokenAmount
    log Payment(msg.sender, msg.value)

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
    assert msg.sender == self.owner
    self.frozenBalances[_target] = _freeze
    log Freeze(_target, _freeze)
    return True

@external
def mintToken(_mintedAmount: uint256) -> bool:
    assert msg.sender == self.owner
    assert self.totalSupply + _mintedAmount <= self.maxSupply
    self.totalSupply += _mintedAmount
    self.balances[msg.sender] += _mintedAmount
    log Transfer(ZERO_ADDRESS, msg.sender, _mintedAmount)

    return True

@external
def burn(_burntAmount: uint256) -> bool:
    assert msg.sender == self.owner
    assert self.balances[msg.sender] >= _burntAmount
    self.totalSupply -= _burntAmount
    self.balances[msg.sender] -= _burntAmount
    log Transfer(msg.sender, ZERO_ADDRESS, _burntAmount)

    return True

@external
def balanceOf(_owner: address) -> uint256:
    return self.balances[_owner]

@external
def transfer(_to: address, _amount: uint256) -> bool:
    assert self.balances[msg.sender] >= _amount
    assert self.frozenBalances[msg.sender] == False
    self.balances[msg.sender] -= _amount
    self.balances[_to] += _amount
    log Transfer(msg.sender, _to, _amount)

    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    assert _value <= self.allowed[_from][msg.sender]
    assert _value <= self.balances[_from]
    assert self.frozenBalances[msg.sender] == False

    self.balances[_from] -= _value
    self.allowed[_from][msg.sender] -= _value
    self.balances[_to] += _value
    log Transfer(_from, _to, _value)

    return True

@external
def approve(_spender: address, _amount: uint256) -> bool:
    self.allowed[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)

    return True

@external
def allowance(_owner: address, _spender: address) -> uint256:
    return self.allowed[_owner][_spender]

@external
def getTotalSupply() -> uint256:
    return self.totalSupply
