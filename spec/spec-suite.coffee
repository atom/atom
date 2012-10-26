fs = require 'fs'
require 'spec-helper'

# Run core specs
for path in fs.listTree(require.resolve("spec")) when /-spec\.coffee$/.test path
  require path

# Run extension specs
for extensionPath in fs.listTree(require.resolve("src/extensions"))
  for path in fs.listTree(fs.join(extensionPath, "spec")) when /-spec\.coffee$/.test path
    require path
