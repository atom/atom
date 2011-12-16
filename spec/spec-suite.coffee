fs = require 'fs'

window.app = new (require 'app')

require path for path in fs.listDirectoryTree(require.resolve '.') when /-spec\.coffee$/.test path
