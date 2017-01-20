/** @babel */

import path from 'path'
import fs from 'fs-plus'

// This is loaded by atom-environment.coffee. See
// https://atom.io/docs/api/latest/Config for more information about config
// schemas.
const configSchema = {
  core: {
    type: 'object',
    properties: {
      ignoredNames: {
        type: 'array',
        default: ['.git', '.hg', '.svn', '.DS_Store', '._*', 'Thumbs.db', 'desktop.ini'],
        items: {
          type: 'string'
        },
        description: 'List of [glob patterns](https://en.wikipedia.org/wiki/Glob_%28programming%29). Files and directories matching these patterns will be ignored by some packages, such as the fuzzy finder and tree view. Individual packages might have additional config settings for ignoring names.'
      },
      excludeVcsIgnoredPaths: {
        type: 'boolean',
        default: true,
        title: 'Exclude VCS Ignored Paths',
        description: 'Files and directories ignored by the current project\'s VCS system will be ignored by some packages, such as the fuzzy finder and find and replace. For example, projects using Git have these paths defined in the .gitignore file. Individual packages might have additional config settings for ignoring VCS ignored files and folders.'
      },
      followSymlinks: {
        type: 'boolean',
        default: true,
        description: 'Follow symbolic links when searching files and when opening files with the fuzzy finder.'
      },
      disabledPackages: {
        type: 'array',
        default: [],

        items: {
          type: 'string'
        },

        description: 'List of names of installed packages which are not loaded at startup.'
      },
      customFileTypes: {
        type: 'object',
        default: {},
        description: 'Associates scope names (e.g. `"source.js"`) with arrays of file extensions and file names (e.g. `["Somefile", ".js2"]`)',
        additionalProperties: {
          type: 'array',
          items: {
            type: 'string'
          }
        }
      },
      themes: {
        type: 'array',
        default: ['one-dark-ui', 'one-dark-syntax'],
        items: {
          type: 'string'
        },
        description: 'Names of UI and syntax themes which will be used when Atom starts.'
      },
      projectHome: {
        type: 'string',
        default: path.join(fs.getHomeDirectory(), 'github'),
        description: 'The directory where projects are assumed to be located. Packages created using the Package Generator will be stored here by default.'
      },
      audioBeep: {
        type: 'boolean',
        default: true,
        description: 'Trigger the system\'s beep sound when certain actions cannot be executed or there are no results.'
      },
      destroyEmptyPanes: {
        type: 'boolean',
        default: true,
        title: 'Remove Empty Panes',
        description: 'When the last tab of a pane is closed, remove that pane as well.'
      },
      closeEmptyWindows: {
        type: 'boolean',
        default: true,
        description: 'When a window with no open tabs or panes is given the \'Close Tab\' command, close that window.'
      },
      fileEncoding: {
        description: 'Default character set encoding to use when reading and writing files.',
        type: 'string',
        default: 'utf8',
        enum: [
          'cp437',
          'cp850',
          'cp866',
          'eucjp',
          'euckr',
          'gbk',
          'iso88591',
          'iso885910',
          'iso885913',
          'iso885914',
          'iso885915',
          'iso885916',
          'iso88592',
          'iso88593',
          'iso88594',
          'iso88595',
          'iso88596',
          'iso88597',
          'iso88597',
          'iso88598',
          'koi8r',
          'koi8u',
          'macroman',
          'shiftjis',
          'utf16be',
          'utf16le',
          'utf8',
          'windows1250',
          'windows1251',
          'windows1252',
          'windows1253',
          'windows1254',
          'windows1255',
          'windows1256',
          'windows1257',
          'windows1258'
        ]
      },
      openEmptyEditorOnStart: {
        description: 'When checked opens an untitled editor when loading a blank environment (such as with _File > New Window_ or when "Restore Previous Windows On Start" is unchecked); otherwise no editor is opened when loading a blank environment. This setting has no effect when restoring a previous state.',
        type: 'boolean',
        default: true
      },
      restorePreviousWindowsOnStart: {
        description: 'When checked restores the last state of all Atom windows when started from the icon or `atom` by itself from the command line; otherwise a blank environment is loaded.',
        type: 'boolean',
        default: true
      },
      reopenProjectMenuCount: {
        description: 'How many recent projects to show in the Reopen Project menu.',
        type: 'integer',
        default: 15
      },
      automaticallyUpdate: {
        description: 'Automatically update Atom when a new release is available.',
        type: 'boolean',
        default: true
      },
      useProxySettingsWhenCallingApm: {
        title: 'Use Proxy Settings When Calling APM',
        description: 'Use detected proxy settings when calling the `apm` command-line tool.',
        type: 'boolean',
        default: true
      },
      allowPendingPaneItems: {
        description: 'Allow items to be previewed without adding them to a pane permanently, such as when single clicking files in the tree view.',
        type: 'boolean',
        default: true
      },
      telemetryConsent: {
        description: 'Allow usage statistics and exception reports to be sent to the Atom team to help improve the product.',
        title: 'Send Telemetry to the Atom Team',
        type: 'string',
        default: 'undecided',
        enum: [
          {
            value: 'limited',
            description: 'Allow limited anonymous usage stats, exception and crash reporting'
          },
          {
            value: 'no',
            description: 'Do not send any telemetry data'
          },
          {
            value: 'undecided',
            description: 'Undecided (Atom will ask again next time it is launched)'
          }
        ]
      },
      warnOnLargeFileLimit: {
        description: 'Warn before opening files larger than this number of megabytes.',
        type: 'number',
        default: 40
      }
    }
  },
  editor: {
    type: 'object',
    // These settings are used in scoped fashion only. No defaults.
    properties: {
      commentStart: {
        type: ['string', 'null']
      },
      commentEnd: {
        type: ['string', 'null']
      },
      increaseIndentPattern: {
        type: ['string', 'null']
      },
      decreaseIndentPattern: {
        type: ['string', 'null']
      },
      foldEndPattern: {
        type: ['string', 'null']
      },
      // These can be used as globals or scoped, thus defaults.
      fontFamily: {
        type: 'string',
        default: '',
        description: 'The name of the font family used for editor text.'
      },
      fontSize: {
        type: 'integer',
        default: 14,
        minimum: 1,
        maximum: 100,
        description: 'Height in pixels of editor text.'
      },
      lineHeight: {
        type: ['string', 'number'],
        default: 1.5,
        description: 'Height of editor lines, as a multiplier of font size.'
      },
      showCursorOnSelection: {
        type: 'boolean',
        'default': true,
        description: 'Show cursor while there is a selection.'
      },
      showInvisibles: {
        type: 'boolean',
        default: false,
        description: 'Render placeholders for invisible characters, such as tabs, spaces and newlines.'
      },
      showIndentGuide: {
        type: 'boolean',
        default: false,
        description: 'Show indentation indicators in the editor.'
      },
      showLineNumbers: {
        type: 'boolean',
        default: true,
        description: 'Show line numbers in the editor\'s gutter.'
      },
      atomicSoftTabs: {
        type: 'boolean',
        default: true,
        description: 'Skip over tab-length runs of leading whitespace when moving the cursor.'
      },
      autoIndent: {
        type: 'boolean',
        default: true,
        description: 'Automatically indent the cursor when inserting a newline.'
      },
      autoIndentOnPaste: {
        type: 'boolean',
        default: true,
        description: 'Automatically indent pasted text based on the indentation of the previous line.'
      },
      nonWordCharacters: {
        type: 'string',
        default: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-…",
        description: 'A string of non-word characters to define word boundaries.'
      },
      preferredLineLength: {
        type: 'integer',
        default: 80,
        minimum: 1,
        description: 'Identifies the length of a line which is used when wrapping text with the `Soft Wrap At Preferred Line Length` setting enabled, in number of characters.'
      },
      tabLength: {
        type: 'integer',
        default: 2,
        minimum: 1,
        description: 'Number of spaces used to represent a tab.'
      },
      softWrap: {
        type: 'boolean',
        default: false,
        description: 'Wraps lines that exceed the width of the window. When `Soft Wrap At Preferred Line Length` is set, it will wrap to the number of characters defined by the `Preferred Line Length` setting.'
      },
      softTabs: {
        type: 'boolean',
        default: true,
        description: 'If the `Tab Type` config setting is set to "auto" and autodetection of tab type from buffer content fails, then this config setting determines whether a soft tab or a hard tab will be inserted when the Tab key is pressed.'
      },
      tabType: {
        type: 'string',
        default: 'auto',
        enum: ['auto', 'soft', 'hard'],
        description: 'Determine character inserted when Tab key is pressed. Possible values: "auto", "soft" and "hard". When set to "soft" or "hard", soft tabs (spaces) or hard tabs (tab characters) are used. When set to "auto", the editor auto-detects the tab type based on the contents of the buffer (it uses the first leading whitespace on a non-comment line), or uses the value of the Soft Tabs config setting if auto-detection fails.'
      },
      softWrapAtPreferredLineLength: {
        type: 'boolean',
        default: false,
        description: 'Instead of wrapping lines to the window\'s width, wrap lines to the number of characters defined by the `Preferred Line Length` setting. This will only take effect when the soft wrap config setting is enabled globally or for the current language. **Note:** If you want to hide the wrap guide (the vertical line) you can disable the `wrap-guide` package.'
      },
      softWrapHangingIndent: {
        type: 'integer',
        default: 0,
        minimum: 0,
        description: 'When soft wrap is enabled, defines length of additional indentation applied to wrapped lines, in number of characters.'
      },
      scrollSensitivity: {
        type: 'integer',
        default: 40,
        minimum: 10,
        maximum: 200,
        description: 'Determines how fast the editor scrolls when using a mouse or trackpad.'
      },
      scrollPastEnd: {
        type: 'boolean',
        default: false,
        description: 'Allow the editor to be scrolled past the end of the last line.'
      },
      undoGroupingInterval: {
        type: 'integer',
        default: 300,
        minimum: 0,
        description: 'Time interval in milliseconds within which text editing operations will be grouped together in the undo history.'
      },
      confirmCheckoutHeadRevision: {
        type: 'boolean',
        default: true,
        title: 'Confirm Checkout HEAD Revision',
        description: 'Show confirmation dialog when checking out the HEAD revision and discarding changes to current file since last commit.'
      },
      invisibles: {
        type: 'object',
        description: 'A hash of characters Atom will use to render whitespace characters. Keys are whitespace character types, values are rendered characters (use value false to turn off individual whitespace character types).',
        properties: {
          eol: {
            type: ['boolean', 'string'],
            default: '¬',
            maximumLength: 1,
            description: 'Character used to render newline characters (\\n) when the `Show Invisibles` setting is enabled. '
          },
          space: {
            type: ['boolean', 'string'],
            default: '·',
            maximumLength: 1,
            description: 'Character used to render leading and trailing space characters when the `Show Invisibles` setting is enabled.'
          },
          tab: {
            type: ['boolean', 'string'],
            default: '»',
            maximumLength: 1,
            description: 'Character used to render hard tab characters (\\t) when the `Show Invisibles` setting is enabled.'
          },
          cr: {
            type: ['boolean', 'string'],
            default: '¤',
            maximumLength: 1,
            description: 'Character used to render carriage return characters (for Microsoft-style line endings) when the `Show Invisibles` setting is enabled.'
          }
        }
      },
      zoomFontWhenCtrlScrolling: {
        type: 'boolean',
        default: process.platform !== 'darwin',
        description: 'Change the editor font size when pressing the Ctrl key and scrolling the mouse up/down.'
      }
    }
  }
}

if (['win32', 'linux'].includes(process.platform)) {
  configSchema.core.properties.autoHideMenuBar = {
    type: 'boolean',
    default: false,
    description: 'Automatically hide the menu bar and toggle it by pressing Alt. This is only supported on Windows & Linux.'
  }
}

if (process.platform === 'darwin') {
  configSchema.core.properties.useCustomTitleBar = {
    type: 'boolean',
    default: false,
    description: 'Use custom, theme-aware title bar.<br>Note: This currently does not include a proxy icon.<br>This setting will require a relaunch of Atom to take effect.'
  }
}

export default configSchema
