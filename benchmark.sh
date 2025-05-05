#!/bin/bash

R=$(realpath "$(dirname "$0")")

pushd "$R" || exit 1

echo "Fetch implementations"
echo "---------------------"
git submodule update --init

echo "Apply Configuration"
echo "-------------------"
source "$R/conf.sh"

if [[ "$INSTALL_DEPS" != 0 ]]; then
	echo "Update apt"
	echo "----------"
	sudo apt update

	# echo "Install OpenBLAS deps"
	# echo "---------------------"

	echo "Install dotnet"
	echo "--------------"
	sudo apt install -y dotnet-sdk-9.0
fi

if [[ "$BUILD_POCL" != 0 ]]; then
	echo "Install POCL deps"
	echo "-----------------"
	sudo apt install -y \
		python3-dev libpython3-dev build-essential \
		ocl-icd-libopencl1 cmake git pkg-config \
		libclang-${LLVM_VERSION}-dev clang-${LLVM_VERSION} \
		llvm-${LLVM_VERSION} make ninja-build ocl-icd-libopencl1 \
		ocl-icd-dev ocl-icd-opencl-dev libhwloc-dev \
		zlib1g zlib1g-dev clinfo dialog apt-utils libxml2-dev \
		libclang-cpp${LLVM_VERSION}-dev libclang-cpp${LLVM_VERSION} \
		llvm-${LLVM_VERSION}-dev

	echo "Build and install POCL"
	echo "----------------------"
	ARCH=$(uname -m)
	POCL_CMAKE_FLAGS=""
	case "$ARCH" in
		"x86_64") POCL_CMAKE_FLAGS="-DKERNELLIB_HOST_CPU_VARIANTS=distro"
			;;
		"riscv64") POCL_CMAKE_FLAGS="-DLLC_HOST_CPU=spacemit-x60 -DHOST_CPU_TARGET_ABI=lp64d"
			;;
		"aarch64") POCL_CMAKE_FLAGS="-DLLC_HOST_CPU=cortex-a55"
			;;
			# TODO add arm
		*) echo "Unknown arch" && exit 1
			;;
	esac

	S="$R/pocl"
	B="$S/build"
	cmake -S "$S" -B "$B" \
		-DWITH_LLVM_CONFIG=/usr/bin/llvm-config-${LLVM_VERSION} \
		-DCMAKE_C_COMPILER=clang-${LLVM_VERSION} \
		-DCMAKE_CXX_COMPILER=clang++-${LLVM_VERSION} \
		-DCMAKE_BUILD_TYPE=Release -G Ninja \
		-DCMAKE_INSTALL_PREFIX=/opt/pocl \
		-DCMAKE_INSTALL_LIBDIR=lib \
		-DINSTALL_OPENCL_HEADERS=OFF \
		"$POCL_CMAKE_FLAGS" \
		&& cmake --build "$B" \
		&& sudo cmake --build "$B" --target install
fi

if [[ "$ENABLE_OPENBLAS" != 0 ]]; then
	S="$R/OpenBLAS"
	B="$S/build"
	cmake -S "$S" -B "$B" \
		-DCMAKE_BUILD_TYPE=Release -G Ninja \
		-DBUILD_BENCHMARKS=ON -DBUILD_SHARED_LIBS=ON \
		&& cmake --build "$B"

	for N in "${MATRICES_SIZES[@]}"; do
		OPENBLAS_LOOPS="$RUNS_NUMBER" "$B/benchmark_gemm" "$N" "$N" 2>&1 \
			| sed '1,2d' \
			| awk -v RUNS="$RUNS_NUMBER" '{ print 1000 * $7 / RUNS }' >> "$R/$OUT_OPENBLAS"
	done
fi

if [[ "$ENABLE_CLBLAST" != 0 ]]; then
	echo "Install CLBlast deps"
	echo "--------------------"
	# TODO install clblast deps

	echo "Build CLBlast"
	echo "-------------"
	git clone https://github.com/CNugteren/CLBlast
	S="$R/CLBlast"
	B="$S/build"
	cmake -S "$S" -B "$B" \
		-DCMAKE_BUILD_TYPE=Release -G Ninja \
		-DCLIENTS=ON \
		&& cmake --build "$B"

	echo "Run CLBlast benckmark"
	echo "---------------------"
	for N in "${MATRICES_SIZES[@]}"; do
		"$B/clblast_client_xgemm" \
			-platform "$OPENCL_PLATFORM" -device "$OPENCL_DEVICE" \
			-precision 32 -runs 10 -warm_up -q -no_abbrv \
			-clblas 0 -cblas 0 -cublas 0 \
			-m "$N" -n "$N" -k "$N" \
			-layout 101 -transA 111 -transB 111 \
			-step 0 -num_steps 1 \
			| cut -f 15 -d ';' | sed '1d' | tr -d '[:space:]' >> "$R/$OUT_CLBLAST"
	done
fi

if [[ "$ENABLE_BRAHMA" != 0 ]]; then
	echo "Build ImageProcessing project"
	echo "-----------------------------"
	pushd "$R/ImageProcessing" || exit 1
	dotnet build -c Release
	pushd ./src/MatrixMultiplication/bin/Release/net9.0/ || exit 1
	for N in "${MATRICES_SIZES[@]}"; do
		IMGPROC_RESULTS=$(mktemp)
		for _ in $(seq 1 1 $RUNS_NUMBER); do
			dotnet MatrixMultiplication.dll \
				--platform "$IMGPROC_DEV" \
				--workgroupsize "$IMGPROC_WGS" \
				--workperthread "$IMGPROC_WPT" \
				--matrixsize "$N" \
				--kernel k4 \
				--matrixtype mt-float32 \
				--semiring arithmetic \
				| sed '1d' | cut -f 3 -d ' ' >> "$IMGPROC_RESULTS"
		done
		awk 'BEGIN { sum = 0 } { sum += $1 } END { print sum / NR }' "$IMGPROC_RESULTS" > "$R/$OUT_BRAHMA"
		rm "$IMGPROC_RESULTS"
	done
	popd || exit 1
	popd || exit 1
fi

popd || exit 1

echo "Finish"
echo "------"
