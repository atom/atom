fs = require 'fs'
require 'spec-helper'

require path for path in fs.listTree(window.resourcePath + "/spec") when /-spec\.coffee$/.test path
