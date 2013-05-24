{
  'variables': {
    'version%': "<!(git rev-parse --short HEAD)",
  },
  'includes': [
    'sources.gypi',
  ],
  'target_defaults': {
    'default_configuration': 'Release',
    'configurations': {
      'Release': {
      },
    },
  },
  'targets': [
    {
      'target_name': 'Atom',
      'type': 'none',
      'sources': [
        '<@(coffee_sources)',
        '<@(cson_sources)',
        '<@(less_sources)'
      ],
      'rules': [
        {
          'rule_name': 'coffee',
          'extension': 'coffee',
          'inputs': [
            'script/compile-coffee',
          ],
          'outputs': [
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).js',
          ],
          'action': [
            'sh',
            'script/compile-coffee',
            '<(RULE_INPUT_PATH)',
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).js',
          ],
        },
        {
          'rule_name': 'cson2json',
          'extension': 'cson',
          'inputs': [
            'script/compile-cson',
          ],
          'outputs': [
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).json',
          ],
          'action': [
            'sh',
            'script/compile-cson',
            '<(RULE_INPUT_PATH)',
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).json',
          ],
        },
        {
          'rule_name': 'less',
          'extension': 'less',
          'inputs': [
            'script/compile-less',
          ],
          'outputs': [
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).css',
          ],
          'action': [
            'sh',
            'script/compile-less',
            '<(RULE_INPUT_PATH)',
            '<(compiled_sources_dir)/<(RULE_INPUT_DIRNAME)/<(RULE_INPUT_ROOT).css',
          ],
        },
      ],
      'copies': [
        {
          'destination': '<(PRODUCT_DIR)',
          'files': [
            'atom-shell/Atom.app'
          ],
        },
      ],
      'postbuilds': [
        {
          'postbuild_name': 'Copy Static Files',
          'action': [
            'script/copy-files-to-bundle',
            '<(compiled_sources_dir_xcode)',
          ],
        },
        {
          'postbuild_name': 'Generate Version',
          'action': [
            'script/generate-version',
            '<(version)',
          ],
        },
      ],
    },
  ],
}
