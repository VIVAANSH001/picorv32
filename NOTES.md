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
