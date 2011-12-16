fs = require 'fs'

require 'spec-helper'
require path for path in fs.listDirectoryTree(require.resolve '.') when /-spec\.coffee$/.test path
