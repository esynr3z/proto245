#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Tests for proto245a"""

import pytest
from sim import Simulator, path, get_test_names


def run_sim(cwd, defines, simtool, gui):
    sim = Simulator(name=simtool, gui=gui, cwd=cwd)
    tb_dir = path("tb_245async")
    tb_common_dir = path("common")
    rtl_dir = path("../src")
    sim.incdirs += [tb_dir, tb_common_dir, rtl_dir, cwd]
    sim.sources += tb_common_dir.glob('*.sv')
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


@pytest.mark.parametrize('testcase', ["TESTCASE=test_rx", "TESTCASE=test_tx"])
@pytest.mark.parametrize('clock_domains', ["MULTIPLE_CLK_DOMAINS",  "SINGLE_CLK_DOMAIN"])
def test(tmp_path, testcase, clock_domains, simtool, gui):
    defines = [testcase, clock_domains]
    res = run_sim(tmp_path, defines, simtool, gui)
    if not gui:
        assert res


def test_debug(tmp_path, simtool, gui):
    if not gui:
        pytest.skip("Run this test separately and add --gui key to debug the testbench in a simulator")
    run_sim(tmp_path, [], simtool, gui)
