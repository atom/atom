# Copyright (c) 2012 Google Inc. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

{
 'targets': [
    {
      'target_name': 'test_batch',
      'type': 'none',
      'rules': [
      {
        'rule_name': 'build_with_batch',
        'msvs_cygwin_shell': 0,
        'extension': 'S',
        'inputs': ['<(RULE_INPUT_PATH)'],
        'outputs': ['output.obj'],
        'action': ['call go.bat', '<(RULE_INPUT_PATH)', 'output.obj'],
      },],
      'sources': ['a.S'],
    },
    {
      'target_name': 'test_call_separate',
      'type': 'none',
      'rules': [
      {
        'rule_name': 'build_with_batch2',
        'msvs_cygwin_shell': 0,
        'extension': 'S',
        'inputs': ['<(RULE_INPUT_PATH)'],
        'outputs': ['output2.obj'],
        'action': ['call', 'go.bat', '<(RULE_INPUT_PATH)', 'output2.obj'],
      },],
      'sources': ['a.S'],
    },
    {
      'target_name': 'test_with_spaces',
      'type': 'none',
      'rules': [
      {
        'rule_name': 'build_with_batch3',
        'msvs_cygwin_shell': 0,
        'extension': 'S',
        'inputs': ['<(RULE_INPUT_PATH)'],
        'outputs': ['output3.obj'],
        'action': ['bat with spaces.bat', '<(RULE_INPUT_PATH)', 'output3.obj'],
      },],
      'sources': ['a.S'],
    },
  ]
}
