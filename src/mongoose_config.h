#ifndef MONGOOSE_CONFIG_H
#define MONGOOSE_CONFIG_H

/*
* LINUX/GCC:
* Enable GNU/POSIX extensions BEFORE including any system headers.
*/
#if !defined(_WIN32) && !defined(_WIN64)
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

/*
* Standard C headers required by Mongoose.
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
* Platform-specific headers for the native socket stack.
*/
#if defined(_WIN32) || defined(_WIN64)
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <io.h>
#include <direct.h>
#else
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

/*
* Set to 0 for desktop OS environments to use the native socket stack.
*/
#define MG_ENABLE_TCPIP 0

/*
* For plaintext HTTP connections, MG_IO_SIZE can be reduced to 512 bytes.
*/
#define MG_IO_SIZE 8192

#define MG_ENABLE_POSIX_FS 1

/* 
* Enable directory listing
*/
#define MG_ENABLE_DIRLIST 0

#endif /* MONGOOSE_CONFIG_H */
