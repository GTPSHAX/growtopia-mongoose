#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <microhttpd.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#endif

struct RequestState
{
  char *body;
  size_t body_size;
  size_t body_capacity;
};

struct HeaderBuffer
{
  char *data;
  size_t size;
  size_t capacity;
};

struct HttpResponseParts
{
  int status_code;
  size_t header_len;
  size_t body_len;
  size_t content_length;
  int has_content_length;
};

static char *read_file_to_string(const char *filename, size_t *out_size)
{
  FILE *f = fopen(filename, "rb");
  if (!f)
  {
    return NULL;
  }
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  if (size < 0)
  {
    fclose(f);
    return NULL;
  }
  fseek(f, 0, SEEK_SET);

  char *buffer = malloc((size_t)size + 1);
  if (!buffer)
  {
    fclose(f);
    return NULL;
  }

  if (fread(buffer, 1, (size_t)size, f) != (size_t)size)
  {
    free(buffer);
    fclose(f);
    return NULL;
  }
  buffer[size] = '\0';
  fclose(f);

  if (out_size)
  {
    *out_size = (size_t)size;
  }
  return buffer;
}

static enum MHD_Result
header_iterator(void *cls, enum MHD_ValueKind kind, const char *key, const char *value)
{
  struct HeaderBuffer *hb = cls;
  if (strcasecmp(key, "Host") == 0 || strcasecmp(key, "Connection") == 0)
  {
    return MHD_YES;
  }

  char header_line[1024];
  int len = snprintf(header_line, sizeof(header_line), "%s: %s\r\n", key, value);
  if (hb->size + len + 1 > hb->capacity)
  {
    hb->capacity = (hb->size + len + 1) * 2;
    hb->data = realloc(hb->data, hb->capacity);
  }
  memcpy(hb->data + hb->size, header_line, len);
  hb->size += len;
  return MHD_YES;
}

static int
parse_http_response(const char *response, size_t response_size, struct HttpResponseParts *parts)
{
  const char *header_end = NULL;
  const char *line = NULL;
  const char *next = NULL;

  memset(parts, 0, sizeof(*parts));
  parts->status_code = 502;

  header_end = strstr(response, "\r\n\r\n");
  if (header_end == NULL) return 0;

  parts->header_len = (size_t) (header_end - response) + 4;
  parts->body_len = response_size - parts->header_len;

  if (sscanf(response, "HTTP/1.%*d %d", &parts->status_code) != 1) {
    parts->status_code = 502;
  }

  line = response;
  while (line < header_end) {
    next = strstr(line, "\r\n");
    if (next == NULL || next > header_end) break;

    if (next > line) {
      const char *colon = memchr(line, ':', (size_t) (next - line));
      if (colon != NULL) {
        size_t key_len = (size_t) (colon - line);
        const char *value = colon + 1;
        while (value < next && (*value == ' ' || *value == '\t')) value++;

        if (key_len == strlen("Content-Length") &&
            strncasecmp(line, "Content-Length", key_len) == 0) {
          char *end = NULL;
          unsigned long parsed = strtoul(value, &end, 10);
          if (end != value) {
            parts->content_length = (size_t) parsed;
            parts->has_content_length = 1;
          }
        }
      }
    }

    line = next + 2;
  }

  return 1;
}

static int
recv_all(int sock, char **buffer, size_t *capacity, size_t *size)
{
  ssize_t n;

  while ((n = recv(sock, *buffer + *size, *capacity - *size, 0)) > 0) {
    *size += (size_t) n;
    if (*size == *capacity) {
      size_t new_capacity = (*capacity) * 2;
      char *new_buffer = realloc(*buffer, new_capacity);
      if (new_buffer == NULL) return 0;
      *buffer = new_buffer;
      *capacity = new_capacity;
    }
  }

  return n >= 0;
}

static enum MHD_Result
access_handler(void *cls, struct MHD_Connection *connection,
               const char *url, const char *method,
               const char *version, const char *upload_data,
               size_t *upload_data_size, void **con_cls)
{

  struct RequestState *rs = *con_cls;

  if (rs == NULL)
  {
    rs = calloc(1, sizeof(struct RequestState));
    *con_cls = rs;
    return MHD_YES;
  }

  if (*upload_data_size > 0)
  {
    if (rs->body_size + *upload_data_size > rs->body_capacity)
    {
      rs->body_capacity = (rs->body_size + *upload_data_size) * 2;
      rs->body = realloc(rs->body, rs->body_capacity);
    }
    memcpy(rs->body + rs->body_size, upload_data, *upload_data_size);
    rs->body_size += *upload_data_size;
    *upload_data_size = 0; /* Acknowledge receipt */
    return MHD_YES;
  }

  /* Gather headers */
  struct HeaderBuffer hb = {0};
  MHD_get_connection_values(connection, MHD_HEADER_KIND, header_iterator, &hb);

  /* Build backend request line and headers */
  char *request_headers = malloc(8192);
  int req_len = snprintf(request_headers, 8192,
                         "%s %s HTTP/1.1\r\n"
                         "Host: %s\r\n"
                         "Connection: close\r\n"
                         "%s"
                         "\r\n",
                         method, url, BACKEND_HOST, hb.data ? hb.data : "");
  free(hb.data);

  /* Open socket to backend */
  int sock = socket(AF_INET, SOCK_STREAM, 0);
  if (sock < 0)
  {
    free(request_headers);
    return MHD_NO;
  }

  struct sockaddr_in server_addr;
  server_addr.sin_family = AF_INET;
  server_addr.sin_port = htons(BACKEND_PORT);
  inet_pton(AF_INET, BACKEND_HOST, &server_addr.sin_addr);

  if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
  {
    close(sock);
    free(request_headers);
    return MHD_NO;
  }

  /* Send headers */
  send(sock, request_headers, req_len, 0);
  free(request_headers);

  /* Send body if present */
  if (rs->body_size > 0)
  {
    send(sock, rs->body, rs->body_size, 0);
  }

  shutdown(sock, SHUT_WR);

  size_t resp_capacity = 8192;
  size_t total_recv = 0;
  char *response = malloc(resp_capacity);
  struct HttpResponseParts response_parts;

  if (response == NULL) {
    close(sock);
    free(rs->body);
    free(rs);
    *con_cls = NULL;
    return MHD_NO;
  }

  if (!recv_all(sock, &response, &resp_capacity, &total_recv)) {
    close(sock);
    free(response);
    free(rs->body);
    free(rs);
    *con_cls = NULL;
    return MHD_NO;
  }

  if (total_recv == resp_capacity) {
    char *new_response = realloc(response, resp_capacity + 1);
    if (new_response != NULL) {
      response = new_response;
      resp_capacity += 1;
    }
  }

  response[total_recv] = '\0';
  close(sock);

  if (parse_http_response(response, total_recv, &response_parts))
  {
    char *body = response + response_parts.header_len;
    size_t body_len = response_parts.body_len;
    int status_code = response_parts.status_code;

    if (response_parts.has_content_length && body_len < response_parts.content_length) {
      status_code = 502;
      body = (char *) "502 Bad Gateway: Incomplete upstream response";
      body_len = strlen(body);
    }

    struct MHD_Response *mhd_resp = MHD_create_response_from_buffer(body_len, body, MHD_RESPMEM_MUST_COPY);

    /* Parse and forward headers */
    char *headers = malloc(response_parts.header_len + 1);
    if (headers != NULL)
    {
      char *saveptr;
      char *line;

      memcpy(headers, response, response_parts.header_len);
      headers[response_parts.header_len] = '\0';

      line = strtok_r(headers, "\r\n", &saveptr);
      while (line)
      {
        char *colon = strchr(line, ':');
        if (colon)
        {
          *colon = '\0';
          char *key = line;
          char *value = colon + 1;

          while (*value == ' ' || *value == '\t') value++;

          if (*value != '\0') {
            char *end = value + strlen(value) - 1;
            while (end > value && (*end == '\r' || *end == '\n' || *end == ' ' || *end == '\t'))
            {
              *end = '\0';
              end--;
            }
          }

          if (strcasecmp(key, "Transfer-Encoding") != 0 && strcasecmp(key, "Connection") != 0)
          {
            MHD_add_response_header(mhd_resp, key, value);
          }
        }
        line = strtok_r(NULL, "\r\n", &saveptr);
      }

      free(headers);
    }

    MHD_queue_response(connection, status_code, mhd_resp);
    MHD_destroy_response(mhd_resp);
  }
  else
  {
    /* Fallback for malformed backend responses */
    const char *err_msg = "502 Bad Gateway: Malformed response";
    struct MHD_Response *mhd_resp = MHD_create_response_from_buffer(strlen(err_msg), (void *)err_msg, MHD_RESPMEM_PERSISTENT);
    MHD_queue_response(connection, 502, mhd_resp);
    MHD_destroy_response(mhd_resp);
  }

  free(response);
  free(rs->body);
  free(rs);
  *con_cls = NULL;

  return MHD_YES;
}

int main(int argc, char **argv)
{
#ifdef _WIN32
  WSADATA wsaData;
  if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0)
  {
    fprintf(stderr, "Winsock initialization failed.\n");
    return 1;
  }
#endif

  printf("Starting HTTPS Proxy Server on port %d...\n", PROXY_PORT);
  printf("Forwarding to HTTP backend at %s:%d\n", BACKEND_HOST, BACKEND_PORT);

  /* Load TLS credentials into memory */
  size_t cert_size, key_size;
  char *cert_data = read_file_to_string(CERT_FILE, &cert_size);
  char *key_data = read_file_to_string(KEY_FILE, &key_size);

  if (!cert_data || !key_data)
  {
    fprintf(stderr, "Failed to load %s or %s.\n", CERT_FILE, KEY_FILE);
    fprintf(stderr, "Please run your certificate generation script first.\n");
    free(cert_data);
    free(key_data);
#ifdef _WIN32
    WSACleanup();
#endif
    return 1;
  }

  struct MHD_Daemon *daemon = MHD_start_daemon(
      MHD_USE_TLS | MHD_USE_SELECT_INTERNALLY,
      PROXY_PORT,
      NULL, NULL,
      &access_handler, NULL,
      MHD_OPTION_HTTPS_MEM_CERT, cert_data,
      MHD_OPTION_HTTPS_MEM_KEY, key_data,
      MHD_OPTION_CONNECTION_TIMEOUT, 15,
      MHD_OPTION_END);

  if (daemon == NULL)
  {
    fprintf(stderr, "Failed to start daemon.\n");
    free(cert_data);
    free(key_data);
#ifdef _WIN32
    WSACleanup();
#endif
    return 1;
  }

  printf("Proxy is running. Press Enter to stop.\n");
  getchar();

  MHD_stop_daemon(daemon);
  free(cert_data);
  free(key_data);
  printf("Proxy stopped.\n");

#ifdef _WIN32
  WSACleanup();
#endif
  return 0;
}
