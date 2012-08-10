# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This file is meant to be included into a target to provide a rule
# to build APK based test suites.
#
# To use this, create a gyp target with the following form:
# {
#   'target_name': 'test_suite_name_apk',
#   'type': 'none',
#   'variables': {
#     'test_suite_name': 'test_suite_name',  # string
#     'input_shlib_path' : '/path/to/test_suite.so',  # string
#     'input_jars_paths': ['/path/to/test_suite.jar', ... ],  # list
#   },
#   'includes': ['path/to/this/gypi/file'],
# }
#

{
  'target_conditions': [
    ['_toolset == "target"', {
      'conditions': [
        ['OS == "android" and gtest_target_type == "shared_library"', {
          'actions': [{
            'action_name': 'apk_<(test_suite_name)',
            'message': 'Building <(test_suite_name) test apk.',
            'inputs': [
              '<(DEPTH)/testing/android/AndroidManifest.xml',
              '<(DEPTH)/testing/android/generate_native_test.py',
              '<(input_shlib_path)',
              '<@(input_jars_paths)',
            ],
            'outputs': [
              '<(PRODUCT_DIR)/<(test_suite_name)_apk/<(test_suite_name)-debug.apk',
            ],
            'action': [
              '<(DEPTH)/testing/android/generate_native_test.py',
              '--native_library',
              '<(input_shlib_path)',
              '--jars',
              '"<@(input_jars_paths)"',
              '--output',
              '<(PRODUCT_DIR)/<(test_suite_name)_apk',
              '--app_abi',
              '<(android_app_abi)',
              '--ant-args',
              '-DPRODUCT_DIR=<(ant_build_out)',
              '--ant-compile'
            ],
          }],
        }],  # 'OS == "android" and gtest_target_type == "shared_library"
      ],  # conditions
    }],
  ],  # target_conditions
}
