require 'window'

measure 'spec suite require time', ->
  fsUtils = require 'fs-utils'
  path = require 'path'
  require 'spec-helper'

  # Run core specs
  for specPath in fsUtils.listTree(fsUtils.resolveOnLoadPath("spec")) when /-spec\.coffee$/.test specPath
    require specPath

  # Run extension specs
  for packageDirPath in config.packageDirPaths
    for packagePath in fsUtils.listSync(packageDirPath)
      for specPath in fsUtils.listTree(path.join(packagePath, "spec")) when /-spec\.coffee$/.test specPath
        require specPath
