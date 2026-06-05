cmake_minimum_required(VERSION 3.10)

project(growtopia-mongoose
  VERSION 1.0.0
  LANGUAGES C
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_executable(http-server
  src/main.c
  lib/mongoose/mongoose.c
)

include_directories(
  lib/mongoose
)
