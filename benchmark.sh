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

	echo "Install deps"
	echo "--------------"
	sudo apt install python3-dev build-essential \
		cmake git pkg-config make ninja-build
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
		"x86_64") POCL_CMAKE_FLAGS=("-DKERNELLIB_HOST_CPU_VARIANTS=distro")
			;;
		"riscv64") POCL_CMAKE_FLAGS=("-DLLC_HOST_CPU=spacemit-x60" "-DHOST_CPU_TARGET_ABI=lp64d")
			;;
		"aarch64") POCL_CMAKE_FLAGS=("-DLLC_HOST_CPU=cortex-a55")
			;;
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
		"${POCL_CMAKE_FLAGS[@]}" \
		&& cmake --build "$B" \
		&& sudo cmake --build "$B" --target install
fi

if [[ "$ENABLE_OPENBLAS" != 0 ]]; then
	S="$R/OpenBLAS"
	B="$S/build"
	if [[ "$BUILD_OPENBLAS" != 0 ]]; then
		echo "Build OpenBLAS"
		echo "--------------"
		cmake -S "$S" -B "$B" \
			-DCMAKE_BUILD_TYPE=Release -G Ninja \
			-DBUILD_BENCHMARKS=ON -DBUILD_SHARED_LIBS=ON \
			&& cmake --build "$B"
	fi

	echo "Run OpenBLAS benchmark"
	echo "----------------------"
	echo "matrix,time" > "${R}/${OUT_OPENBLAS}"
	for i in ${!MATRICES_SIZES[*]}; do
		N=${MATRICES_SIZES[$i]}
		printf '\rProcess matrix: %d  [%d/%d]' "$N" "$(( i + 1 ))" "${#MATRICES_SIZES[*]}"
		OPENBLAS_LOOPS="$RUNS_NUMBER" "$B/benchmark_gemm" "$N" "$N" 2>&1 \
			| sed '1,2d' \
			| awk -v MATRIX="$N" -v RUNS="$RUNS_NUMBER" \
				'BEGIN{ OFS="," } { print MATRIX, 1000 * $7 / RUNS }' >> "${R}/${OUT_OPENBLAS}"
	done
	echo ""
fi

run_clblast() {
	PLATFORM="$1"
	S="$R/CLBlast"
	B="$S/build"
	echo "Run CLBlast benckmark for ${PLATFORM} platform"
	echo "------------------------------------"
	clinfo -d "${PLATFORM}:${OPENCL_DEVICE}" -l
	OUT_CLBLAST="${R}/clblast_${PLATFORM}_${OPENCL_DEVICE}.csv"
	echo "matrix,time" > "$OUT_CLBLAST"
	for i in ${!MATRICES_SIZES[*]}; do
		N=${MATRICES_SIZES[$i]}
		printf '\rProcess matrix: %d  [%d/%d]' "$N" "$(( i + 1 ))" "${#MATRICES_SIZES[*]}"
		"$B/clblast_client_xgemm" \
			-platform "$PLATFORM" -device "$OPENCL_DEVICE" \
			-precision 32 -runs "$RUNS_NUMBER" -warm_up -q -no_abbrv \
			-clblas 0 -cblas 0 -cublas 0 \
			-m "$N" -n "$N" -k "$N" \
			-layout 101 -transA 111 -transB 111 \
			-step 0 -num_steps 1 \
			| cut -f 15 -d ';' | sed '1d' | tr -d '[:space:]' \
			| awk -v MATRIX="$N" 'BEGIN{ OFS="," } { print MATRIX, $1 }' >> "$OUT_CLBLAST"
	done
	echo ""
}

if [[ "$ENABLE_CLBLAST" != 0 ]]; then
	S="$R/CLBlast"
	B="$S/build"
	if [[ "$BUILD_CLBLAST" != 0 ]]; then
		echo "Build CLBlast"
		echo "-------------"
		cmake -S "$S" -B "$B" \
			-DCMAKE_BUILD_TYPE=Release -G Ninja \
			-DCLIENTS=ON \
			&& cmake --build "$B"
	fi
	for platform in "${OPENCL_PLATFORM[@]}"; do
		run_clblast "$platform"
	done
fi

run_brahma() {
	KERNEL="$1"
	DEV="$2"
	pushd "$R/ImageProcessing" || exit 1
	echo "Run Brahma benckmark with kernel ${KERNEL} and device ${DEV}"
	echo "-----------------------------------------------------"
	if [[ "$BRAHMA_AUTOTUNE" != 0 ]]; then
		echo "Run tune.py for ${KERNEL} and device ${DEV}"
		echo "------------------------------------"
		sed -i "s/kernels = \[.*\]/kernels = [\'${KERNEL}\']/g" ./tune.py
		sed -i "s/platform = '.*'/platform = '${DEV}'/g" ./tune.py
		sed -i "s/types = \[.*\]/types = [\'${BRAHMA_TYPE}\']/g" ./tune.py
		python3 ./tune.py
		WGS=$(head -n 1 "./tuning_results/${KERNEL}_${DEV}_mt-float32_1024_arithmetic.log" \
			| cut -f 1 -d ',')
		WPT=$(head -n 1 "./tuning_results/${KERNEL}_${DEV}_mt-float32_1024_arithmetic.log" \
			| cut -f 2 -d ',' | tr -d '[:space:]')
	else
		WGS="$BRAHMA_WGS_DEFAULT"
		WPT="$BRAHMA_WPT_DEFAULT"
	fi
	OUT_BRAHMA="${R}/brahma_${KERNEL}_${DEV}_${WGS}_${WPT}.csv"
	echo "matrix,time" > "${OUT_BRAHMA}"
	for i in ${!MATRICES_SIZES[*]}; do
		N=${MATRICES_SIZES[$i]}
		printf '\rProcess matrix: %d  [%d/%d]' "$N" "$(( i + 1 ))" "${#MATRICES_SIZES[*]}"
		dotnet ./src/MatrixMultiplication/bin/Release/net9.0/MatrixMultiplication.dll \
			--platform "$DEV" \
			--workgroupsize "$WGS" \
			--workperthread "$WPT" \
			--matrixsize "$N" \
			--kernel "$KERNEL" \
			--matrixtype mt-float32 \
			--semiring arithmetic \
			--numtorun "$RUNS_NUMBER" \
			| sed '1d' \
			| cut -f 3 -d ' ' \
			| awk -v MATRIX="$N" -v RUNS="$RUNS_NUMBER" \
			'	BEGIN{ OFS="," } { print MATRIX, $1 / RUNS }' >> "$OUT_BRAHMA"
	done
	echo ""
	popd || exit 1
}

if [[ "$ENABLE_BRAHMA" != 0 ]]; then
	pushd "$R/ImageProcessing" || exit 1
	if [[ "$BUILD_BRAHMA" != 0 ]]; then
		echo "Build ImageProcessing project"
		echo "-----------------------------"
		dotnet build -c Release
	fi
	popd || exit 1
	for kernel in "${BRAHMA_KERNEL[@]}"; do
		for dev in "${BRAHMA_DEV[@]}"; do
			run_brahma "$kernel" "$dev"
		done
	done
fi

popd || exit 1

echo "Finish"
echo "------"
