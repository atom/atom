# This is where we put things from JSCocoa's class.js file

exports.outArgument = (args...) ->
  # Derive to store some javascript data in the internal hash
  if not @outArgument2?
    OSX.JSCocoa.createClass_parentClass_('JSCocoaOutArgument2', 'JSCocoaOutArgument')

  console.log(OSX.JSCocoaOutArgument2)
  o = OSX.JSCocoaOutArgument2.instance
  o.isOutArgument = true
  if args.length == 2
    o.mateWithMemoryBuffer_atIndex_(args[0], args[1])

  o

