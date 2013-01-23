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
  },
  'includes': [
    'cef/cef_paths2.gypi',
    'git2/libgit2.gypi',
  ],
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': {
        'defines': ['DEBUG=1', 'RESOURCE_PATH="$PROJECT_DIR"'],
        'xcode_settings': { 'GCC_OPTIMIZATION_LEVEL' : '0' },
      },
      'Release': {
      },
    },
    'xcode_settings': {
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
        'libcef_dll_wrapper',
      ],
      'defines': [
        'USING_CEF_SHARED',
      ],
      'include_dirs': [ '.', 'cef', 'git2' ],
      'mac_framework_dirs': [ 'native/frameworks' ],
      'libraries': [ 'native/frameworks/CocoaOniguruma.framework', 'native/frameworks/Sparkle.framework'],
      'sources': [
        '<@(includes_common)',
        '<@(includes_wrapper)',
        'native/main_mac.mm',
        'native/atom_application.h',
        'native/atom_application.mm',
        'native/atom_cef_app.h',
        'native/atom_window_controller.h',
        'native/atom_window_controller.mm',
        'native/atom_cef_client_mac.mm',
        'native/atom_cef_client.cpp',
        'native/atom_cef_client.h',
        'native/message_translation.cpp',
        'native/message_translation.h',
      ],
      'mac_bundle_resources': [
        'native/mac/atom.icns',
        'native/mac/file.icns',
        'native/mac/speakeasy.pem',
        'native/mac/English.lproj/MainMenu.xib',
        'native/mac/English.lproj/AtomWindow.xib',
      ],
      'xcode_settings': {
        'INFOPLIST_FILE': 'native/mac/info.plist',
        'OTHER_LDFLAGS': ['-Wl,-headerpad_max_install_names'], # Necessary to avoid an "install_name_tool: changing install names or rpaths can't be redone" error.
      },
      'conditions': [
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
                'cef/frameworks/libcef.dylib',
                'cef/frameworks/ffmpegsumo.so',
              ],
            },
            {
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Frameworks',
              'files': [
                'native/frameworks/CocoaOniguruma.framework',
                'native/frameworks/Sparkle.framework',
              ],
            },
            {
              'destination': '<(PRODUCT_DIR)/Atom.app/Contents/Frameworks/libgit2.framework/Libraries',
              'files': [
                'git2/frameworks/libgit2.0.17.0.dylib',
              ],
            },
          ],
          'postbuilds': [
            {
              'postbuild_name': 'Copy and Compile Static Files',
              'action': [
                'script/copy-files-to-bundle'
              ],
            },
            {
              'postbuild_name': 'Copy Helper App',
              'action': [
                'cp',
                '-r',
                '${BUILT_PRODUCTS_DIR}/Atom Helper.app',
                '${BUILT_PRODUCTS_DIR}/Atom.app/Contents/Frameworks',
              ],
            },
            {
              'postbuild_name': 'Fix Framework Link',
              'action': [
                'install_name_tool',
                '-change',
                '@executable_path/libcef.dylib',
                '@executable_path/../Frameworks/Chromium Embedded Framework.framework/Libraries/libcef.dylib',
                '${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}'
              ],
            },
            {
              'postbuild_name': 'Copy Framework Resources Directory',
              'action': [
                'cp',
                '-r',
                'cef/Resources',
                '${BUILT_PRODUCTS_DIR}/Atom.app/Contents/Frameworks/Chromium Embedded Framework.framework/'
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
                'tools/mac/make_more_helpers.sh',
                'Frameworks',
                'Atom',
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
          'cef/frameworks/libcef.dylib',
        ],
      }
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
            'libcef_dll_wrapper',
          ],
          'defines': [
            'USING_CEF_SHARED',
            'PROCESS_HELPER_APP',
          ],
          'include_dirs': [ '.', 'cef', 'git2' ],
          'mac_framework_dirs': [ 'native/frameworks' ],
          'link_settings': {
            'libraries': [
              '$(SDKROOT)/System/Library/Frameworks/AppKit.framework',
            ],
          },
          'libraries': [
            'native/frameworks/CocoaOniguruma.framework',
            'git2/frameworks/libgit2.0.17.0.dylib',
          ],
          'sources': [
            'native/atom_cef_app.h',
            'native/atom_cef_render_process_handler.h',
            'native/atom_cef_render_process_handler.mm',
            'native/message_translation.cpp',
            'native/message_translation.h',
            'native/path_watcher.mm',
            'native/path_watcher.h',
            'native/main_helper_mac.mm',
            'native/v8_extensions/native.mm',
            'native/v8_extensions/native.h',
            'native/v8_extensions/onig_reg_exp.mm',
            'native/v8_extensions/onig_reg_exp.h',
            'native/v8_extensions/onig_scanner.mm',
            'native/v8_extensions/onig_scanner.h',
            'native/v8_extensions/atom.mm',
            'native/v8_extensions/atom.h',
            'native/v8_extensions/git.mm',
            'native/v8_extensions/git.h',
            'native/v8_extensions/readtags.h',
            'native/v8_extensions/readtags.c',
            'native/v8_extensions/tags.h',
            'native/v8_extensions/tags.mm',
          ],
          # TODO(mark): For now, don't put any resources into this app.  Its
          # resources directory will be a symbolic link to the browser app's
          # resources directory.
          'mac_bundle_resources/': [
            ['exclude', '.*'],
          ],
          'xcode_settings': {
            'INFOPLIST_FILE': 'native/mac/helper-info.plist',
            'OTHER_LDFLAGS': ['-Wl,-headerpad_max_install_names'], # Necessary to avoid an "install_name_tool: changing install names or rpaths can't be redone" error.
          },
          'copies': [
            {
              'destination': '<(PRODUCT_DIR)/Atom Helper.app/Contents/Frameworks',
              'files': [
                'native/frameworks/CocoaOniguruma.framework',
              ],
            },
          ],
          'postbuilds': [
            {
              # The framework defines its load-time path
              # (DYLIB_INSTALL_NAME_BASE) relative to the main executable
              # (chrome).  A different relative path needs to be used in
              # atom_helper_app.
              'postbuild_name': 'Fix CEF Framework Link',
              'action': [
                'install_name_tool',
                '-change',
                '@executable_path/libcef.dylib',
                '@executable_path/../../../../Frameworks/Chromium Embedded Framework.framework/Libraries/libcef.dylib',
                '${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}'
              ],
            },
            {
              'postbuild_name': 'Fix libgit2 Framework Link',
              'action': [
                'install_name_tool',
                '-change',
                '@executable_path/libgit2.0.17.0.dylib',
                '@executable_path/../../../../Frameworks/libgit2.framework/Libraries/libgit2.0.17.0.dylib',
                '${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}'
              ],
            },
            {
              'postbuild_name': 'Copy and Compile Static Files',
              'action': [
                'script/copy-files-to-bundle'
              ],
            },
          ],
        },  # target cefclient_helper_app
      ],
    }],  # OS=="mac"
  ],
}
