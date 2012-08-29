fs = require('fs')

atom.configDirPath = fs.absolute("~/.atom")
atom.configFilePath = fs.join(atom.configDirPath, "atom.coffee")
atom.open = (args...) -> @sendMessageToBrowserProcess('open', args)
atom.newWindow = (args...) -> @sendMessageToBrowserProcess('newWindow', args)
