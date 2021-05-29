#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""HDL tests"""

import pytest
from sim import Simulator, path, get_test_names


def run_sim(cwd, defines, simtool, gui):
    sim = Simulator(name=simtool, gui=gui, cwd=cwd)
    tb_dir = path("tb")
    rtl_dir = path("../src")
    sim.incdirs += [tb_dir, rtl_dir, cwd]
    sim.sources += tb_dir.glob('*.sv')
    sim.sources += rtl_dir.glob('*.sv')
    sim.defines += defines
    sim.top = "tb"
    sim.setup()
    sim.run()
    return sim.is_passed


@pytest.fixture
def simtool(pytestconfig):
    return pytestconfig.getoption("sim")


@pytest.fixture
def gui(pytestconfig):
    return pytestconfig.getoption("gui")


def ignore_some_combinations(testcase, clock_domains, ft_clock, fifo_clock, data_width):
    """Special function to ignore some fixtures combinations"""
    if (('SINGLE' in clock_domains) and ('48' not in fifo_clock)):
        # no need to use multiple fifo clock values in the single domain mode
        return True


@pytest.mark.uncollect_if(func=ignore_some_combinations)
@pytest.mark.parametrize('testcase', ["TESTCASE=test_rx_simple", "TESTCASE=test_rx_flow_control", "TESTCASE=test_rx_thresholds",
                                      "TESTCASE=test_tx_simple", "TESTCASE=test_tx_flow_control", "TESTCASE=test_tx_thresholds"])
@pytest.mark.parametrize('ft_clock', ["FT_CLK_FREQ=60e6", "FT_CLK_FREQ=66e6", "FT_CLK_FREQ=100e6"])
@pytest.mark.parametrize('fifo_clock', ["FIFO_CLK_FREQ=48e6", "FIFO_CLK_FREQ=72e6",
                                        "FIFO_CLK_FREQ=96e6","FIFO_CLK_FREQ=120e6"])
@pytest.mark.parametrize('data_width', ["DATA_W=8", "DATA_W=16", "DATA_W=32"])
@pytest.mark.parametrize('clock_domains', ["MULTIPLE_CLK_DOMAINS",  "SINGLE_CLK_DOMAIN"])
def test(tmp_path, testcase, clock_domains, ft_clock, fifo_clock, data_width, simtool, gui):
    defines = [testcase, clock_domains, ft_clock, fifo_clock, data_width]
    if "thresholds" in testcase:
        defines += ["TX_FIFO_SIZE=64", "TX_START_THRESHOLD=20", "TX_BURST_SIZE=16",
                    "RX_FIFO_SIZE=64", "RX_START_THRESHOLD=16", "RX_BURST_SIZE=20"]
    res = run_sim(tmp_path, defines, simtool, gui)
    if not gui:
        assert res

def test_debug(tmp_path, simtool, gui):
    if not gui:
        pytest.skip("Run this test separately and add --gui key to debug the testbench in a simulator")
    run_sim(tmp_path, [], simtool, gui)
