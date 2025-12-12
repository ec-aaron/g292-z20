# Gigabyte G292-Z20 Hardware Validation Test Suite

Automated hardware validation tests for the Gigabyte G292-Z20 server platform.

## Overview

This test suite validates critical hardware components:
- **CPU**: Model and core count verification
- **Memory**: DIMM count, size, and speed validation
- **GPUs**: Count verification and PCIe bandwidth testing
- **NICs**: Mellanox ConnectX-5 detection (1x Infiniband, 1x Ethernet)
- **NVMe Drives**: Lexar SSD inventory and write/read/verify functionality
- **Fans**: Basic fan detection
- **nvbandwidth**: GPU host-to-device memory bandwidth testing

## Prerequisites

- Ubuntu/Debian-based Linux system
- Root/sudo access (required for hardware access and test execution)
- CUDA Toolkit installed at `/usr/local/cuda` (for nvbandwidth tests)
- Internet connection (for setup.sh to download dependencies)

## Quick Start

### 1. Setup

Run the setup script to install all dependencies and build required tools:

```bash
./setup.sh
```

This will:
- Install system packages: `ipmitool`, `fio`, `build-essential`, `cmake`, etc.
- Create a Python virtual environment at `.venv`
- Install Python dependencies (`pytest`, `PyYAML`)
- Clone and build `nvbandwidth` for GPU memory bandwidth testing
- Verify CUDA toolkit installation

### 2. Configure Tests

Edit `tests/config.yaml` to match your hardware configuration:

```yaml
cpu:
  model_contains: "AMD EPYC 7402"

mem:
  dimms_expected: 8
  per_dimm_gib: 64
  speed_mhz: 2666

nvbandwidth:
  min_h2d_gbps: 25.0

disk:
  skip_write_test: false
  write_test_size_mb: 100

gpus:
  expect_count: 8
```

### 3. Run Tests

Execute all tests as root (required for hardware access):

```bash
./run.sh
```

Run specific tests:

```bash
./run.sh tests/test_cpu.py
./run.sh tests/test_disk.py -v
./run.sh tests/test_nvbandwidth.py
```

#### Enabling Disk Write Tests

Disk write tests are **disabled by default** for safety. To enable:

1. Set in `tests/config.yaml`:
```yaml
disk:
  skip_write_test: false
```

2. Mount drives (choose one):

**Manual mounting (recommended for interactive use):**
```bash
./lexar-drives.sh mount    # Mount drives
./run.sh                   # Run tests
./lexar-drives.sh unmount  # Unmount when done
```

**Auto-mount (for CI/CD):**
```yaml
disk:
  auto_mount_for_testing: true
```
Then `./run.sh` will automatically mount drives before testing.

## Test Descriptions

### CPU Tests (`test_cpu.py`)
- Validates CPU model contains expected string
- Checks core count matches configuration

### Memory Tests (`test_mem.py`)
- Verifies number of populated DIMMs
- Validates per-DIMM size (with tolerance)
- Checks configured memory speed

### GPU Tests (`test_gpu_pcie.py`)
- Counts detected GPUs
- Validates PCIe link speed and width

### NIC Tests (`test_nics.py`)
- Detects Mellanox ConnectX-5 cards
- Expects exactly 1 Infiniband controller
- Expects exactly 1 Ethernet controller
- Warns on multi-function/dual-port configurations

### Disk Tests (`test_disk.py`)
- **Inventory**: Validates 4x Lexar SSD NM790 4TB drives present
- **Boot Drive**: Checks for ~256GB NVMe drive
- **Write Test**: Uses `fio` to write/read/verify data on each mounted Lexar drive
  - Writes test file (default 100MB) to each mounted drive
  - Verifies data integrity with CRC32C checksums
  - Automatically cleans up test files
  - Skips unmounted drives for safety

### nvbandwidth Tests (`test_nvbandwidth.py`)
- Tests GPU host-to-device (H2D) memory bandwidth
- Validates minimum bandwidth threshold per GPU
- Checks CUDA runtime and driver versions

### Fan Tests (`test_fans.py`)
- Basic fan presence detection via IPMI

## Configuration Reference

### `tests/config.yaml`

#### CPU Configuration
```yaml
cpu:
  model_contains: "AMD EPYC 7402"  # Expected CPU model substring
```

#### Memory Configuration
```yaml
mem:
  dimms_expected: 8                # Number of populated DIMMs
  per_dimm_gib: 64                 # Expected size per DIMM in GiB
  speed_mhz: 2666                  # Minimum acceptable speed
  size_tolerance_gib: 0.5          # Size reporting tolerance
```

#### nvbandwidth Configuration
```yaml
nvbandwidth:
  bin: "/usr/local/bin/nvbandwidth"  # Optional: override binary path
  min_h2d_gbps: 25.0                 # Minimum H2D bandwidth (GB/s)
```

#### Disk Configuration
```yaml
disk:
  skip_write_test: true            # Disabled by default; set false to enable
  write_test_size_mb: 100          # Test file size (MB) per drive
  auto_mount_for_testing: false    # Auto-mount drives before tests (CI/CD)
```

#### GPU Configuration
```yaml
gpus:
  expect_count: 8             # Expected number of GPUs
```

## File Structure

```
g292-z20/
├── README.md                 # This file
├── requirements.txt          # Python dependencies
├── setup.sh                  # Setup and dependency installation
├── run.sh                    # Test execution wrapper (runs as root)
├── lexar-drives.sh           # Manage Lexar drive mounts (mount/unmount/status)
├── .venv/                    # Python virtual environment (created by setup.sh)
├── tests/
│   ├── config.yaml          # Hardware configuration
│   ├── conftest.py          # pytest configuration and fixtures
│   ├── test_cpu.py          # CPU validation tests
│   ├── test_mem.py          # Memory validation tests
│   ├── test_gpu_pcie.py     # GPU detection and PCIe tests
│   ├── test_nics.py         # Network interface tests
│   ├── test_disk.py         # NVMe inventory and write tests
│   ├── test_nvbandwidth.py  # GPU bandwidth tests
│   └── test_fans.py         # Fan detection tests
└── .gitignore               # Git ignore rules (includes .venv)
```

## Troubleshooting

### Tests Require Root Access
The test suite uses `subprocess` tools that require root privileges. Always run via:
```bash
sudo ./run.sh
```

### nvbandwidth Build Fails
Ensure CUDA toolkit is installed:
```bash
ls -la /usr/local/cuda/bin/nvcc
ls -la /usr/local/cuda/bin/cuobjdump
```

Check cmake version (requires ≥3.20):
```bash
cmake --version
```

### Disk Write Tests Failing
- Ensure Lexar drives are mounted
- Check available disk space
- Verify fio is installed: `which fio`
- Increase test size or disable: set `disk.skip_write_test: true` in config.yaml

### nvbandwidth Not Found
The binary should be at `/usr/local/bin/nvbandwidth` (symlinked by setup.sh).
Manual check:
```bash
ls -la /usr/local/bin/nvbandwidth
~/nvbandwidth/build/nvbandwidth --help
```

### Import Errors
Ensure you're using the virtualenv python via `run.sh`, not running pytest directly.

## Development

### Adding New Tests

1. Create a new test file in `tests/test_*.py`
2. Use the `cfg` fixture to access configuration
3. Follow existing test patterns for consistency
4. Update this README with test description

### Modifying Configuration

Edit `tests/config.yaml` and update the "Configuration Reference" section of this README.

## License

Internal use - Gigabyte G292-Z20 hardware validation.
