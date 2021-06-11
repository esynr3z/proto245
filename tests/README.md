# Test environment

Environment is built around Python [pytest](https://docs.pytest.org/) framework - it offers some nice and easy to use tools for test execution control and parametrization out of the box.

Current workflow is based on the [pyhdlsim](https://github.com/esynr3z/pyhdlsim) example - ```sim.py``` is a wrapper around HDL simulators and ```test_*.py``` files contain tests.

Tested on:

* Windows 10, Python 3.8, Modelsim 10.6d
* Ubuntu 20.04, Python 3.8, Modelsim 2020.02

## Requirements

Several Python modules are required:

```bash
python3 -m pip install pytest pytest-xdist
```

## Frequently used commands

All the commands are invoked from the ```tests``` directory.

List all tests:

```bash
pytest --collect-only -q
```

Run all tests on all available cores in parallel:

```bash
pytest -v -n auto
```

Run only tests that have ```SINGLE``` and ```60e6``` substrings in their name:

```bash
pytest -v -n auto -k "SINGLE and 60e6"
```

Run "default" test with no parametrization to debug the testbench inside the simulator GUI:

```bash
pytest -v test_245sync.py::test_debug --gui
```

Run specific test using it's full name:

```bash
pytest -v test_245sync.py::test[SINGLE_CLK_DOMAIN-DATA_W=32-FIFO_CLK_FREQ=48e6-FT_CLK_FREQ=100e6-TESTCASE=test_read_corners]
```

Run specific test inside the simulator GUI (helpful for failed tests debugging):

```bash
pytest -v --gui test_245sync.py::test[SINGLE_CLK_DOMAIN-DATA_W=32-FIFO_CLK_FREQ=48e6-FT_CLK_FREQ=100e6-TESTCASE=test_read_corners]
```

Run tests in the specified simulator (also compatible with variants above):

```bash
pytest -v -n auto --sim vivado
```
