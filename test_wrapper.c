// needed for a bug in meson test with custom targets on windows

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: test_wrapper cmd test_saves_path\n");
        return 1;
    }
    char buffer[1024] = {0};
    strcat(buffer, argv[1]);
    strcat(buffer, " ");
    strcat(buffer, argv[2]);
    return system(buffer);
}