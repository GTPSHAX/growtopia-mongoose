# growtopia-mongoose

A lightweight HTTP server built in C for Growtopia Private Server (GTPS), powered by the [Mongoose](https://github.com/cesanta/mongoose) embedded networking library.

## Overview

`growtopia-mongoose` provides a simple, cross-platform HTTP server designed to serve the cache files for a Growtopia Private Server. It is written in C99 and uses Mongoose as a git submodule for its networking layer.

## Features

- Lightweight HTTP server written in pure C
- Cross-platform: supports Linux, macOS, and Windows (MSVC & GCC/Clang)
- Uses [Mongoose](https://github.com/cesanta/mongoose) as the embedded networking backend
- Configurable via `mongoose_config.h`
- CMake-based build system

## Requirements

- CMake 3.16+
- C99-compatible compiler (GCC, Clang, or MSVC)
- Git (for cloning submodules)

**Linux/macOS:**

- `pthreads`
- `libm`
- `libdl`

**Windows:**

- `ws2_32`
- `crypt32`

## Getting Started

### 1. Clone the repository

```bash
git clone --recurse-submodules https://github.com/GTPSHAX/growtopia-mongoose.git
cd growtopia-mongoose
```

> [!NOTE]
> If you already cloned without `--recurse-submodules`, initialize the submodule manually:
>
> ```bash
> git submodule update --init --recursive
> ```

### 2. Build

Build scripts are provided in the `scripts/` directory for each platform. All scripts default to a **Debug** build, pass `--release` for an optimized build.

**Linux / macOS [native]:**

```bash
# Debug (default)
bash scripts/build.sh

# Release
bash scripts/build.sh --release

# Clean + release
bash scripts/build.sh --release --clean
```

**Linux cross-compile for Windows (requires `mingw-w64`):**

```bash
# Debug (default)
bash scripts/build-windows.sh

# Release
bash scripts/build-windows.sh --release

# With a custom generator (e.g. Ninja)
bash scripts/build-windows.sh --release --generator Ninja
```

**Windows with Command Prompt:**

```bat
:: Debug (default)
scripts\build.bat

:: Release
scripts\build.bat --release

:: Clean + release
scripts\build.bat --release --clean
```

All scripts support `--build-dir <path>` to override the output directory, and `--help` to see all options. The compiled binary will be named `http-server` (or `http-server.exe` on Windows).

### 3. Run

```bash
./http-server [options]
```

| Flag          | Default               | Description                     |
| ------------- | --------------------- | ------------------------------- |
| `--http ADDR` | `http://0.0.0.0:8080` | HTTP listen address and port    |
| `--root DIR`  | `public`              | Static file root directory      |
| `--log LEVEL` | `2`                   | Log verbosity (see table below) |

**Log levels:**

| Level | Flag      | When to use                                       |
| ----- | --------- | ------------------------------------------------- |
| `0`   | `--log 0` | Silent, best throughput when file cache is stable |
| `1`   | `--log 1` | Errors only, recommended for production           |
| `2`   | `--log 2` | Info, default, good for staging                   |
| `3`   | `--log 3` | Debug                                             |
| `4`   | `--log 4` | Verbose, full request/response tracing            |

**Examples:**

```bash
# Production deploy on port 80, errors only
./http-server --http http://0.0.0.0:80 --root ./dist --log 1

# Silent mode for maximum throughput (stable cache assumed)
./http-server --log 0

# Verbose tracing for debugging
./http-server --http http://0.0.0.0:8080 --root ./public --log 4
```

> [!TIP]
> **Pro tip:** Once your file cache is warm and stable, `--log 0` eliminates all logging overhead and gives the best raw performance. Use `--log 1` for production deployments where you still want error visibility, and reserve `--log 4` for local debugging only.

## Project Structure

```
growtopia-mongoose/
├── cmake/              # CMake helper modules
├── dist/               # Distribution / output files
├── lib/
│   └── mongoose/       # Mongoose submodule (cesanta/mongoose)
├── scripts/            # Build or utility scripts
├── src/
│   ├── main.c          # Entry point
│   └── mongoose_config.h  # Mongoose configuration
├── .gitmodules
├── CMakeLists.txt
└── README.md
```

## Configuration

Server behavior can be customized by editing `src/mongoose_config.h`. This file is automatically force-included into every translation unit at compile time via compiler flags.

## Performance Tuning

For high-load or benchmarking scenarios, tuning scripts are provided to raise system-level limits on Linux and Windows.

### Linux: `scripts/tune_highload.sh`

Adjusts kernel TCP parameters and file descriptor limits via `sysctl` and `limits.conf`. **Must be run as root.**

```bash
sudo bash scripts/tune_highload.sh
```

What it applies:

| Setting                        | Value        | Effect                            |
| ------------------------------ | ------------ | --------------------------------- |
| `net.ipv4.tcp_tw_reuse`        | `1`          | Allows reuse of TIME_WAIT sockets |
| `net.ipv4.ip_local_port_range` | `1024 65535` | Expands ephemeral port range      |
| `net.core.somaxconn`           | `10000`      | Increases listen backlog          |
| `net.ipv4.tcp_max_syn_backlog` | `10000`      | Increases SYN queue size          |
| `net.core.netdev_max_backlog`  | `50000`      | Increases NIC receive queue       |
| `net.ipv4.tcp_max_tw_buckets`  | `200000`     | Raises TIME_WAIT bucket limit     |
| `nofile` (soft + hard)         | `50000`      | Raises open file descriptor limit |

Backups of the original `sysctl.conf` and `limits.conf` are created automatically before any changes are made.

### Windows: `scripts/tune_highload.ps1`

Run from an **Administrator** PowerShell session:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tune_highload.ps1
```

> These scripts are intended for server/benchmark environments. Avoid running them on personal or shared machines without understanding the implications.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Author

[GTPSHAX](https://github.com/GTPSHAX)
