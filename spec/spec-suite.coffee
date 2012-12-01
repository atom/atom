fs = require 'fs'
require 'spec-helper'

# Run core specs
for path in fs.readTree(require.resolve("spec")) when /-spec\.coffee$/.test path
  require path

# Run extension specs
for extensionPath in fs.readTree(require.resolve("src/extensions"))
  for path in fs.readTree(fs.join(extensionPath, "spec")) when /-spec\.coffee$/.test path
    require path
