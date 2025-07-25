#!/bin/bash

set -ex

# Default workspace directory
WORKSPACE=$(pwd)/eep_kernels_workspace
INSTALL_NVSHMEM=true

# Parse command line arguments
while getopts "w:n" opt; do
  case $opt in
    w)
      WORKSPACE="$OPTARG"
      ;;
    n)
      INSTALL_NVSHMEM=false
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$WORKSPACE" ]; then
    mkdir -p $WORKSPACE
fi


# install dependencies if not installed
pip3 install cmake torch ninja

# build nvshmem
pushd $WORKSPACE
# Reset NVSHMEM build if requested
if [ "$INSTALL_NVSHMEM" = true ]; then
    mkdir -p nvshmem_src
    wget https://developer.download.nvidia.com/compute/redist/nvshmem/3.2.5/source/nvshmem_src_3.2.5-1.txz
    tar -xvf nvshmem_src_3.2.5-1.txz -C nvshmem_src --strip-components=1
    pushd nvshmem_src
    wget https://github.com/deepseek-ai/DeepEP/raw/main/third-party/nvshmem.patch
    git init
    git apply -vvv nvshmem.patch
    git apply --reject --whitespace=fix ../../eep_nvshmem.patch 
else
    pushd nvshmem_src
fi

# assume CUDA_HOME is set correctly
if [ -z "$CUDA_HOME" ]; then
    echo "CUDA_HOME is not set, please set it to your CUDA installation directory."
    exit 1
fi

# disable all features except IBGDA
export NVSHMEM_IBGDA_SUPPORT=1

export NVSHMEM_SHMEM_SUPPORT=0
export NVSHMEM_UCX_SUPPORT=0
export NVSHMEM_USE_NCCL=0
export NVSHMEM_PMIX_SUPPORT=0
export NVSHMEM_TIMEOUT_DEVICE_POLLING=0
export NVSHMEM_USE_GDRCOPY=0
export NVSHMEM_IBRC_SUPPORT=0
export NVSHMEM_BUILD_TESTS=0
export NVSHMEM_BUILD_EXAMPLES=0
export NVSHMEM_MPI_SUPPORT=0
export NVSHMEM_BUILD_HYDRA_LAUNCHER=0
export NVSHMEM_BUILD_TXZ_PACKAGE=0
export NVSHMEM_TIMEOUT_DEVICE_POLLING=0

cmake -G Ninja -S . -B $WORKSPACE/nvshmem_build/ -DCMAKE_INSTALL_PREFIX=$WORKSPACE/nvshmem_install
cmake --build $WORKSPACE/nvshmem_build/ --target install

popd

export CMAKE_PREFIX_PATH=$WORKSPACE/nvshmem_install:$CMAKE_PREFIX_PATH

# build and install pplx, require pytorch installed
pushd $WORKSPACE
git clone https://github.com/ppl-ai/pplx-kernels
cd pplx-kernels
# see https://github.com/pypa/pip/issues/9955#issuecomment-838065925
# PIP_NO_BUILD_ISOLATION=0 disables build isolation
PIP_NO_BUILD_ISOLATION=0 TORCH_CUDA_ARCH_LIST=9.0a+PTX pip install . --no-deps -v

