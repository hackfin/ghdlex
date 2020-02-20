#!/usr/bin/env python

import sys
import time
import netpp
import pytest
import subprocess

import sys
sys.path.append("py")
import board
import ram
import bus


SLAVE = "./simboard"

@pytest.yield_fixture(autouse=True, scope='session')
def test_cleanup():
	global slave, dev, root
	slave = subprocess.Popen([SLAVE])
	time.sleep(0.5)
	dev = netpp.connect("TCP:localhost:2010")
	root = dev.sync()
	yield
	slave.terminate()

def test_board_ram():
	assert ram.run_test(root)

def test_board_bus():
	assert bus.run_test(root)

def test_board_fifo():
	assert board.run_test(root)


