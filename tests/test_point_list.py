import pytest
from brownie import accounts, reverts
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def test_point_list(point_list):
    points = 10
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert "PointsUpdated" in tx.events
    assert point_list.hasPoints(accounts[3], points) == True

    assert point_list.isInList(accounts[3]) == True
    assert point_list.points(accounts[3]) == points


def test_point_list_remove(point_list):
    points = 10
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert point_list.points(accounts[3]) == points
    points = 10
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert "PointsUpdated" not in tx.events
    with reverts():
        tx = point_list.setPoints([], [], {"from": accounts[0]})
    with reverts():
        tx = point_list.setPoints([], [points], {"from": accounts[0]})
    with reverts():
        tx = point_list.setPoints([accounts[3]], [], {"from": accounts[0]})
    with reverts():
        tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[1]})

    points = 5
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert point_list.points(accounts[3]) == points
    assert point_list.totalPoints() == points
    points = 0
    tx = point_list.setPoints([accounts[3]], [points], {"from": accounts[0]})
    assert "PointsUpdated" in tx.events
    assert point_list.totalPoints() == 0
    assert point_list.points(accounts[3]) == 0
    assert point_list.isInList(accounts[3]) == False
    assert point_list.hasPoints(accounts[3], 1) == False


# Test cannot initPointList twice
# Test not allowed operator, cannot change
# Test setPoints to an empty account array, and empty amount, and both empty
# Test an array with multiple users, some duplicates accounts different amounts
# Test changing amount, higher, lower, higher and check still correct, and totalPoints correct