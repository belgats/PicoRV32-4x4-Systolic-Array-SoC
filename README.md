# PicoRV32 4x4 Systolic-Array SoC

This project integrates a 4x4 MAC-based systolic array into a small
PicoRV32 RISC-V system-on-chip. Software running on PicoRV32 writes matrix
data through an AXI4-Lite memory-mapped accelerator interface, starts the
accelerator, waits for completion, and reads back the 16 matrix-multiplication
results.

The current demonstration multiplies two 4x4 matrices:

```text
A = B =
[ 1  2  3  4 ]
[ 5  6  7  8 ]
[ 9 10 11 12 ]
[13 14 15 16 ]
```

The complete CPU-to-hardware test passes and reports:

```text
PASS: full 4x4 matrix result verified at cycle 736
```

## Features

- PicoRV32 RV32IM processor.
- 32-bit AXI4-Lite interconnect and address crossbar.
- 64 KiB on-chip RAM initialized from `firmware/firmware.hex`.
- Memory-mapped 4x4 systolic matrix-multiplication accelerator.
- Eight 64-bit A-stream words and eight 64-bit B-stream words.
- Four 16-bit lanes per stream word.
- Sixteen 32-bit result registers.
- Hardware clear, feed, drain, completion, and result-capture control.
- Verilator testbench that checks every result and detects CPU traps and
  simulation timeouts.

## Repository layout

```text
.
├── firmware/
│   ├── main.c                 # PicoRV32 accelerator driver
│   ├── start.S                # Reset entry point and stack setup
│   ├── linker.ld              # 64 KiB RAM linker script
│   └── firmware.hex           # ROM/RAM image loaded by simulation
├── soc/
│   ├── rtl/
│   │   ├── soc_top.sv         # CPU, RAM, AXI-Lite crossbar, accelerator
│   │   ├── soc_pkg.sv         # AXI types and crossbar configuration
│   │   ├── accel_regs.sv      # Accelerator registers and controller
│   │   └── axi_lite_ram.sv    # AXI-Lite RAM model
│   └── tb/tb_soc.sv           # Full end-to-end verification testbench
├── picorv32/                  # PicoRV32 CPU source and utilities
├── axi/                       # AXI implementation and dependencies
├── Systolic-Array-for-Matrix-Multiplication/
│   ├── rtl/                   # Original standalone reference array
│   └── run.sh                 # Standalone reference simulation
└── .gitignore                 # Local build and dependency exclusions
```

The `axi` and `picorv32` directories contain upstream components used by the
SoC. The integrated accelerator used by the top-level SoC is
`soc/rtl/accel_regs.sv`.

## Architecture

```text
                           Software
                              │
                              ▼
                     ┌─────────────────┐
                     │    PicoRV32     │
                     │    RV32IM CPU   │
                     └────────┬────────┘
                              │ 32-bit AXI4-Lite
                              ▼
                     ┌─────────────────┐
                     │ AXI-Lite XBAR   │
                     └──────┬─────┬────┘
                            │     │
             0x0000_0000    │     │ 0x1000_0000
                            ▼     ▼
                    ┌──────────┐ ┌─────────────────────┐
                    │ 64 KiB   │ │ Accelerator registers│
                    │ AXI RAM  │ │ and controller       │
                    └──────────┘ └──────────┬──────────┘
                                            │
                              registered A/B stream inputs
                                            ▼
                                  ┌─────────────────┐
                                  │ 4x4 systolic    │
                                  │ MAC array       │
                                  └────────┬────────┘
                                           │ 16 x 32-bit
                                           ▼
                                  result register window
```

Each processing element performs a multiply-accumulate operation:

```text
accumulator <= accumulator + (a * b)
```

The array shifts A values horizontally and B values vertically. The
accelerator controller supplies a stable stream before each sampling clock,
then provides zero-valued drain cycles so all partial sums reach their final
positions before the results are captured.

The controller uses a per-operation clear sequence. Therefore a new
operation can clear the previous partial sums without resetting the entire
SoC.

## Memory map

The accelerator is mapped at `0x1000_0000`.

| Address | Register | Description |
|---:|---|---|
| `0x1000_0000` | `CTRL` | Write bit 0 as `1` to start |
| `0x1000_0004` | `STATUS` | Read bit 0; `1` means results are complete |
| `0x1000_0008` to `0x1000_0044` | `A_STREAM[0..7]` | Eight 64-bit A stream words |
| `0x1000_0048` to `0x1000_0084` | `B_STREAM[0..7]` | Eight 64-bit B stream words |
| `0x1000_0088` to `0x1000_00C4` | `RESULT[0..15]` | Sixteen 32-bit result words |

The AXI-Lite data bus is 32 bits wide, so every 64-bit stream word is written
as two 32-bit writes:

```text
low 32 bits:  base + 8*index
high 32 bits: base + 8*index + 4
```

Within a 64-bit stream word, lane `0` is bits `[15:0]`, lane `1` is
`[31:16]`, lane `2` is `[47:32]`, and lane `3` is `[63:48]`.

## Systolic input schedule

For the example matrices, firmware supplies these stable streams:

```text
A[0] = [ 1,  0,  0,  0]     B[0] = [ 1,  0,  0,  0]
A[1] = [ 5,  2,  0,  0]     B[1] = [ 2,  5,  0,  0]
A[2] = [ 9,  6,  3,  0]     B[2] = [ 3,  6,  9,  0]
A[3] = [13, 10,  7,  4]     B[3] = [ 4,  7, 10, 13]
A[4] = [ 0, 14, 11,  8]     B[4] = [ 0,  8, 11, 14]
A[5] = [ 0,  0, 15, 12]     B[5] = [ 0,  0, 12, 15]
A[6] = [ 0,  0,  0, 16]     B[6] = [ 0,  0,  0, 16]
A[7] = [ 0,  0,  0,  0]     B[7] = [ 0,  0,  0,  0]
```

The final zero stream and controller drain phase flush the pipeline without
adding to the accumulated results.

## Requirements

Install the following tools locally:

- Verilator
- RISC-V GCC toolchain with `riscv64-unknown-elf-gcc`
- GNU binutils for RISC-V
- Python 3
- Git

The simulator is a local Verilator build product and is intentionally not
stored in Git. A rebuild requires Verilator and the AXI dependencies managed
by Bender.

## Build and run the full SoC test

The full simulator is generated locally. From the project root:

```bash
cd axi
bender sources -f > ../axi_sources.json
cd ..
jq -r '.[].files[]' axi_sources.json \
  | grep -v '/common_cells/.*/src/deprecated/find_first_one.sv' \
  > /tmp/axi_sources.filtered.f

verilator \
  --binary \
  --timing \
  --top-module tb_soc \
  -Iaxi/include \
  -Iaxi/src \
  -Isoc/rtl \
  -f /tmp/axi_sources.filtered.f \
  picorv32/picorv32.v \
  soc/rtl/soc_pkg.sv \
  soc/rtl/accel_regs.sv \
  soc/rtl/axi_lite_ram.sv \
  soc/rtl/soc_top.sv \
  soc/tb/tb_soc.sv
```

Run the generated test:

```bash
./obj_dir/Vtb_soc
```

A successful run ends with:

```text
PASS: full 4x4 matrix result verified at cycle 736
```

The simulator also fails if:

- PicoRV32 asserts `trap_o`;
- the accelerator never reports completion;
- the debug value is unexpected;
- any of the 16 result words differs from the expected value.

The simulation reads `firmware/firmware.hex` from the project root, so run
the simulator from the project root.

## Rebuild the firmware

The firmware source is `firmware/main.c`. It writes all stream words, starts
the accelerator, polls `STATUS`, and reads all 16 result registers.

```bash
riscv64-unknown-elf-gcc \
  -march=rv32im -mabi=ilp32 \
  -nostdlib -ffreestanding -fno-builtin -Os \
  -T firmware/linker.ld \
  firmware/start.S firmware/main.c \
  -o firmware/firmware.elf

riscv64-unknown-elf-objcopy \
  -O binary firmware/firmware.elf firmware/firmware.bin

python3 picorv32/firmware/makehex.py \
  firmware/firmware.bin 16384 > firmware/firmware.hex
```

Then rerun:

```bash
./obj_dir/Vtb_soc
```

The final `16384` value produces a 64 KiB image because the RAM contains
16384 32-bit words.

## Standalone systolic-array test

The original reference array has its own testbench:

```bash
cd Systolic-Array-for-Matrix-Multiplication
./run.sh
```

This requires `iverilog` and `vvp`. The integrated SoC test uses Verilator and
is the authoritative end-to-end test because it covers firmware, PicoRV32,
AXI-Lite routing, accelerator control, computation, and result readback.

## How correctness is confirmed

For the example input, the expected mathematical result is:

```text
C = A x B =
[  90  100  110  120 ]
[ 202  228  254  280 ]
[ 314  356  398  440 ]
[ 426  484  542  600 ]
```

For example, the first element is the dot product of row 0 of `A` and column
0 of `B`:

```text
C[0][0] = 1*1 + 2*5 + 3*9 + 4*13
        = 1 + 10 + 27 + 52
        = 90
```

The testbench in `soc/tb/tb_soc.sv` independently stores all 16 expected
values, waits for `dut.accel.status_q[0]`, and compares each 32-bit result:

```text
result[0]  = 90
result[1]  = 100
...
result[15] = 600
```

The test is considered successful only when every comparison passes. This
confirms the complete path:

```text
CPU firmware
  -> AXI-Lite writes
  -> accelerator stream storage
  -> registered systolic input schedule
  -> 4x4 MAC computation
  -> result capture
  -> AXI-Lite result readback
```

## Publishing this project to GitHub

The root repository is already initialized locally and the nested upstream
Git metadata has been removed for a self-contained source snapshot. Set the
GitHub remote and push the current `main` branch:

```bash
cd /home/gams/project

git remote set-url origin \
  https://github.com/belgats/PicoRV32-4x4-Systolic-Array-SoC.git
git add -A
git commit -m "Remove obsolete project folders"
git push -u origin main
```

Check what will be included before pushing:

```bash
git status
git diff --cached --stat
```

Do not commit generated build directories such as `obj_dir/`, dependency
checkout databases such as `axi/.bender/`, or large generated dependency
artifacts unless you intentionally want to publish them. If the generated simulator is needed, regenerate it locally rather than
committing `obj_dir/`.

For an existing GitHub checkout, use:

```bash
git add README.md
git commit -m "Add project documentation"
git push
```

## License and upstream components

The project includes upstream PicoRV32, AXI, and systolic-array sources.
Preserve their respective license and attribution files when publishing the
repository. Add a project-specific license at the repository root if you want
to define licensing terms for your integration and firmware.
