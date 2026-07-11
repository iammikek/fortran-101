#include <ctype.h>
#include <crypt.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <sqlite3.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void base64url_encode(const unsigned char *input, size_t len, char *output, size_t out_cap) {
  static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  size_t i = 0;
  size_t o = 0;

  while (i < len) {
    size_t remaining = len - i;
    unsigned int a = input[i++];
    unsigned int b = remaining > 1 ? input[i++] : 0;
    unsigned int c = remaining > 2 ? input[i++] : 0;
    unsigned int triple = (a << 16) + (b << 8) + c;

    if (o + 4 >= out_cap) break;
    output[o++] = table[(triple >> 18) & 0x3F];
    output[o++] = table[(triple >> 12) & 0x3F];
    output[o++] = remaining > 1 ? table[(triple >> 6) & 0x3F] : '=';
    output[o++] = remaining > 2 ? table[triple & 0x3F] : '=';
  }

  while (o > 0 && output[o - 1] == '=') {
    o--;
  }
  for (size_t j = 0; j < o; j++) {
    if (output[j] == '+') output[j] = '-';
    else if (output[j] == '/') output[j] = '_';
  }
  output[o] = '\0';
}

static int base64url_decode_char(int c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '-') return 62;
  if (c == '_') return 63;
  return -1;
}

static int base64url_decode(const char *input, unsigned char *output, size_t out_cap) {
  size_t len = strlen(input);
  size_t o = 0;

  for (size_t i = 0; i < len; i += 4) {
    int vals[4];
    int pad = 0;

    for (int j = 0; j < 4; j++) {
      if (i + (size_t)j >= len) {
        vals[j] = 0;
        pad++;
      } else {
        int v = base64url_decode_char(input[i + (size_t)j]);
        if (v < 0) return -1;
        vals[j] = v;
      }
    }

    if (o < out_cap) output[o++] = (unsigned char)((vals[0] << 2) | (vals[1] >> 4));
    if (pad < 2 && o < out_cap) output[o++] = (unsigned char)(((vals[1] & 0xF) << 4) | (vals[2] >> 2));
    if (pad < 1 && o < out_cap) output[o++] = (unsigned char)(((vals[2] & 0x3) << 6) | vals[3]);
  }
  return (int)o;
}

static void hmac_sha256(const char *key, const char *data, unsigned char *out) {
  unsigned int len = 0;
  HMAC(EVP_sha256(), key, (int)strlen(key), (const unsigned char *)data, strlen(data), out, &len);
}

int chelpers_hash_password(const char *password, char *out, int out_len) {
  char salt[32];
  snprintf(salt, sizeof(salt), "$6$%08x$", (unsigned int)time(NULL));
  char *hash = crypt(password, salt);
  if (!hash) return 0;
  snprintf(out, (size_t)out_len, "%s", hash);
  return 1;
}

int chelpers_bind_text(void *stmt, int idx, const char *text) {
  return sqlite3_bind_text((sqlite3_stmt *)stmt, idx, text, -1, SQLITE_TRANSIENT);
}

int chelpers_verify_password(const char *password, const char *hash) {
  char *result = crypt(password, hash);
  if (!result) return 0;
  return strcmp(result, hash) == 0 ? 1 : 0;
}

int chelpers_jwt_create(const char *email, const char *secret, char *out, int out_len) {
  char header_b64[128];
  char payload[512];
  char payload_b64[768];
  char signing_input[1024];
  unsigned char signature[32];
  char signature_b64[128];
  time_t now = time(NULL);

  snprintf(payload, sizeof(payload),
           "{\"sub\":\"%s\",\"exp\":%ld}",
           email, (long)(now + 3600));

  base64url_encode((const unsigned char *)"{\"alg\":\"HS256\",\"typ\":\"JWT\"}", 30, header_b64, sizeof(header_b64));
  base64url_encode((const unsigned char *)payload, strlen(payload), payload_b64, sizeof(payload_b64));
  snprintf(signing_input, sizeof(signing_input), "%s.%s", header_b64, payload_b64);
  hmac_sha256(secret, signing_input, signature);
  base64url_encode(signature, 32, signature_b64, sizeof(signature_b64));
  snprintf(out, (size_t)out_len, "%s.%s.%s", header_b64, payload_b64, signature_b64);
  return 1;
}

static int json_extract_int(const char *json, const char *key, int *value) {
  char pattern[64];
  snprintf(pattern, sizeof(pattern), "\"%s\":", key);
  const char *pos = strstr(json, pattern);
  if (!pos) return 0;
  pos += strlen(pattern);
  while (*pos == ' ') pos++;
  *value = atoi(pos);
  return 1;
}

static int json_extract_string(const char *json, const char *key, char *out, int out_len) {
  char pattern[64];
  snprintf(pattern, sizeof(pattern), "\"%s\":\"", key);
  const char *pos = strstr(json, pattern);
  if (!pos) return 0;
  pos += strlen(pattern);
  const char *end = strchr(pos, '"');
  if (!end) return 0;
  int len = (int)(end - pos);
  if (len >= out_len) len = out_len - 1;
  memcpy(out, pos, (size_t)len);
  out[len] = '\0';
  return 1;
}

int chelpers_jwt_verify(const char *token, const char *secret, char *email, int email_len) {
  char token_copy[2048];
  char header_b64[256];
  char payload_b64[768];
  char signature_b64[128];
  char signing_input[1024];
  unsigned char expected[32];
  unsigned char provided[64];
  char payload_json[512];
  int provided_len;
  char *dot1;
  char *dot2;

  snprintf(token_copy, sizeof(token_copy), "%s", token);
  dot1 = strchr(token_copy, '.');
  if (!dot1) return 0;
  *dot1 = '\0';
  snprintf(header_b64, sizeof(header_b64), "%s", token_copy);

  dot2 = strchr(dot1 + 1, '.');
  if (!dot2) return 0;
  *dot2 = '\0';
  snprintf(payload_b64, sizeof(payload_b64), "%s", dot1 + 1);
  snprintf(signature_b64, sizeof(signature_b64), "%s", dot2 + 1);

  snprintf(signing_input, sizeof(signing_input), "%s.%s", header_b64, payload_b64);
  hmac_sha256(secret, signing_input, expected);
  provided_len = base64url_decode(signature_b64, provided, sizeof(provided));
  if (provided_len != 32 || memcmp(expected, provided, 32) != 0) return 0;

  if (base64url_decode(payload_b64, (unsigned char *)payload_json, sizeof(payload_json) - 1) <= 0) return 0;
  payload_json[sizeof(payload_json) - 1] = '\0';
  for (int i = 0; payload_json[i] != '\0'; i++) {
    if (payload_json[i] < 32) payload_json[i] = '\0';
  }

  if (!json_extract_string(payload_json, "sub", email, email_len)) return 0;

  int exp = 0;
  if (!json_extract_int(payload_json, "exp", &exp)) return 0;
  if (exp < (int)time(NULL)) return 0;

  return 1;
}
