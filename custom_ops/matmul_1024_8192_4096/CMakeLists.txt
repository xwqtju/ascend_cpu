# MatMul M=1024 K=8192 N=4096
cmake_minimum_required(VERSION 3.16)

find_package(ASC REQUIRED HINTS $ENV{ASCEND_INSTALL_PATH}/compiler/tikcpp/ascendc_kernel_cmake)

project(kernel_samples LANGUAGES ASC CXX)

add_executable(matmul_1024_8192_4096
    matmul.asc
)

target_link_libraries(matmul_1024_8192_4096 PRIVATE
    tiling_api
    register
    platform
    m
    dl
)

target_compile_options(matmul_1024_8192_4096 PRIVATE
    $<$<COMPILE_LANGUAGE:ASC>:--npu-arch=dav-2201>
)
