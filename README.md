# RISC-V(irtual) Machine

## Requirement
- python3.10
- pytest

## Usage

Run tests.
```
pytest
```

A quick sanity check.
```
python3 -m riscvm.emulator < tests/fib.bin
```

## Develop

- Clone this project
- `cd riscvm`
- `bash pub.sh`
- Install this package in editable mode (i.e. setuptools "develop mode") `pip install -e .`
- Sanity check `echo 12345678 | python3 -m riscvm`
