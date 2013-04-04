{
  'variables': {
    'pkg-config': 'pkg-config',
    'chromium_code': 1,
    'use_aura%': 0,
    'conditions': [
      ['OS=="win"', {
        'os_posix': 0,
      }, {
        'os_posix': 1,
      }],
      # Set toolkit_uses_gtk for the Chromium browser on Linux.
      ['(OS=="linux" or OS=="freebsd" or OS=="openbsd" or OS=="solaris") and use_aura==0', {
        'toolkit_uses_gtk%': 1,
      }, {
        'toolkit_uses_gtk%': 0,
      }],
    ],
    'fix_framework_link_command': [
      'install_name_tool',
      '-change',
      '@executable_path/libcef.dylib',
      '@rpath/Chromium Embedded Framework.framework/Libraries/libcef.dylib',
      '-change',
      '@loader_path/../Frameworks/Sparkle.framework/Versions/A/Sparkle',
      '@rpath/Sparkle.framework/Versions/A/Sparkle',
      '-change',
      '@executable_path/../Frameworks/Quincy.framework/Versions/A/Quincy',
      '@rpath/Quincy.framework/Versions/A/Quincy',
      '${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}'
    ],
  },
  'includes': [
    'cef/cef_paths2.gypi',
    'sources.gypi',
  ],
  'target_defaults': {
    'default_configuration': 'Release',
    'configurations': {
      'Debug': {
        'defines': ['DEBUG=1'],
        'xcode_settings': { 'GCC_OPTIMIZATION_LEVEL' : '0' },
      },
      'Release': {
      },
    },
    'xcode_settings': {
      'VERSION': "<!(git rev-parse --short HEAD)",
      'CLANG_CXX_LANGUAGE_STANDARD' : 'c++0x',
      'GCC_VERSION': 'com.apple.compilers.llvm.clang.1_0',
      'COMBINE_HIDPI_IMAGES': 'YES', # Removes 'Validate Project Settings' warning
      'GCC_SYMBOLS_PRIVATE_EXTERN': 'YES' # Removes 'Reference to global weak symbol vtable' warning
    },
  },
  'targets': [
    {
      'target_name': 'Atom',
      'type': 'executable',
      'mac_bundle': 1,
      'msvs_guid': 'D22C6F51-AA2D-457C-B579-6C97A96C724D',
      'dependencies': [
        'atom_framework',
      ],
      'mac_framework_dirs': [ 'native/frameworks' ],
      'sources': [
        'native/main.cpp',
      ],
      'mac_bundle_resources': [
        'native/mac/atom.icns',
        'native/mac/file.icns',
        'native/mac/speakeasy.pem',
      ],
      'xcode_settings': {
        'INFOPLIST_FILE': 'native/mac/Atom-Info.plist',
        'LD_RUNPATH_SEARCH_PATHS': '@executable_path/../Frameworks',
      },
      'conditions': [
        ['CODE_SIGN' , {
          'xcode_settings': {'CODE_SIGN_IDENTITY': "<(CODE_SIGN)"},
        }],
        ['OS=="win" and win_use_allocator_shim==1', {
          'dependencies': [
            '<(DEPTH)/base/allocator/allocator.gyp:allocator',
          ],
        }],
        ['OS=="win"', {
          'configurations': {
            'Debug_Base': {
              'msvs_settings': {
                'VCLinkerTool': {
                  'LinkIncremental': '<(msvs_large_module_debug_link_mode)',
                },
              },
            },
          },
          'msvs_settings': {
            'VCLinkerTool': {
              # Set /SUBSYSTEM:WINDOWS.
              'SubSystem': '2',
              'EntryPointSymbol' : 'wWinMainCRTStartup',
            },
          },
          'link_settings': {
            'libraries': [
              '-lcomctl32.lib',
              '-lshlwapi.lib',
              '-lrpcrt4.lib',
            ],
          },
          'sources': [
            '<@(includes_win)',
          ],
        }],
        ['OS == "win" or (toolkit_uses_gtk == 1 and selinux == 0)', {
          'dependencies': [
            '<(DEPTH)/sandbox/sandbox.gyp:sandbox',
          ],
        }],
        ['toolkit_uses_gtk == 1', {
          'dependencies': [
            '<(DEPTH)/build/linux/system.gyp:gtk',
          ],
        }],
        [ 'OS=="mac"', {
          'product_name': 'Atom',
          'dependencies': [
            'AtomHelperApp',
          ],
          'copies': [
            {
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Frameworks/Chromium Embedded Framework.framework/Libraries/',
              'files': [
                'cef/Release/libcef.dylib',
                'cef/Release/ffmpegsumo.so',
              ],
            },
            {
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Frameworks',
              'files': [
                '<(PRODUCT_DIR)/Atom Helper.app',
                '<(PRODUCT_DIR)/Atom.framework',
                'native/frameworks/Sparkle.framework',
                'native/frameworks/Quincy.framework'
              ],
            },
            {
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Frameworks/Chromium Embedded Framework.framework',
              'files': [
                'cef/Resources',
              ],
            },
            {
              # Copy node binary for worker process support.
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Resources',
              'files': [
                'node/node',
              ],
            },
          ],
          'postbuilds': [
            {
              'postbuild_name': 'Fix Framework Link',
              'action': [
                '<@(fix_framework_link_command)',
              ],
            },
            {
              # This postbuid step is responsible for creating the following
              # helpers:
              #
              # Atom Helper EH.app and Atom Helper NP.app are created
              # from Atom Helper.app.
              #
              # The EH helper is marked for an executable heap. The NP helper
              # is marked for no PIE (ASLR).
              'postbuild_name': 'Make More Helpers',
              'action': [
                'script/make_more_helpers.sh',
                'Frameworks',
                'Atom',
              ],
            },
            {
              'postbuild_name': 'Print env for Constructicon',
              'action': [
                'env',
              ],
            },
          ],
          'link_settings': {
            'libraries': [
              '$(SDKROOT)/System/Library/Frameworks/AppKit.framework',
            ],
          },
          'sources': [
            'cef/include/cef_application_mac.h',
            'cef/include/internal/cef_mac.h',
            'cef/include/internal/cef_types_mac.h',
          ],
        }],
        [ 'OS=="linux" or OS=="freebsd" or OS=="openbsd"', {
          'sources': [
            '<@(includes_linux)',
          ],
          'copies': [
            {
              'destination': '<(PRODUCT_DIR)/files',
              'files': [
                '<@(cefclient_bundle_resources_linux)',
              ],
            },
          ],
        }],
      ],
    },
    {
      'target_name': 'atom_framework',
      'product_name': 'Atom',
      'type': 'shared_library',
      'mac_bundle': 1,
      'dependencies': [
        'generated_sources',
        'libcef_dll_wrapper',
      ],
      'defines': [
        'USING_CEF_SHARED',
      ],
      'xcode_settings': {
        'INFOPLIST_FILE': 'native/mac/framework-info.plist',
        'LD_DYLIB_INSTALL_NAME': '@rpath/Atom.framework/Atom',
      },
      'include_dirs': [ '.', 'cef' ],
      'mac_framework_dirs': [ 'native/frameworks' ],
      'sources': [
        '<@(includes_common)',
        '<@(includes_wrapper)',
        'native/atom_application.h',
        'native/atom_application.mm',
        'native/atom_cef_app.h',
        'native/atom_cef_app.h',
        'native/atom_cef_client.cpp',
        'native/atom_cef_client.h',
        'native/atom_cef_client_mac.mm',
        'native/atom_cef_render_process_handler.h',
        'native/atom_cef_render_process_handler.mm',
        'native/atom_window_controller.h',
        'native/atom_window_controller.mm',
        'native/atom_main.h',
        'native/atom_main_mac.mm',
        'native/message_translation.cpp',
        'native/message_translation.cpp',
        'native/message_translation.h',
        'native/message_translation.h',
        'native/path_watcher.h',
        'native/path_watcher.mm',
        'native/v8_extensions/atom.h',
        'native/v8_extensions/atom.mm',
        'native/v8_extensions/native.h',
        'native/v8_extensions/native.mm',
      ],
      'link_settings': {
        'libraries': [
          '$(SDKROOT)/System/Library/Frameworks/AppKit.framework',
          'native/frameworks/Sparkle.framework',
          'native/frameworks/Quincy.framework',
        ],
      },
      'mac_bundle_resources': [
        'native/mac/English.lproj/AtomWindow.xib',
        'native/mac/English.lproj/MainMenu.xib',
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
          'postbuild_name': 'Fix Framework Link',
          'action': [
            '<@(fix_framework_link_command)',
          ],
        },
      ],
    },
    {
      'target_name': 'libcef_dll_wrapper',
      'type': 'static_library',
      'msvs_guid': 'A9D6DC71-C0DC-4549-AEA0-3B15B44E86A9',
      'dependencies': [
      ],
      'defines': [
        'USING_CEF_SHARED',
      ],
      'include_dirs': [ '.', 'cef' ],
      'sources': [
        '<@(includes_common)',
        '<@(includes_capi)',
        '<@(includes_wrapper)',
        '<@(libcef_dll_wrapper_sources_common)',
      ],
      'link_settings': {
        'libraries': [
          'cef/Release/libcef.dylib',
        ],
      }
    },
    {
      'target_name': 'generated_sources',
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
    },
  ],
  'conditions': [
    ['os_posix==1 and OS!="mac" and OS!="android" and gcc_version==46', {
      'target_defaults': {
        # Disable warnings about c++0x compatibility, as some names (such
        # as nullptr) conflict with upcoming c++0x types.
        'cflags_cc': ['-Wno-c++0x-compat'],
      },
    }],
    ['OS=="mac"', {
      'targets': [
        {
          'target_name': 'AtomHelperApp',
          'type': 'executable',
          'variables': { 'enable_wexit_time_destructors': 1, },
          'product_name': 'Atom Helper',
          'mac_bundle': 1,
          'dependencies': [
            'atom_framework',
          ],
          'defines': [
            'USING_CEF_SHARED',
            'PROCESS_HELPER_APP',
          ],
          'mac_framework_dirs': [ 'native/frameworks' ],
          'sources': [
            'native/main.cpp',
          ],
          # TODO(mark): For now, don't put any resources into this app.  Its
          # resources directory will be a symbolic link to the browser app's
          # resources directory.
          'mac_bundle_resources/': [
            ['exclude', '.*'],
          ],
          'xcode_settings': {
            'INFOPLIST_FILE': 'native/mac/helper-info.plist',
            'LD_RUNPATH_SEARCH_PATHS': '@executable_path/../../..',
          },
          'postbuilds': [
            {
              'postbuild_name': 'Fix Framework Link',
              'action': [
                '<@(fix_framework_link_command)',
              ],
            },
          ],
        },  # target cefclient_helper_app
      ],
    }],  # OS=="mac"
  ],
}
