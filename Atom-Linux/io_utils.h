#ifndef IO_UTILS_H_
#define IO_UTILS_H_
#pragma once

#include <string>

/**
 * Read file at path and append to output string
 */
int io_utils_read(std::string path, std::string* output);

/**
 * Get realpath for given path that is relative to the app path
 */
std::string io_utils_real_app_path(std::string relativePath);

#endif
