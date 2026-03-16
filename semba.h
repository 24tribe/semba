#ifndef SEMBA_H_2025_09_16_05_13
#define SEMBA_H_2025_09_16_05_13

#include <stdint.h>

extern void NimMain(void);

extern char *SembaCall(const char *uri, const char *request);
extern char *SembaCallDemo(const char *uri, const char *request);
extern void SembaInitOfflineDb(const char *path);
extern void SembaSetRemoteUrl(const char *url);

struct SembaExContext;

extern struct SembaExContext *SembaExInit(const char *dbPath, int32_t gameVersion, int32_t *status);
extern char *SembaExCall(struct SembaExContext *ctx, const char *path, const char *req, int32_t *status);
extern void SembaExFreeResponse(char *response);
extern void SembaExDeinit(struct SembaExContext *ctx);

#endif