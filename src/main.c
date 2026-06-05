#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mongoose.h"

struct server_config {
  const char *http_addr;
  const char *root_dir;
  int log_level;
};

struct server_state {
  struct server_config config;
};

static volatile sig_atomic_t s_stop;

static void on_signal(int signo) {
  s_stop = signo;
}

static void usage(const char *program) {
  fprintf(stderr,
          "Mongoose v%s static HTTP server\n"
          "\n"
          "Usage: %s [options]\n"
          "  --http ADDR    HTTP listen address, default http://0.0.0.0:8000\n"
          "  --root DIR     Static file root, default public\n"
          "  --log LEVEL    Log level 0..4, default 2\n"
          "  --help         Show this help\n"
          "\n"
          "HTTP/2 is intentionally not advertised or implemented here because\n"
          "Mongoose v7.21 supports HTTP/1.0 and HTTP/1.1, not native HTTP/2.\n",
          MG_VERSION, program);
}

static int read_arg(int argc, char **argv, int *index, const char **out) {
  if (*index + 1 >= argc) {
    fprintf(stderr, "Missing value for %s\n", argv[*index]);
    return 0;
  }
  *index += 1;
  *out = argv[*index];
  return 1;
}

static int parse_args(int argc, char **argv, struct server_config *config) {
  int i;

  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--http") == 0) {
      if (!read_arg(argc, argv, &i, &config->http_addr)) return 0;
    } else if (strcmp(argv[i], "--root") == 0) {
      if (!read_arg(argc, argv, &i, &config->root_dir)) return 0;
    } else if (strcmp(argv[i], "--log") == 0) {
      const char *value = NULL;
      char *end = NULL;
      long level;

      if (!read_arg(argc, argv, &i, &value)) return 0;
      level = strtol(value, &end, 10);
      if (*value == '\0' || *end != '\0' || level < MG_LL_NONE ||
          level > MG_LL_VERBOSE) {
        fprintf(stderr, "Invalid log level: %s\n", value);
        return 0;
      }
      config->log_level = (int) level;
    } else if (strcmp(argv[i], "--help") == 0) {
      usage(argv[0]);
      exit(0);
    } else {
      fprintf(stderr, "Unknown option: %s\n", argv[i]);
      return 0;
    }
  }

  return 1;
}

static void on_http_event(struct mg_connection *c, int ev, void *ev_data) {
  struct server_state *state = (struct server_state *) c->fn_data;

  if (ev == MG_EV_ACCEPT && c->is_tls) {
    // Currently no special handling for TLS connections
  }

  if (ev == MG_EV_HTTP_MSG) {
    struct mg_http_message *hm = (struct mg_http_message *) ev_data;
    struct mg_http_serve_opts opts;

    memset(&opts, 0, sizeof(opts));
    opts.root_dir = state->config.root_dir;
    opts.fs = &mg_fs_posix;
    
    mg_http_serve_dir(c, hm, &opts);

    MG_INFO(("%.*s %.*s", (int) hm->method.len, hm->method.buf,
             (int) hm->uri.len, hm->uri.buf));
  } else if (ev == MG_EV_ERROR) {
    char *error_msg = (char *) ev_data;
    MG_ERROR(("Server connection error occurred: %s", error_msg));
  }
}

int main(int argc, char **argv) {
  struct server_state state = {
    {"http://0.0.0.0:8000", "public", MG_LL_INFO},
  };
  struct mg_mgr mgr;
  struct mg_connection *http_listener;

  if (!parse_args(argc, argv, &state.config)) {
    usage(argv[0]);
    return 1;
  }

  signal(SIGINT, on_signal);
  signal(SIGTERM, on_signal);
  setvbuf(stdout, NULL, _IONBF, 0);
  mg_log_set(state.config.log_level);
  
  // Initialize the event manager
  mg_mgr_init(&mgr);

  // Instantiate HTTP listener on the target URL
  http_listener = mg_http_listen(&mgr, state.config.http_addr, on_http_event, &state);
  if (http_listener == NULL) {
    MG_ERROR(("Failed to bind server listener to %s", state.config.http_addr));
    mg_mgr_free(&mgr);
    return 1;
  }

  MG_INFO(("Mongoose version: %s", MG_VERSION));
  MG_INFO(("HTTP listening : %s", state.config.http_addr));
  MG_INFO(("Web root       : %s", state.config.root_dir));

  while (s_stop == 0) {
    mg_mgr_poll(&mgr, 5);
  }

  MG_INFO(("Stopping on signal %d", (int) s_stop));
  
  // Cleanup structures
  mg_mgr_free(&mgr);
  return 0;
}
