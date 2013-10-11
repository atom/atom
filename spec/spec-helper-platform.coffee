path = require 'path'
fsUtils = require '../src/fs-utils'

{_} = require 'atom'

## Platform specific helpers
module.exports =
  # Public: Returns true if being run from within Windows
  isWindows: ->
    !!process.platform.match /^win/

  # Public: Some files can not exist on Windows filesystems, so we have to
  # selectively generate our fixtures.
  #
  # Returns nothing.
  generateEvilFiles: ->
    evilFilesPath = path.join(__dirname, 'fixtures', 'evil-files')
    fsUtils.remove(evilFilesPath) if fsUtils.exists(evilFilesPath)
    fsUtils.mkdirSync(evilFilesPath)

    if (@isWindows())
      filenames = [
        "a_file_with_utf8.txt",
        "file with spaces.txt",
        "utfa\u0306.md"
      ]
    else
      filenames = [
        "a_file_with_utf8.txt",
        "file with spaces.txt",
        "goddam\nnewlines",
        "quote\".txt",
        "utfa\u0306.md"
      ]

    for filename in filenames
      fd = fsUtils.writeFileSync(path.join(evilFilesPath, filename), 'evil file!', flag: 'w')

