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

ARG DEBIAN_FRONTEND=noninteractive
ARG SYSTEMC_VERSION=2.3.3
ARG SCV_VERSION=2.0.1

SHELL ["/bin/bash", "-c"]
USER root:root

ENV SRC_DIR=/usr/src
ENV SYSTEMC_VERSION=${SYSTEMC_VERSION}
#ENV SYSTEMC_AMS_VERSION=2_0
#ENV SYSTEMC_CCI_VERSION=1_0_0
ENV SCV_VERSION=${SCV_VERSION}
#ENV SYSTEMC_SYNTHESIS_SUBSET_VERSION=1_4_7

ENV CC=gcc
ENV CXX=g++
ENV SYSTEMC_INSTALL_PATH=/opt/systemc-${SYSTEMC_VERSION}
ENV SCV_INSTALL_PATH=/opt/scv-${SCV_VERSION}
ENV CPLUS_INCLUDE_PATH=${CPLUS_INCLUDE_PATH}:${SYSTEMC_INSTALL_PATH}/include
ENV LIBRARY_PATH=${LIBRARY_PATH}:${SYSTEMC_INSTALL_PATH}/lib-linux64
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${SYSTEMC_INSTALL_PATH}/lib-linux64
ENV SYSTEMC_HOME=${SYSTEMC_INSTALL_PATH}

RUN apt update -qq \
    && apt install --no-install-recommends -qq -y \
    build-essential \
    cmake \
    g++ \
    wget \
    perl=5.* \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${SRC_DIR}
# Fetch and build SystemC core library (includes TLM).
WORKDIR ${SRC_DIR}
RUN wget https://www.accellera.org/images/downloads/standards/systemc/systemc-${SYSTEMC_VERSION}.tar.gz \
    && tar -xf ./systemc-${SYSTEMC_VERSION}.tar.gz \
    && rm -f ./systemc-${SYSTEMC_VERSION}.tar.gz \
    && cd ./systemc-${SYSTEMC_VERSION} \
    && ./configure --prefix=${SYSTEMC_INSTALL_PATH} \
    && make \
    && make install \
    && make check \
    && rm -rf ${SRC_DIR}/*

# Fetch and build SystemC regression tests.
WORKDIR ${SRC_DIR}
RUN wget https://www.accellera.org/images/downloads/standards/systemc/systemc-regressions-${SYSTEMC_VERSION}.tar.gz \
    && tar -xf ./systemc-regressions-${SYSTEMC_VERSION}.tar.gz \
    && cd ./systemc-regressions-${SYSTEMC_VERSION}/tests \
    && ../scripts/verify.pl * \
    && rm -rf ${SRC_DIR}/*

# Fetch and build SystemC verification library.
WORKDIR ${SRC_DIR}
RUN wget https://www.accellera.org/images/downloads/standards/systemc/scv-${SCV_VERSION}.tar.gz \
    && tar -xf ./scv-${SCV_VERSION}.tar.gz \
    && cd ./scv-${SCV_VERSION} \
    && ./configure --prefix=${SCV_INSTALL_PATH} --with-systemc=${SYSTEMC_INSTALL_PATH} \
    && make \
    && make install \
    && make check \
    && rm -rf ${SRC_DIR}/*

WORKDIR ${SYSTEMC_HOME}

# all the formal related things
RUN apt-get update
RUN apt-get install -y xdot pkg-config python libftdi-dev gperf
RUN apt-get install -y libboost-program-options-dev autoconf libgmp-dev
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Minsk
RUN apt-get install -y  clang bison flex libreadline-dev gawk tcl-dev libffi-dev graphviz cmake

# YOSYS
RUN git clone https://github.com/YosysHQ/yosys.git yosys
RUN cd yosys
WORKDIR yosys
RUN make -j4
RUN make install
RUN cd ..

# SymbiYosys
RUN git clone https://github.com/YosysHQ/SymbiYosys.git SymbiYosys
RUN cd SymbiYosys
WORKDIR SymbiYosys
RUN   make install
RUN cd ..

# yices2
RUN git clone https://github.com/SRI-CSL/yices2.git yices2
RUN cd yices2
WORKDIR yices2
RUN autoconf
RUN ./configure
RUN make -j4
RUN   make install
RUN cd ..

# Z3
RUN git clone https://github.com/Z3Prover/z3.git z3
RUN cd z3
WORKDIR z3
RUN python scripts/mk_make.py
RUN cd build
WORKDIR build
RUN make -j4
RUN make install
RUN cd ../..

# Avy
WORKDIR /
RUN git clone https://bitbucket.org/arieg/extavy.git
RUN cd extavy
WORKDIR extavy
RUN git submodule update --init
RUN mkdir build
RUN cd build
WORKDIR build
RUN cmake -DCMAKE_BUILD_TYPE=Release ..
RUN make -j4
RUN   cp avy/src/{avy,avybmc} /usr/local/bin/
RUN cd ../..

# #boolector
# RUN git clone https://github.com/boolector/boolector
# RUN cd boolector
# WORKDIR boolector
# RUN ./contrib/setup-btor2tools.sh
# RUN ./contrib/setup-lingeling.sh
# RUN ./configure.sh
# RUN make -C build -j4
# RUN   cp build/bin/{boolector,btor*} /usr/local/bin/
# RUN   cp deps/btor2tools/bin/btorsim /usr/local/bin/
# RUN cd ..
