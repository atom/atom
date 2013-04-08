require 'window'

measure 'spec suite require time', ->
  fsUtils = require 'fs-utils'
  require 'spec-helper'

  # Run core specs
  for path in fsUtils.listTree(fsUtils.resolveOnLoadPath("spec")) when /-spec\.coffee$/.test path
    require path

  # Run extension specs
  for packageDirPath in config.packageDirPaths
    for packagePath in fsUtils.list(packageDirPath)
      for path in fsUtils.listTree(fsUtils.join(packagePath, "spec")) when /-spec\.coffee$/.test path
        require path
