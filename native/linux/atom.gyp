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
        ],
        'include_dirs': [
          '../cef',
        ],
        'sources': [
          'atom.cpp',
          'atom_cef_render_process_handler.cpp',
          'atom_handler.cpp',
          'client_handler.cpp',
          'io_utils.cpp',
          'message_translation.cpp',
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
