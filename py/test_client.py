
import sys
import os
import time
import netpp
import pytest
import subprocess


NETPP = os.getenv("NETPP")

if not NETPP:
	NETPP = "/usr/share/netpp"

SLAVE = NETPP + "/devices/example/slave"

@pytest.yield_fixture(autouse=True, scope='session')
def test_cleanup():
	global client
	server = subprocess.Popen([SLAVE, "--port=2008"])
	time.sleep(0.5)
	yield
	server.terminate()

def test_client():
	client = subprocess.Popen(["./simnetpp"])
	ret = client.wait()
	assert ret == 0
