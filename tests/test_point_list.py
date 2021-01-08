import pytest
from brownie import accounts
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def test_point_list(point_list):
    points = 10
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert "PointsUpdated" in tx.events
    assert point_list.isInPointList(accounts[3]) == True
    assert point_list.points(accounts[3]) == points

# Test cannot initPointList twice
# Test not allowed operator, cannot change
# Test setPoints to an empty account array, and empty amount, and both empty
# Test an array with multiple users, some duplicates accounts different amounts
# Test changing amount, higher, lower, higher and check still correct, and totalPoints correct