# Benchmark configuration
# -----------------------
ENABLE_OPENBLAS=1
BUILD_OPENBLAS=1
ENABLE_CLBLAST=1
BUILD_CLBLAST=1
ENABLE_BRAHMA=1
BUILD_BRAHMA=1

INSTALL_DEPS=0

MATRICES_SIZES=(512 1024 2048 4096 8192)
RUNS_NUMBER=2

# POCL configuration
# ------------------
BUILD_POCL=1
LLVM_VERSION=18

# OpenCL configuration
# --------------------
OPENCL_PLATFORM=0
OPENCL_DEVICE=0

# CLBlast configuration
# ---------------------
OUT_CLBLAST=clblast_${OPENCL_PLATFORM}_${OPENCL_DEVICE}.csv

# OpenBLAS configuration
# ----------------------
OUT_OPENBLAS=openblas.csv

# ImageProcessing configuration
# -----------------------------
BRAHMA_WGS=8
BRAHMA_WPT=4
BRAHMA_DEV=anygpu
BRAHMA_KERNEL=k4
OUT_BRAHMA="brahma_${BRAHMA_KERNEL}_${BRAHMA_DEV}.csv"
export BRAHMA_OCL_PATH=/usr/lib/libOpenCL.so.1.0.0
