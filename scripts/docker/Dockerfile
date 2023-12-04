FROM ubuntu:20.04 as builder

ENV BUILD_DIR="/appbuild"
RUN mkdir -p ${BUILD_DIR}

# Install essential packages
ENV DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
      autoconf \
      automake \
      bison \
      build-essential \
      clang-11 \
      cmake \
      flex \
      git \
      libclang-11-dev \
      libgmp-dev \
      libtool \
      lld-11 \
      llvm-11-dev \
      llvm-11-tools \
      ninja-build \
      pkg-config \
      tzdata \
      texinfo \
      ca-certificates; \
      rm -rf /var/lib/apt/lists/*

# Set clang 11 tools
RUN update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-11 100; \
    update-alternatives --install /usr/bin/FileCheck FileCheck /usr/bin/FileCheck-11 100; \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-11 100; \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-11 100

# Clone and build polygeist
WORKDIR ${BUILD_DIR}
RUN git clone --single-branch -b main https://github.com/llvm/Polygeist.git polygeist; \
    cd polygeist; \
    git checkout 6ba6b7b8ac07c9d60994eb46b46682a9f76ea34e; \
    git submodule init; \
    git submodule update; \
    mkdir llvm-project/build; \
    cd llvm-project/build; \
    cmake -G Ninja ../llvm \
      -DLLVM_ENABLE_PROJECTS="mlir;clang" \
      -DLLVM_TARGETS_TO_BUILD="host"      \
      -DLLVM_PARALLEL_LINK_JOBS=2         \
      -DLLVM_INCLUDE_BENCHMARKS=OFF       \
      -DLLVM_INCLUDE_EXAMPLES=OFF         \
      -DLLVM_ENABLE_ASSERTIONS=ON         \
      -DLLVM_USE_LINKER=lld               \
      -DCMAKE_C_COMPILER=clang            \
      -DCMAKE_CXX_COMPILER=clang++        \
      -DCMAKE_BUILD_TYPE=Release; \
    ninja; \
    mkdir ../install; \
    cmake --install . --prefix ../install; \
    cd ../../; \
    mkdir build; \
    cd build; \
    cmake -G Ninja .. \
      -DMLIR_DIR=$PWD/../llvm-project/build/lib/cmake/mlir \
      -DCLANG_DIR=$PWD/../llvm-project/build/lib/cmake/clang \
      -DLLVM_TARGETS_TO_BUILD="host" \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_USE_LINKER=lld \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_BUILD_TYPE=Release; \
    ninja

# Clone and build polymer
WORKDIR ${BUILD_DIR}
RUN git clone --single-branch -b main https://github.com/kumasento/polymer.git polymer; \
    cd polymer; \
    git checkout 4bb0aa2ff43f70bb3f13f221ebcf9f76fb41fa76; \
    git submodule init; \
    git submodule update --recursive --init; \
    export POLYGEIST="${BUILD_DIR}/polygeist"; \
    mkdir build; \
    cd build; \
    cmake -G Ninja .. \
      -DMLIR_DIR="${POLYGEIST}/llvm-project/build/lib/cmake/mlir" \
      -DLLVM_DIR="${POLYGEIST}/llvm-project/build/lib/cmake/llvm" \
      -DLLVM_EXTERNAL_LIT="${POLYGEIST}/llvm-project/build/bin/llvm-lit" \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_USE_LINKER=lld \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_BUILD_TYPE=Release; \
    ninja

# Copy llvm-packing
COPY llvm-packing-v0.5/ ${BUILD_DIR}/llvm-packing/

# Build llvm-packing
WORKDIR ${BUILD_DIR}/llvm-packing
RUN mkdir build; \
    cd build; \
    cmake -DLLVM_ENABLE_PROJECTS="mlir"    \
      -DLLVM_TARGETS_TO_BUILD="host"       \
      -DLLVM_PARALLEL_LINK_JOBS=2          \
      -DLLVM_INCLUDE_BENCHMARKS=OFF        \
      -DLLVM_INCLUDE_EXAMPLES=OFF          \
      -DLLVM_ENABLE_ASSERTIONS=ON          \
      -DLLVM_USE_LINKER=lld                \
      -DBUILD_SHARED_LIBS=ON               \
      -DCMAKE_C_COMPILER=clang             \
      -DCMAKE_CXX_COMPILER=clang++         \
      -DCMAKE_BUILD_TYPE=Release           \
      -G Ninja ../llvm; \
    ninja; \
    mkdir ${BUILD_DIR}/llvm-packing-install; \
    cmake --install . --prefix ${BUILD_DIR}/llvm-packing-install

WORKDIR ${BUILD_DIR}
RUN git clone --depth 1 --branch binutils-2_39 https://sourceware.org/git/binutils-gdb.git binutils; \
    cd binutils; \
    mkdir build; \
    cd build; \
    ../configure --enable-gold --enable-plugins --disable-werror; \
    make all-gold

WORKDIR ${BUILD_DIR}
RUN git clone https://github.com/llvm/llvm-project.git llvm-project; \
    cd llvm-project; \
    git checkout llvmorg-14.0.1; \
    mkdir build; \
    cd build; \
    cmake -DLLVM_ENABLE_PROJECTS="clang;polly"            \
          -DLLVM_TARGETS_TO_BUILD="host"                  \
          -DLLVM_PARALLEL_LINK_JOBS=2                     \
          -DLLVM_INCLUDE_BENCHMARKS=OFF                   \
          -DLLVM_INCLUDE_EXAMPLES=OFF                     \
          -DLLVM_ENABLE_ASSERTIONS=ON                     \
          -DLLVM_USE_LINKER=lld                           \
          -DLLVM_BINUTILS_INCDIR=${BUILD_DIR}/binutils/include \
          -DBUILD_SHARED_LIBS=ON                          \
          -DCMAKE_C_COMPILER=clang                        \
          -DCMAKE_CXX_COMPILER=clang++                    \
          -DCMAKE_BUILD_TYPE=Release                      \
          -G Ninja ../llvm; \
    ninja; \
    mkdir ${BUILD_DIR}/llvm-14; \
    cmake --install . --prefix ${BUILD_DIR}/llvm-14

WORKDIR ${BUILD_DIR}
RUN git clone https://github.com/google/benchmark.git benchmark; \
    cd benchmark; \
    git checkout v1.6.1; \
    cmake -E make_directory "build"; \
    cmake -E chdir "build" cmake -DBENCHMARK_DOWNLOAD_DEPENDENCIES=on -DCMAKE_BUILD_TYPE=Release ../; \
    cmake --build "build" --config Release; \
    mkdir ${BUILD_DIR}/benchmark-install; \
    cmake --install build --config Release --prefix ${BUILD_DIR}/benchmark-install

FROM ubuntu:20.04 as test

ENV BUILD_DIR="/appbuild"

# Install essential packages and install vim sensible
ENV DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
      build-essential vim git nano python3 wget ca-certificates \
      linux-tools-common linux-tools-generic linux-tools-`uname -r` \
      python3-pip ed; \
    rm -rf /var/lib/apt/lists/*; \
    pip install numpy==1.22.4 matplotlib==3.5.2 scipy==1.7.0; \
    mkdir -p ~/.vim/pack/tpope/start; \
    cd ~/.vim/pack/tpope/start; \
    git clone https://tpope.io/vim/sensible.git

# Create and switch to non-root user and group
ARG user=packing
ARG group=packing
ARG uid=1000
ARG gid=1000
ENV HOME="/home/${user}"
RUN groupadd --gid ${gid} ${group}; \
    useradd --uid ${uid} -g ${group} --no-log-init -s /bin/bash -m ${user}; \
    mkdir ${HOME}/bin; \
    mkdir ${HOME}/install; \
    mkdir ${HOME}/lib

# Copy required files from build docker
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/polygeist/llvm-project/install/ ${HOME}/install/polygeist-llvm/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/polygeist/build/bin/ ${HOME}/bin/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/polymer/build/bin/ ${HOME}/bin/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/polymer/build/pluto/lib/ ${HOME}/lib/pluto/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/llvm-packing-install/ ${HOME}/install/llvm-packing/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/llvm-14/ ${HOME}/install/llvm-14/
COPY --chown=${user}:${group} --from=builder ${BUILD_DIR}/benchmark-install/ ${HOME}/install/google-benchmark/

# Copy scripts and polybench
COPY --chown=${user}:${group} packing-scripts/ ${HOME}/scripts/
COPY --chown=${user}:${group} polybench-c-4.2.1-plus-contract-3d/ ${HOME}/polybench/

USER ${uid}:${gid}

WORKDIR ${HOME}
CMD ["bash"]
