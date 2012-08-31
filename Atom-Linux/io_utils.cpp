#include "io_utils.h"
#include "atom.h"
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>

#define BUFFER_SIZE 8192

using namespace std;

int io_utils_read(string path, string* output) {
  int fd = open(path.c_str(), O_RDONLY);
  if (fd <= 0)
    return 0;

  char buffer[BUFFER_SIZE];
  unsigned int bytesRead = 0;
  unsigned int totalRead = 0;
  while ((bytesRead = read(fd, buffer, BUFFER_SIZE)) > 0) {
    output->append(buffer, 0, bytesRead);
    totalRead += bytesRead;
  }
  close(fd);
  return totalRead;
}

string io_utils_real_app_path(string relativePath) {
  string path = AppPath() + relativePath;
  char* realPath = realpath(path.c_str(), NULL);
  if (realPath != NULL) {
    string realAppPath(realPath);
    free(realPath);
    return realAppPath;
  } else
    return "";
}

string io_util_app_directory() {
  char path[BUFFER_SIZE];
  if (readlink("/proc/self/exe", path, BUFFER_SIZE) < 2)
    return "";

  string appPath(path);
  unsigned int lastSlash = appPath.rfind("/");
  if (lastSlash != string::npos)
    return appPath.substr(0, lastSlash);
  else
    return appPath;
}