#ifndef MONGOOSE_CONFIG_H
#define MONGOOSE_CONFIG_H

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
