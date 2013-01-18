require 'atom'
atom.show()
{runSpecSuite} = require 'jasmine-helper'

document.title = "Spec Suite"
runSpecSuite "spec-suite"
