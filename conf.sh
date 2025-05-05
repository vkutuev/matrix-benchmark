# Benchmark configuration
# -----------------------
ENABLE_OPENBLAS=1
ENABLE_CLBLAST=1
ENABLE_BRAHMA=1

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
OUT_CLBLAST=clblast.csv

# OpenBLAS configuration
# ----------------------
OUT_OPENBLAS=openblas.csv

# ImageProcessing configuration
# -----------------------------
OUT_BRAHMA=brahma.csv
IMGPROC_WGS=64
IMGPROC_WPT=4
IMGPROC_DEV=anygpu
