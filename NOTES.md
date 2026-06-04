# PICO RV32 : CUSTOM INSTRUCTIONS

## Baseline:
- So this project is basically a strictly for me to learn about how instructions will look and how they are organized in actual RISC-V CPU's. The Pico RV32I is a very simple CPU and thus I think it is a good starting point to learning how instructions are organized and recognized by the CPU.

- From what I know till now the PICO RV32 is a open source RISC-V CPU and amazingly it fits in **ONE VERILOG FILE**. Its not pipeline and works on one instruction at a time and thus it's very small and simple but for learners like me it acts as a doorway to RISC-V CPUs.

- Since I want to know exactly how the insides of the CPU look especially when it comes to running instructions I will not be using the PCPI to do this.

- My first goal is to make sure the PICO code that I have forked from github works before I begin.

## Setting up the Enviornment:
- First I have to verify if I have the basic tools needed.

```bash
git --version
iverilog -V
```

- Next I have to clone the fork to start working on it and then also create a branch for the custom code so observers can see the original code and my version cleanly.

```bash
cd ~
git clone https://github.com/VIVAANSH001/picorv32.git
cd picorv32
git checkout -b custom-instructions
```

- So I need two tools to make the testing work , they are make so that rather than having to give the instructiosn every time I can use the Makefile already given to run tests and other work. Also need cross compiling here and for that I donwload a RISC-V compiler so that I have RISC-V binary to my testbench so that the CPU can understand otherwise I will have an x86 compiler working on the testbench.

```bash
sudo apt install make -y
sudo apt install gcc-riscv64-unknown-elf -y
```

- Know I have to means to check and create a baseline to basically verify if my code breaks anything and so on. So I run the command for the Makefile.

```bash
make test TOOLCHAIN_PREFIX=/usr/bin/riscv64-unknown-elf-
```

- ALRIGHT IT WORKS! `ALL TESTS PASSED`

## Understanding the CPU before touching it:

- So before I could add anything I needed to understand how PicoRV32 actually works. Unlike my own CPU project which is a 5 stage pipeline, PicoRV32 is a state machine. It does one instruction at a time, fetch then decode then load registers then execute then writeback and then back to fetch. No overlapping, no parallelism.Thus this CPU prioritized simplicity over speed.
- The technique I used to find where to make changes was basically shadowing the ADD instruction. ADD is the most basic R-type instruction and is referenced everywhere in the code. So I ran `grep -n "instr_add" picorv32.v` and that gave me all the line numbers I needed to look at.

## The 5 Instructions:

- All 5 use opcode `0x0B` which is the custom-0 slot in RISC-V. The reason I used this specifically and not just any unused opcode is that the RISC-V spec explicitly reserves these custom slots and promises they will never be assigned to anything official. So if you use a random unused opcode today it might collide with something in a future version of RISC-V. Thus Custom-0 was the way forward for me.
- All 5 are R-type format, so they follow the standard 32 bit layout with funct7,rs2, rs1, funct3, rd and opcode fields. I use funct3 to distinguish between the 5 since funct7 is 0000000 for all of them.
- REV (funct3 = 000) reverses all 32 bits of rs1. Bit 31 goes to position 0, bit 0 goes to position 31 etc. Important thing is the bit values dont change, just their positions swap. So 0x00000005 reversed is 0xA0000000.
- ABS (funct3 = 001) gives the signed absolute value of rs1. In two's complement a number is negative when bit 31 is 1. To negate it you do ~x + 1. So the logic is basically if rs1[31] is 1 then output ~rs1 + 1, otherwise output rs1 as is.
- MIN (funct3 = 010) and MAX (funct3 = 011) do signed minimum and maximum of rs1 and rs2. The trick here is using $signed() cast in Verilog so the comparator treats the top bit as a sign bit rather than just a magnitude bit. Without that you get wrong results on negative numbers.
- SATADD (funct3 = 100) is saturating signed add. Normal addition wraps around on overflow which is a disaster in a lot of DSP and audio applications. Saturating add clamps to INT_MAX or INT_MIN instead. Overflow only happens when both inputs have the same sign but the result has a different sign, mixed signs can never overflow. I used a 33 bit extended add to detect this cleanly.

## The 8 Touch-points in picorv32.v:

So I ended up having to edit 8 places in the file. I originally expected maybe 4 or 5 but the extra ones were honestly the most educational part.

- Touch-point 1 (~line 650): Declared the 5 new instruction flags as registers. Every instruction the CPU recognises needs a 1 bit signal that goes high when that instruction is current. So I added `reg instr_rev, instr_abs, instr_min, instr_max, instr_satadd;`

- Touch-point 2 (~line 676): Declared `is_custom` register and the SATADD helper wires. The existing `is_alu_reg_reg` flag only goes high for the standard R-type opcode 0110011, ours is 0001011 so it would always be false for us. Also pre-declared three wires for the SATADD computation here which was necessary because of a Verilog rule I learned the hard way (see bug 1 below).

- Touch-point 3 (~line 879): Set `is_custom` in the decoder. Right after the line that sets `is_alu_reg_reg`, I added a line that checks if the opcode bits match 0001011.

- Touch-point 4 (~line 1068 and 1154): Decoded each instruction by funct3. Once `is_custom` confirms the opcode, I use funct3 to figure out which of the 5 instructions it is. Also had to add resets to 0 in the reset block so the flags dont hold stale values.

- Touch-point 5 (~line 1238): The SATADD helper logic using continuous assign. This one lives outside the always block in the module body. More on why below.

- Touch-point 6 (~line 1283): The actual ALU compute logic. Added one case per instruction inside the combinational ALU. REV needed a named block `begin : rev_block` with a local integer for the loop index. ABS, MIN, MAX are one-liners. SATADD just picks up the wire computed in touch-point 5.

- Touch-point 7 (~line 684): The trap list. This was the sneaky one. `instr_trap` is computed as basically none of the known instructions matched. It is the logical NOT of a big OR list of every legal instruction flag. Our flags were not in that list so the CPU was declaring every custom instruction illegal and trapping immediately. Fix was just adding our 5 flags to that list.

- Touch-point 8 (~line 1746): Routing in cpu_state_ld_rs1. After fixing the trap, REV and ABS still were not writing back. In the load-rs1 state there is a case statement that decides the next state and the path that loads rs1 and jumps directly to execute only listed certain known single-source instructions. REV and ABS needed to be added there. MIN, MAX and SATADD already fell through the default path which loads rs2 as well, which is exactly what they need.

## Hand encoding the instructions:

- Since the assembler has no idea our instructions exist, writing something like `REV a0, a1` would just error. So I had to hand build the 32 bit instruction word for each one and drop it into the testbench memory using `.word 0x...`
- For REV a0, a1 for example: rd = a0 = x10 = 01010, rs1 = a1 = x11 = 01011, rs2 = x0 = 00000, funct3 = 000, funct7 = 0000000, opcode = 0001011. Concatenate everything and you get 0x0005850B.

## Writing the testbench:

- This was honestly the most challenging part of this project as I have never written a testbench for a CPU but nevertheless it was a good learning experience.
- Alright so I wrote custom_test.v from scratch. The basic idea is the testbench acts as the memory. The CPU requests an address and we hand back the word. `mem_addr >> 2` converts byte address to word index since RISC-V is byte addressed but we store words.
- Loaded the registers first using standard ADDI instructions (a1 = 5, a2 = -3) and then placed all 5 custom instructions after that, then an ebreak to cleanly end the simulation.
- The most useful debugging tool was a live a0 monitor inside the testbench that prints every write to a0 as it happens. That way I could see all 5 results in order as they came out rather than only at the end.
- Also worth noting, using `uut.` prefix in the testbench lets you probe internal signals of the instantiated module. Obviously this is simulation only, you cannot do this in real hardware.

## The bugs I ran into:

- Bug 1 was a syntax error, Malformed statement. I had put the wire and assign declarations for SATADD inside the combinational `always @*` ALU block. This was a very silly mistake as this was something I had learnt a long time ago. So basically in a always block you cannot assign anything to a wire thus it gave me an error only if I was using registers would this have worked.

- Bug 2 was that the simulation was trapping after about 25 cycles and a0 was full X, never written. This was the trap list issue at touch-point 7. The CPU was seeing my instructions as completely illegal even though the decode logic was correct. Decoding an instruction and the CPU accepting it as legal are two completely different things. There is a separate gatekeeper. X values in simulation almost always mean nothing drove this signal which is a good debug hint.

- Bug 3 was after fixing the trap, REV and ABS still were not writing back. This was the routing issue at touch-point 8. Even if the CPU accepts an instruction as legal and the ALU knows how to compute it, if the control flow never routes it to the right state it just dies silently. MIN, MAX and SATADD happened to work because they use two source registers and fell through the default path. REV and ABS only use rs1 so they needed explicit routing.

## Final results:

```
a0 written: 0xa0000000 --> REV(5) correct
a0 written: 0x00000005 --> ABS(5) correct
a0 written: 0xfffffffd --> MIN(5,-3) = -3 correct
a0 written: 0x00000005 --> MAX(5,-3) = 5 correct
a0 written: 0x00000002 --> SATADD(5,-3) = 2 correct
```

- After that ran `make test TOOLCHAIN_PREFIX=/usr/bin/riscv64-unknown-elf-` and got ALL TESTS PASSED. This is the regression test, it proves adding our instructions did not break any of the roughly 45 standard instructions.

## FINAL THANK YOU!!

- Thanks to whoever took their time going through this work of mine it taught me a lot especially on the path instructions take within a CPU and I hope to learn a lot more in the coming years about this fascinating field.