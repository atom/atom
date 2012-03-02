fs = require 'fs'
require 'spec-helper'

require path for path in fs.listTree(atom.loadPath + "/spec") when /-spec\.coffee$/.test path
