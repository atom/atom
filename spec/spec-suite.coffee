fs = require 'fs'
require 'spec-helper'

# Run core specs
for path in fs.listTree(require.resolve("spec")) when /-spec\.coffee$/.test path
  require path

# Run extension specs
for packagePath in fs.listTree(require.resolve("src/packages"))
  for path in fs.listTree(fs.join(packagePath, "spec")) when /-spec\.coffee$/.test path
    require path
