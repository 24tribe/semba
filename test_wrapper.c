// needed for a bug in meson test with custom targets

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifdef __linux__
static int call_exe(char *exe) {
    size_t len = strlen(exe);
    char *final_cmd = malloc(len + 2 + 1);
    if (!final_cmd) { return 1; }
    strcpy(final_cmd, "./");
    strcpy(final_cmd + 2, exe);
    return system(final_cmd);
}
#else
static int call_exe(char *exe) {
    return system(exe)
}
#endif

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: test_wrapper cmd\n");
        return 1;
    }
    return call_exe(argv[1]);
}