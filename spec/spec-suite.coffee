fs = require 'fs'
path = require 'path'
walkdir = require 'walkdir'
require 'spec-helper'

# Run core specs
for path in walkdir.sync('./spec') when /-spec\.coffee$/.test path
  require path

# Run extension specs
# for path in walkdir.sync('src/extensions') when /-spec\.coffee$/.test path
#   require path
