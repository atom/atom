#!/bin/sh
python translator.py --cpp-header-dir ../include --capi-header-dir ../include/capi --cpptoc-global-impl ../libcef_dll/libcef_dll.cc --ctocpp-global-impl ../libcef_dll/wrapper/libcef_dll_wrapper.cc --cpptoc-dir ../libcef_dll/cpptoc --ctocpp-dir ../libcef_dll/ctocpp  --gypi-file ../cef_paths.gypi
