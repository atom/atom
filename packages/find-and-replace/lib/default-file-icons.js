const fs = require('fs-plus')
const path = require('path')

class DefaultFileIcons {
  iconClassForPath (filePath) {
    const extension = path.extname(filePath)

    if (fs.isSymbolicLinkSync(filePath)) {
      return 'icon-file-symlink-file'
    } else if (fs.isReadmePath(filePath)) {
      return 'icon-book'
    } else if (fs.isCompressedExtension(extension)) {
      return 'icon-file-zip'
    } else if (fs.isImageExtension(extension)) {
      return 'icon-file-media'
    } else if (fs.isPdfExtension(extension)) {
      return 'icon-file-pdf'
    } else if (fs.isBinaryExtension(extension)) {
      return 'icon-file-binary'
    } else {
      return 'icon-file-text'
    }
  }
}

module.exports = new DefaultFileIcons()
