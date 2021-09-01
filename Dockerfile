FROM ubuntu:18.04 AS builder
RUN apt-get update
RUN apt-get install -y autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev git
RUN git clone https://github.com/riscv/riscv-gnu-toolchain
RUN cd riscv-gnu-toolchain
RUN ./riscv-gnu-toolchain/configure --prefix=/opt/riscv --with-arch=rv32imc --with-abi=ilp32
RUN make -j 4

FROM ubuntu:18.04 as runner
COPY --from=builder /opt/riscv /opt/riscv
RUN apt-get update
RUN apt-get install -y build-essential python3 git iverilog verilator bsdmainutils device-tree-compiler srecord python3-pip
RUN pip3 install --user -U fusesoc
ENV RISCV=/opt/riscv/bin
RUN export PATH=/opt/riscv/bin:$PATH
RUN apt-get install -y libelf-dev binutils-dev libfdt-dev gdb device-tree-compiler
RUN echo export PATH=/opt/riscv/bin/:$PATH >> ~/.bashrc