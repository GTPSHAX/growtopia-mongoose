cmake_minimum_required(VERSION 3.16)

project(growtopia-mongoose
  VERSION 1.0.0
  LANGUAGES C
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

option(USE_OPENSSL "Use OpenSSL TLS backend" OFF)

add_executable(${PROJECT_NAME}
  src/main.c
  lib/mongoose/mongoose.c
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/mongoose
)

if(MSVC)
  target_compile_options(${PROJECT_NAME} PRIVATE /W4)
else()
  target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(USE_OPENSSL)
  find_package(OpenSSL REQUIRED)
  target_compile_definitions(${PROJECT_NAME} PRIVATE MG_TLS=MG_TLS_OPENSSL)
  target_link_libraries(${PROJECT_NAME} PRIVATE OpenSSL::SSL OpenSSL::Crypto)
else()
  target_compile_definitions(${PROJECT_NAME} PRIVATE MG_TLS=MG_TLS_BUILTIN)
endif()

if(WIN32)
  target_link_libraries(${PROJECT_NAME} PRIVATE ws2_32 crypt32)
else()
  find_package(Threads REQUIRED)
  target_compile_definitions(${PROJECT_NAME} PRIVATE _GNU_SOURCE)
  target_link_libraries(${PROJECT_NAME} PRIVATE Threads::Threads m ${CMAKE_DL_LIBS})
endif()
