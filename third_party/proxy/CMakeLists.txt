cmake_minimum_required(VERSION 3.16)

project(proxy VERSION 1.0
  DESCRIPTION "A simple proxy server"
  LANGUAGES C
)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(APP_NAME "proxy-server")

add_executable(${APP_NAME}
  src/proxy.c
  src/hello.c
)

target_include_directories(${APP_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)
