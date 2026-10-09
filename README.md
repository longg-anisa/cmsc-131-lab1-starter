<!--no-pdf-->
# CMSC 131 Lab 1 Starter

[![lab1-checks](https://github.com/longg-anisa/cmsc-131-lab1-starter/actions/workflows/test.yml/badge.svg)](https://github.com/longg-anisa/cmsc-131-lab1-starter/actions/workflows/test.yml)
<!-- [![lab1-checks](https://github.com/WhiteLicorice/cmsc-131-lab1-starter/actions/workflows/test.yml/badge.svg)](https://github.com/WhiteLicorice/cmsc-131-lab1-starter/actions/workflows/test.yml) -->

Decode, encode, and checksum 20-byte IPv4 packet headers under a C driver.
The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: argument parsing and file I/O
cdecl.h             provided: the calling-convention macros
decode.asm          yours
encode.asm          yours
checksum.asm        yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register discipline checks for contract_test
tests/              provided: the header fixtures, their expected output,
                    and manifest.txt, the list both passes read
LICENSE             CC BY-NC-SA 4.0, inherited from the pcasm material
```

## What to Run

On Windows, run these commands in Git Bash, the shell from Block 1. In that
shell, `make` is your alias for `mingw32-make`. On Linux, use your terminal.

```bash
make
make check
```

`make` builds `renpkt` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The gate has two passes. The first decodes every header listed in
`tests/manifest.txt` and compares the output with `tests/expected/`. The
second is `contract_test`. It decodes and re-encodes every header the
manifest marks valid. It checks a checksum vector that needs the carry
folded twice. It checks that all three routines keep `ebx`, `esi`, `edi`,
and `ebp`, and return with `esp` where the call left it. A program can pass
the first pass and fail the second. That failure is the usual encoder bug.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, which
makes every check fail: `7 of 7 checks differ`. That red run is the correct
starting state for a starter. The badge stays red until you implement the
routines.

## Adding a Header

Put the header in `tests/NAME.bin`. Write the output `renpkt --decode`
must print for it in `tests/expected/NAME.out`. Then add one line to
`tests/manifest.txt`:

```text
NAME valid
```

Use `invalid` for a header with a wrong checksum. A valid header joins the
round trip in `contract_test` as well as the decode pass. The gate fails
and names the file when a `.bin` is not in the manifest, and when a listed
header has no expected file.

## The Driver's Argument Checks

`renpkt --encode` refuses a value its field cannot hold, and two values the
standard forbids. `--len` takes 20 through 65535, because the total length
counts the header. It defaults to 20. `--flags` takes 0 through 3, because
the top bit of the field is reserved and must be zero. `--df` sets 2 and
`--mf` sets 1. A refused option exits with status 2 and writes no file.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

## Fixtures

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`,
`contract_test.c`, `contract_regs.asm`, or a provided `tests/` file appears
as a diff in the open. Your own headers and manifest lines are additions,
not edits.

---

## Design Notes
### Problem analysis

**What it writes and what it reads?**

|  | Reads | Writes |
|---|---|---|
| Decode | Reading the 20 bytes of the 13 fields provided in `tests/NAME.bin` by the sample codes or encoded by the encoder. | From the 20 bytes it read, decode must write it in readable form, and the verification of the checksum with its validity printed out in the terminal. |
| Encode | Reading the command-line field values inputted individually. | The 13 field values from the command-line packed back to the 20-byte format of IPv4. The newly built header is stored in `NAME.bin`.

**Which field is the hard one?** \
In Bytes 6-7, they are divided into the flags and fragment offset. Specifically, byte 6’s top three bytes (bits 7-5) indicate the flag for DF (bit 6) and MF (bit 5). Bit 7 is reserved as 0. Byte 6’s remaining bits are grouped with all the bits in byte 7 to form the Fragment Offset. This means Fragment Offset will have 13 bits, which cannot be read with mov. A shift and mask is necessary for this.

**State the header layout in your own words.**\
The IPv4 header is a fixed 20 bytes packed together, and they can be interpreted depending on their position in the 20-byte structure. Their meanings are as follows:
- Bytes 0-3
     - Byte 0: Version, IHL
     - Byte 1: DSCP, ECN
    - Bytes 2-3: Total Length (grouped as a 2-byte number)
- Bytes 4-7
    - Bytes 4-5: Identification (grouped as a 2-byte number)
    - Bytes 6-7: Flags + Fragment Offset
    - Byte 6 is divided into two different fields:
        - Top 3 bits of byte 6 are Flags, while its remaining bits are grouped with byte 7 to form the Fragment Offset.
- Bytes 8-11
    - Byte 8: TTL
    - Byte 9: Protocol
    - Byte 10-11: Header Checksum
- Bytes 12-15
    - Source Address (4 separate one-byte octets)
- Bytes 16-19
    - Destination Address (4 separate one-byte octets)

**Five obligations of the cdecl routine**
1. Preserve `ebx`, `esi`,  `edi` and `ebp`; `eax`, `ecx` and `edx` are caller-saved.
2. Return the result in `eax` (`ax` for 16-bit values for `ip_checksum`).
3. Balance the stack as every push inside the routine is popped before `ret`. 
4. Leave arguments alone because the caller pushed them, so the caller also cleans them up (`add esp, N`) after the call returns. 
5. Return via `ret`.

**Full trace: `decode_header(hdr, &f)`**
| # | Instruction | Effect | esp after |
|---|---|---|---|
| 1 | `push dword [address of f]` | 2nd arg pushed first (right-to-left) | `0x0FFC` |
| 2 | `push dword [address of hdr]` | 1st arg pushed last | `0x0FF8` |
| 3 | `call _decode_header` | return address pushed automatically | `0x0FF4` |
| 4 | `push ebp` | save caller's frame pointer | `0x0FF0` |
| 5 | `mov ebp, esp` | set up new frame; esp unchanged | `0x0FF0` |
| 6 | — | `[ebp+8] = hdr`, `[ebp+12] = &f` | `0x0FF0` |
| 7 | `push` any callee-saved regs used | e.g. `ebx`, `esi`, `edi` | drops by 4 per push |
| 8 | *(routine body runs)* | decode/encode logic | unchanged |
| 9 | set `eax` | return value goes here | unchanged |
| 10 | `pop` those regs, reverse order | undo step 7 | back to `0x0FF0` |
| 11 | `leave` | `mov esp, ebp` then `pop ebp` | `0x0FF4` |
| 12 | `ret` | pops return address into `eip` | `0x0FF8` |
| 13 | *(back in driver.c)* `add esp, 8` | caller removes its 2 pushed args | `0x1000` |

### Solution architecture

The `renpkt` tool is divided into three assembly routines: `decode_header`, `encode_header`, and `ip_checksum`. `decode_header` reads the 20-byte IPv4 header, extracts the 13 supported fields using shifts and masks, and stores them in `ipv4_fields`. `encode_header`, on the other hand, performs the same operation in reverse by reading the fields from `ipv4_fields` and constructing the 20-byte header in IPv4 network byte order (big-endian). Lastly, `ip_checksum` processes the header as 16-bit big-endian words and computes the one's-complement checksum with end-around carry. 

To implement these routines, the following registers will be used for each routine:
- `decode_header`: `ESI` for the input header, `EDI` for the output struct.
- `encode_header`: `EDI` for the input struct, `ESI` for the output header. 
- `ip_checksum`: `ESI` for the current header position, `ECX` for the remaining length, `EAX` for the checksum accumulator. 

Temporary values use caller-saved registers (`EAX`, `ECX`, `EDX`) where possible, and callee-saved registers are preserved.

The routines access the `ipv4_fields` structure using the following offsets:
| Offset | Field |
|---:|---|
| `+0` | `version` |
| `+4` | `ihl` |
| `+8` | `dscp` |
| `+12` | `ecn` |
| `+16` | `total_length` |
| `+20` | `identification` |
| `+24` | `flags` |
| `+28` | `fragment_offset` |
| `+32` | `ttl` |
| `+36` | `protocol` |
| `+40` | `checksum` |
| `+44` | `src[0..3]` |
| `+48` | `dst[0..3]` |

### Timeline

| Week | Goal | Owner |
|---|---|---|
| 1 | The C boundary, Design Notes, Prototype for decode | All |
| 2 | Complete `decode.asm` path and `encode.asm` path (end to end) | Carreon, Kaindoy |
| 3 | Checksum and tests(`checksum.asm`, `tests/`), `make check` passes all tests and round trip, Quirks and Issues of `README.md` | Cambel, De Guzman|
| 4 | Defense | All |

## Subsystem Ownership

| Subsystem | Owner |
|---|---|
| Decode path (`decode.asm`) | Carreon |
| Encode path (`encode.asm`) | Kaindoy |
| Checksum and tests (`checksum.asm`, `tests/`) | Cambel, De Guzman |

## Quirks and Issues

- popa restores `eax` in checksum.asm, overwriting checksum result.  **[RESOLVED]**
    - Fix: stash `eax` to a reserve doubleword, then push its value back to `eax`.
- flag and fragment offsets do not give correct value.  **[RESOLVED]**
    - Fix: switched `eax` and `[edi+offset]` in `mov` in lines 126 and 127, decode.asm 
