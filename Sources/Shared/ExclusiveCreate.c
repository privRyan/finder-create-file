#include <fcntl.h>

int finder_create_file_exclusive(const char *path) {
    return open(path, O_WRONLY | O_CREAT | O_EXCL, 0644);
}
