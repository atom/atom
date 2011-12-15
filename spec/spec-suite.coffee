fs = require 'fs'
require path for path in fs.listDirectoryTree(require.resolve '.') when /-spec\.coffee$/.test path
