#ifndef MONGOOSE_CONFIG_H
#define MONGOOSE_CONFIG_H

/*
 * Standard C headers required by Mongoose when using MG_ARCH_CUSTOM.
 */
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/*
 * Platform-specific headers and compatibility macros
 */
#if defined(_WIN32) || defined(_WIN64)
  #include <winsock2.h>
  #include <ws2tcpip.h>
  #include <windows.h>
  #include <io.h>
  #include <direct.h>

  #if defined(_MSC_VER)
    #include <malloc.h>
    #ifndef alloca
      #define alloca(size) _alloca(size)
    #endif
  #endif
  
  #define mkdir(path, mode) _mkdir(path)
  
  #define MG_CUSTOM_NONBLOCK(fd) do { \
    unsigned long non_blocking = 1; \
    ioctlsocket(fd, FIONBIO, &non_blocking); \
  } while(0)

#else
  /* POSIX / Linux / macOS */
  #ifndef _GNU_SOURCE
    #define _GNU_SOURCE
  #endif
  #include <alloca.h>
  #include <unistd.h>
  #include <sys/types.h>
  #include <sys/stat.h>
  #include <sys/socket.h>
  #include <sys/time.h>
  #include <sys/select.h>
  #include <sys/ioctl.h>
  #include <netinet/in.h>
  #include <netinet/tcp.h>
  #include <arpa/inet.h>
  #include <netdb.h>
  #include <net/if.h>
  #include <dirent.h>
  #include <signal.h>
#endif

#define MG_ARCH MG_ARCH_CUSTOM

#ifdef _WIN32
  #define MG_ARCH MG_ARCH_WIN32
#endif

/*
 * Set to 0 for desktop OS environments to use the native socket stack.
 */
#define MG_ENABLE_TCPIP 0

/*
 * For plaintext HTTP connections, MG_IO_SIZE can be reduced to 512 bytes.
 */
#define MG_IO_SIZE 8192

/*
 * Centralized Feature Toggles
 */
#define MG_ENABLE_POSIX_FS 1

/* 
* Enable directory listing
*/
#define MG_ENABLE_DIRLIST 0

#endif /* MONGOOSE_CONFIG_H */
