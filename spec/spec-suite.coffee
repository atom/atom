fs = require 'fs'
require 'spec-helper'

# Run extension specs
for extensionPath in fs.listTree(require.resolve("extensions"))
  for path in fs.listTree(fs.join(extensionPath, "spec")) when /-spec\.coffee$/.test path
    require path

# Run core specs
for path in fs.listTree(require.resolve("spec")) when /-spec\.coffee$/.test path
  require path

