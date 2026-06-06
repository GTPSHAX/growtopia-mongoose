cmake_minimum_required(VERSION 3.16)

project(growtopia-mongoose
  VERSION 1.0.0
  LANGUAGES C
)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(APP_NAME "http-server")

set(PROJECT_SOURCES
  src/main.c
  lib/mongoose/mongoose.c
)

add_executable(${APP_NAME} ${PROJECT_SOURCES})

target_include_directories(${APP_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/mongoose
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(MSVC)
  target_compile_options(${APP_NAME} PRIVATE /W4)
else()
  target_compile_options(${APP_NAME} PRIVATE -Wall -Wextra -Wpedantic)
  target_compile_options(${APP_NAME} PRIVATE -fno-tree-loop-distribute-patterns)
endif()

if(WIN32)
  target_link_libraries(${APP_NAME} PRIVATE ws2_32 crypt32)
else()
  find_package(Threads REQUIRED)
  target_compile_definitions(${APP_NAME} PRIVATE _GNU_SOURCE)
  target_link_libraries(${APP_NAME} PRIVATE
    Threads::Threads
    m
    ${CMAKE_DL_LIBS}
  )
endif()
