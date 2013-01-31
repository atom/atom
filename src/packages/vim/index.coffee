DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class Tree extends DeferredAtomPackage

  loadEvents: [
    'vim:activate'
  ]

  instanceClass: 'vim/src/vim'