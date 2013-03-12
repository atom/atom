fs = require 'fs-utils'
require 'spec-helper'


# Run core specs
for path in fs.listTree(require.resolve("spec")) when /-spec\.coffee$/.test path
  require path

# Run extension specs
for packageDirPath in config.packageDirPaths
  for packagePath in fs.list(packageDirPath)
    for path in fs.listTree(fs.join(packagePath, "spec")) when /-spec\.coffee$/.test path
      require path
