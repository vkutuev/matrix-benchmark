# Benchmark configuration
# -----------------------
ENABLE_OPENBLAS=1
BUILD_OPENBLAS=1
ENABLE_CLBLAST=1
BUILD_CLBLAST=1
ENABLE_BRAHMA=1
BUILD_BRAHMA=1

INSTALL_DEPS=0

MATRICES_SIZES=(512 1024 1536 2048 2560 3072 3584 4096 4608 5120 5632 6144 6656 7168 7680 8192)
RUNS_NUMBER=10

# POCL configuration
# ------------------
BUILD_POCL=0
LLVM_VERSION=18

# CLBlast configuration
# ---------------------
OPENCL_PLATFORM=(0 1)
OPENCL_DEVICE=0

# OpenBLAS configuration
# ----------------------
OUT_OPENBLAS=openblas.csv

# ImageProcessing configuration
# -----------------------------
BRAHMA_AUTOTUNE=1
BRAHMA_WGS_DEFAULT=8
BRAHMA_WPT_DEFAULT=4
BRAHMA_DEV=("anygpu" "poclcpu")
BRAHMA_KERNEL=("k3" "k4")
BRAHMA_TYPE="mt-float32"
export BRAHMA_OCL_PATH=/usr/lib/libOpenCL.so.1.0.0
