# Matrix multiplication benchmark

This benchmark measures the execution time of square matrix multiplication. The implementations taken for comparison are

* [OpenBLAS](https://github.com/OpenMathLib/OpenBLAS)
* [CLBlast](https://github.com/CNugteren/CLBlast)
* [Brahma.FSharp (ImageProcessing)](https://github.com/gsvgit/ImageProcessing/tree/matrix_multiplication)

## Configure Benchmark

One needs change values of variables in `conf.sh` file.

> [!WARNING]
> The most important option affecting the operability of Brahma.FSharp is `export BRAHMA_OCL_PATH=...`.
> Be sure to specify the correct path..

### General options

* `ENABLE_OPENBLAS=1` \
    Whether to run the OpenBLAS benchmark.
    * `0` — no
    * `1` — yes
* `BUILD_OPENBLAS=1` \
    Whether to build or rebuild the OpenBLAS benchmark.
    * `0` — no
    * `1` — yes
* `ENABLE_CLBLAST=1` \
    Whether to run the CLBlast benchmark.
    * `0` — no
    * `1` — yes
* `BUILD_CLBLAST=1` \
    Whether to build or rebuild the CLBlast benchmark.
    * `0` — no
    * `1` — yes
* `ENABLE_BRAHMA=1` \
    Whether to run the Brahma.FSharp benchmark.
    * `0` — no
    * `1` — yes
* `BUILD_BRAHMA=1` \
    Whether to build or rebuild the CLBlast benchmark.
    * `0` — no
    * `1` — yes
* `INSTALL_DEPS=1` \
    Whether to install some dependencies needed to build benchmarks.
    * `0` — no
    * `1` — yes
* `MATRICES_SIZES=(512 1024 2048 4096 8192)` \
    Matrix sizes (i.e. number of rows and cols of square matrix) on which benchmarks will be run. \
    Valid value is a bash array of integers.
* `RUNS_NUMBER=10` \
    Number of runs of each tool on each matrix size.

### POLC options

* `BUILD_POCL=0` \
    Whether to build and install [PoCL (Portable Computing Language)](https://portablecl.org/).
    * `0` — no
    * `1` — yes
* `LLVM_VERSION=18` \
    The version of LLVM used when building PoCL.

### CLBlast options

* `OPENCL_PLATFORM=(0 1)` \
    Numbers of OpenCL platforms on which CLBlast benchmarks will be run. \
    Valid value is a bash array of integers. Check `clinfo -l`
to find out the available platforms and devices.
* `OPENCL_DEVICE=0` \
    Number of OpenCL device on which CLBlast benchmarks will be run.

### Brahma.fsahrp (ImageProcessing) options

* `INSTALL_DOTNET=0` \
    Whether to install .NET (or just download in RISC-V case).
    * `0` — no
    * `1` — yes
* `BRAHMA_AUTOTUNE=1` \
    Whether to use autotuner to determine optimal WGS (work group size)
and WPT (work per thread) parameters for selected devices and kernels.
* `BRAHMA_WGS_DEFAULT=8` \
    Default WGS value
* `BRAHMA_WPT_DEFAULT=4` \
    Default WPT value
* `BRAHMA_DEV=("anygpu" "poclcpu")` \
    OpenCL devices on which Brahma.FSharp benchmarks will be run. \
    A valid value is a bash array of values from the following: `nvidia`, `intelgpu`, `anygpu`, `poclcpu`.
* `BRAHMA_KERNEL=("k3" "k4")` \
    Kernels (based on "[Tutorial: OpenCL SGEMM tuning for Kepler](https://cnugteren.github.io/tutorial/pages/page1.html)") on which Brahma.FSharp benchmarks will be run. \
    A valid value is a bash array of values from the following: `k0`, `k1`, `k2`, `k3`, `k4`.
* `export BRAHMA_OCL_PATH=/usr/lib/libOpenCL.so.1.0.0` \
    Path to OpenCL.

## Run benchmark

Once configured, the script must be run.

```bash
./benchmark.sh
```

 It will automatically download, build and run the selected tools. As a result of work in the root directory of the repository there will be CSV files containing the results of measurements.
