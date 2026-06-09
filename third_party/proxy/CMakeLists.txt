cmake_minimum_required(VERSION 3.16)

project(proxy VERSION 1.0
  LANGUAGES C
)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(APP_NAME "proxy-server")

if(WIN32)
  set(MICROHTTPD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../lib/libmicrohttpd-1.0.1-w32-bin")
  
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(MH_ARCH "x86_64")
  else()
    set(MH_ARCH "x86")
  endif()

  if(MSVC)
    set(MH_VS_VERSION "VS2022")
    set(MH_LINK_TYPE "dll") 

    if(MH_LINK_TYPE STREQUAL "dll")
      set(MH_INCLUDE_DIR "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Release-dll")
      set(MH_LIB_DEBUG   "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Debug-dll/libmicrohttpd-dll_d.lib")
      set(MH_LIB_RELEASE "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Release-dll/libmicrohttpd-dll.lib")
      set(MH_DLL_DEBUG   "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Debug-dll/libmicrohttpd-dll_d.dll")
      set(MH_DLL_RELEASE "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Release-dll/libmicrohttpd-dll.dll")
    else()
      set(MH_INCLUDE_DIR "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Release-static")
      set(MH_LIB_DEBUG   "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Debug-static/libmicrohttpd_d.lib")
      set(MH_LIB_RELEASE "${MICROHTTPD_ROOT}/${MH_ARCH}/${MH_VS_VERSION}/Release-static/libmicrohttpd.lib")
    endif()

  elseif(MINGW)
    set(MH_MINGW_ENV "mingw64")
    set(MH_LINK_TYPE "dll")

    set(MH_INCLUDE_DIR "${MICROHTTPD_ROOT}/${MH_ARCH}/MinGW/shared/${MH_MINGW_ENV}/include")
    set(MH_LIB_DEBUG   "${MICROHTTPD_ROOT}/${MH_ARCH}/MinGW/shared/${MH_MINGW_ENV}/lib/libmicrohttpd.dll.a")
    set(MH_LIB_RELEASE "${MICROHTTPD_ROOT}/${MH_ARCH}/MinGW/shared/${MH_MINGW_ENV}/lib/libmicrohttpd.dll.a")
    set(MH_DLL_DEBUG   "${MICROHTTPD_ROOT}/${MH_ARCH}/MinGW/shared/${MH_MINGW_ENV}/bin/libmicrohttpd-12.dll")
    set(MH_DLL_RELEASE "${MICROHTTPD_ROOT}/${MH_ARCH}/MinGW/shared/${MH_MINGW_ENV}/bin/libmicrohttpd-12.dll")
  endif()

  if(MH_LINK_TYPE STREQUAL "static")
    add_library(microhttpd STATIC IMPORTED)
    set_target_properties(microhttpd PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${MH_INCLUDE_DIR}"
      IMPORTED_LOCATION_DEBUG "${MH_LIB_DEBUG}"
      IMPORTED_LOCATION_RELEASE "${MH_LIB_RELEASE}"
      INTERFACE_LINK_LIBRARIES "ws2_32"
    )
  else()
    add_library(microhttpd SHARED IMPORTED)
    set_target_properties(microhttpd PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${MH_INCLUDE_DIR}"
      IMPORTED_IMPLIB_DEBUG "${MH_LIB_DEBUG}"
      IMPORTED_IMPLIB_RELEASE "${MH_LIB_RELEASE}"
      IMPORTED_LOCATION_DEBUG "${MH_DLL_DEBUG}"
      IMPORTED_LOCATION_RELEASE "${MH_DLL_RELEASE}"
      INTERFACE_LINK_LIBRARIES "ws2_32"
    )
  endif()

else()
  find_package(PkgConfig REQUIRED)
  
  pkg_check_modules(MICROHTTPD REQUIRED IMPORTED_TARGET libmicrohttpd)

  add_library(microhttpd ALIAS PkgConfig::MICROHTTPD)
endif()

add_executable(${APP_NAME}
  src/main.c
)

target_precompile_headers(${APP_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include/proxy/pch.h
)

target_include_directories(${APP_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${APP_NAME} PRIVATE microhttpd)

if(WIN32 AND DEFINED MH_LINK_TYPE AND MH_LINK_TYPE STREQUAL "dll")
  add_custom_command(TARGET ${APP_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "$<TARGET_FILE:microhttpd>"
    "$<TARGET_FILE_DIR:${APP_NAME}>"
  )
endif()
