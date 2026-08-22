#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stdio.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "usage: AtomicInstallMove source destination\n");
        return 64;
    }
    if (renameatx_np(AT_FDCWD, argv[1], AT_FDCWD, argv[2], RENAME_EXCL) == 0) {
        return 0;
    }
    int error = errno;
    perror("AtomicInstallMove");
    return error == EEXIST ? 17 : 1;
}
