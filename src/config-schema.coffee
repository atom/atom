path = require 'path'
fs = require 'fs-plus'

# This is loaded by atom.coffee. See https://atom.io/docs/api/latest/Config for
# more information about config schemas.
module.exports =
  core:
    type: 'object'
    properties:
      ignoredNames:
        type: 'array'
        default: [".git", ".hg", ".svn", ".DS_Store", "Thumbs.db"]
        items:
          type: 'string'
      excludeVcsIgnoredPaths:
        type: 'boolean'
        default: true
        title: 'Exclude VCS Ignored Paths'
      disabledPackages:
        type: 'array'
        default: []
        items:
          type: 'string'
      themes:
        type: 'array'
        default: ['atom-dark-ui', 'atom-dark-syntax']
        items:
          type: 'string'
      projectHome:
        type: 'string'
        default: path.join(fs.getHomeDirectory(), 'github')
      audioBeep:
        type: 'boolean'
        default: true
      destroyEmptyPanes:
        type: 'boolean'
        default: true
      fileEncoding:
        description: 'Default character set encoding to use when reading and writing files.'
        type: 'string'
        default: 'utf8'
        enum: [
          'cp437',
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
          'windows1258',
          'windows866'
        ]

  editor:
    type: 'object'
    properties:
      # These settings are used in scoped fashion only. No defaults.
      commentStart:
        type: ['string', 'null']
      commentEnd:
        type: ['string', 'null']
      increaseIndentPattern:
        type: ['string', 'null']
      decreaseIndentPattern:
        type: ['string', 'null']
      foldEndPattern:
        type: ['string', 'null']

      # These can be used as globals or scoped, thus defaults.
      fontFamily:
        type: 'string'
        default: ''
      fontSize:
        type: 'integer'
        default: 16
        minimum: 1
      lineHeight:
        type: ['string', 'number']
        default: 1.3
      showInvisibles:
        type: 'boolean'
        default: false
      showIndentGuide:
        type: 'boolean'
        default: false
      showLineNumbers:
        type: 'boolean'
        default: true
      autoIndent:
        type: 'boolean'
        default: true
        description: 'Automatically indent the cursor when inserting a newline'
      autoIndentOnPaste:
        type: 'boolean'
        default: true
      normalizeIndentOnPaste:
        type: 'boolean'
        default: true
      nonWordCharacters:
        type: 'string'
        default: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
      preferredLineLength:
        type: 'integer'
        default: 80
        minimum: 1
      tabLength:
        type: 'integer'
        default: 2
        enum: [1, 2, 3, 4, 6, 8]
      softWrap:
        type: 'boolean'
        default: false
      softTabs:
        type: 'boolean'
        default: true
      softWrapAtPreferredLineLength:
        type: 'boolean'
        default: false
      scrollSensitivity:
        type: 'integer'
        default: 40
        minimum: 10
        maximum: 200
      scrollPastEnd:
        type: 'boolean'
        default: false
      undoGroupingInterval:
        type: 'integer'
        default: 500
        minimum: 0
        description: 'Time interval in milliseconds within which operations will be grouped together in the undo history'
      useHardwareAcceleration:
        type: 'boolean'
        default: true
        description: 'Disabling will improve editor font rendering but reduce scrolling performance.'
      useShadowDOM:
        type: 'boolean'
        default: false
        title: 'Use Shadow DOM'
        description: 'Enable to test out themes and packages with the new shadow DOM before it ships by default.'
      confirmCheckoutHeadRevision:
        type: 'boolean'
        default: true
        title: 'Confirm Checkout HEAD Revision'
      invisibles:
        type: 'object'
        properties:
          eol:
            type: ['boolean', 'string']
            default: '\u00ac'
          space:
            type: ['boolean', 'string']
            default: '\u00b7'
          tab:
            type: ['boolean', 'string']
            default: '\u00bb'
          cr:
            type: ['boolean', 'string']
            default: '\u00a4'
      zoomFontWhenCtrlScrolling:
        type: 'boolean'
        default: process.platform isnt 'darwin'
        description: 'Increase/decrease the editor font size when pressing the Ctrl key and scrolling the mouse up/down.'

if process.platform in ['win32', 'linux']
  module.exports.core.properties.autoHideMenuBar =
    type: 'boolean'
    default: false
    description: 'Automatically hide the menu bar and toggle it by pressing Alt. This is only supported on Windows & Linux.'
