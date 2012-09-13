{
    'targets': [
      {
        'target_name': 'atom',
        'type': 'executable',
        'variables': {
          'pkg-config': 'pkg-config',
          'install-dir': '/usr/share/atom',
        },
        'dependencies': [
        ],
        'defines': [
           'PROCESS_HELPER_APP',
        ],
        'include_dirs': [
          '../../cef',
          '..',
          '../v8_extensions',
          '.',
        ],
        'sources': [
          '../v8_extensions/atom_linux.cpp',
          '../v8_extensions/native_linux.cpp',
          '../v8_extensions/onig_reg_exp_linux.cpp',
          '../message_translation.cpp',
          'atom.cpp',
          'atom_cef_render_process_handler.cpp',
          'client_handler.cpp',
          'io_utils.cpp',
          'native_handler.cpp',
          'onig_regexp_extension.cpp',
        ],
        'cflags': [
            '<!@(<(pkg-config) --cflags gtk+-2.0 gthread-2.0 openssl)',
        ],
        'link_settings': {
          'ldflags': [
            '<!@(<(pkg-config) --libs-only-L --libs-only-other gtk+-2.0 gthread-2.0 openssl)',
            '-Llib',
            '-Wl,-rpath=<(install-dir)',
          ],
          'libraries': [
            '<!@(<(pkg-config) --libs-only-l gtk+-2.0 gthread-2.0 openssl)',
            '-lcef',
            '-lcef_dll_wrapper',
            '-lonig',
          ],
        }
      },
    ],
  }
