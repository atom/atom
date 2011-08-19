
	// ObjC
	var nil = null
	var	YES	= true
	var NO	= false
	
	
	if ('OSX' in this)
	{
		var JSCocoaController	= OSX.JSCocoaController
		var NSApp				= null
	}

	
	function	log(str)	{	__jsc__.log_('' + str)	}
	// This one is because I can't bring myself to not typing alert. 
	function	alert(str)	{	log('********USE log(), not alert()*********'), log(str) }
	
	function	dumpHash(o)	{	var str = ''; for (var i in o) str += i + '=' + o[i] + '\n'; return str }
	
	//	
	//	ObjC type encodings
	//	http://developer.apple.com/mac/library/documentation/cocoa/conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
	//	
	//	  Used to write ObjC methods in Javascript
	//
	var types = ['char', 'int', 'short', 'long', 'long long', 'unsigned char', 'unsigned int', 'unsigned short', 'unsigned long',
				'unsigned long long', 'float', 'double', 'bool', 'void', 'char*', 'id', 'Class', 'selector', 'BOOL', 'void*',
				'NSInteger', 'NSUInteger', 'CGFloat'];
	var encodings = {}
	var l = types.length
	// Encodings are architecture dependent and were encoded at compile time, retrieve them now
	for (var i=0; i<l; i++)
	{
		var t = types[i]
		// use new String to convert from a boxed NSString to a Javascript string
		encodings[t] = new String(JSCocoaFFIArgument.typeEncodingForType_(t))
	}
	encodings['charpointer'] = encodings['char*']
	encodings['IBAction'] = encodings['void']
	
	var reverseEncodings = {}
	for (var e in encodings) reverseEncodings[encodings[e]] = e
	

	function	objc_unary_encoding(encoding)
	{
		// Remove protocol information 
		//		id<NSValidatedUserInterfaceItem> item
		//	->	id item
		encoding = encoding.replace(/\s*<\s*\w+\s*>\s*/, '').toString()


		// Structure arg
//		if (encoding.indexOf(' ') != -1 && encoding.indexOf('*') == -1)
		if (encoding.match(/struct \w+/))
		{
			var structureName = encoding.split(' ')[1]
			var structureEncoding = JSCocoaFFIArgument.structureFullTypeEncodingFromStructureName(structureName)
			if (!structureEncoding)	throw 'no encoding found for structure ' + structureName

			//
			// Remove names of variables to keep only encodings
			//
			//	{_NSPoint="x"f"y"f}
			//	becomes
			//	{_NSPoint=ff}
			//
//			JSCocoaController.log('*' + structureEncoding + '*' + String(String(structureEncoding).replace(/"[^"]+"/gi, "")) + '*')
			return String(String(structureEncoding).replace(/"[^"]+"/gi, ""))
		}
		else
		{
			if (!(encoding in encodings))	
			{
				// Pointer to an ObjC object ?
				var match = encoding.match(/^(\w+)\s*(\*+)$/)
				if (match)
				{
					var className = match[1]
					
					//
					// this[className]['class'] == this[className]
					//	can only work if each object is boxed only once : 
					//	both expressions will return the same object, comparing one object to itself
					//	-> true
					//
					//	BUT if both expressions each use their own box, comparison will come negative
					//
					var starCount = match[2].toString().length
					if (className in this && this[className]['class'] == this[className])	
					{
						// ** is a pointer to class
						return starCount > 1 ? '^@' : '@'
					}
					else
					if (starCount == 1)
					{
						var rawEncoding = encoding.replace(/\*/, '')
						rawEncoding = encodings[rawEncoding]
						if (rawEncoding)	return '^' + rawEncoding
					}
				}
				// Structure ?
				var structureEncoding = JSCocoaFFIArgument.structureFullTypeEncodingFromStructureName(encoding)
				if (structureEncoding)	return	String(String(structureEncoding).replace(/"[^"]+"/gi, ""))
				throw	'invalid encoding : "' + encoding + '"'
			}
			return encodings[encoding]
		}
	}

	function	objc_encoding()
	{
		var encoding = objc_unary_encoding(arguments[0])
		encoding += '@:'
		
		for (var i=1; i<arguments.length; i++)	
			encoding += objc_unary_encoding(arguments[i])
		return	encoding
	}





	//
	//	
	//	Define a class deriving from an ObjC class
	//	
	//	defineClass('ChildClass < ParentClass', 
	//		,'overloadedMethod:' :
	//						function (sel)
	//						{
	//							var r = this.Super(arguments)
	//							testClassOverload = true
	//							return	r
	//						}
	//		,'newMethod:' :
	//						['id', 'id', function (o)  // encoding + function
	//						{
	//							testAdd = true
	//							return o
	//						}]
	//		,'myOutlet' : 'IBOutlet'
	//		,'myAction' : ['IBAction', 
	//						function (sender)
	//						{
	//						}]
	//					
	//	})
	//
	//

	function	defineClass(inherit, methods)
	{
		var s = inherit.split('<')
		var className = s[0].replace(/ /gi, '')
		var parentClassName = s[1].replace(/ /gi, '')
		if (className.length == 0 || parentClassName.length == 0)	throw 'Invalid class definition : ' + inherit

		// Get parent class
		var parentClass = this[parentClassName]
		if (!parentClass)											throw 'Parent class ' + parentClassName + ' not found'
//		JSCocoaController.log('parentclass=' + parentClass)

		var newClass = JSCocoa.createClass_parentClass_(className, parentClassName)
		for (var method in methods)
		{
			var isInstanceMethod = parentClass.instancesRespondToSelector(method)
			var isOverload = parentClass.respondsToSelector(method) || isInstanceMethod
//			JSCocoaController.log('adding method *' + method + '* to ' + className + ' isOverload=' + isOverload + ' isInstanceMethod=' + isInstanceMethod)
			
			if (isOverload)
			{
				var fn = methods[method]
				if (!fn || (typeof fn) != 'function')	throw '(overloading) Method ' + method + ' not a function - when overloading, omit encodings as they will be inferred from the existing method'

				if (isInstanceMethod)	JSCocoa.overloadInstanceMethod_class_jsFunction_(method, newClass, fn)
				else					JSCocoa.overloadClassMethod_class_jsFunction_(method, newClass, fn)
			}
			else
			{
				// Extract encodings
				var encodings = methods[method]
				
				// IBOutlet
				if (encodings == 'IBOutlet')
				{
					class_add_outlet(newClass, method)
				}
				else
				// IBAction
				if (encodings.length == 2 && encodings[0] == 'IBAction' && (typeof encodings[1] == 'function'))
				{
					class_add_action(newClass, method, encodings[1])
				}
				else
				// Key
				if (encodings == 'Key')
				{
					class_add_key(newClass, method)
				}
				else
				// New method
				{
					if (typeof encodings != 'object' || !('length' in encodings))	throw 'Invalid definition of ' + method + ' in ' + inherit + ' ' + (typeof encodings) + ' ' + (encodings.length)

					// Extract method
					var fn = encodings.pop()
					if (!fn || (typeof fn) != 'function')	throw 'New method ' + method + ' not a function'
					
					var selectorArgumentCount	= (method.match(/:/g) || []).length
					var encodingsArgumentCount	= encodings.length-1
					if (selectorArgumentCount != encodingsArgumentCount)
						throw 'Argument count mismatch in defining ' + className + '.' + method + ' — encoding array has ' + encodingsArgumentCount + ', selector has ' + selectorArgumentCount
					
					var encoding = objc_encoding.apply(null, encodings)
					class_add_instance_method(newClass, method, fn, encoding)
				}
			}
		}
		return	newClass
	}
	
	
	
	//
	//
	// Shared class methods : call these at runtime to add outlets, methods, actions to an existing class
	// 
	// 
	
	//
	// Outlets are set as properties starting with an underscore, to avoid recursive call in setProperty
	//
	function	class_add_outlet(newClass, name, setter)
	{
		var outletMethod = 'set' + name.substr(0, 1).toUpperCase() + name.substr(1) + ':'
		var encoding = objc_encoding('void', 'id')

//		var fn = new Function('outlet', 'this.set({jsValue:outlet, forJsName : "_' + name + '"})')
		var fn = new Function('outlet', 'this.setJSValue_forJSName(outlet, "_' + name + '")')
		if (setter)	
		{
			if (typeof setter != 'function')	throw 'outlet setter not a function (' + setter + ')'
			fn = setter
		}
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(outletMethod, newClass, fn, encoding)

		var fn = new Function('return this.JSValueForJSName("_' + name + '")')
		var encoding = objc_encoding('id')
		
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(name, newClass, fn, encoding)					
	}
	
	//
	// Actions
	//
	function	class_add_action(newClass, name, fn)
	{
		if (name.charAt(name.length-1) != ':')	name += ':'
		var encoding = objc_encoding('void', 'id')
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(name, newClass, fn, encoding)					
	}
	
	//
	// Keys : used in bindings and valueForKey — given keyName, creates two ObjC methods (getter/setter) - (id) keyName and - (void) setKeyName
	// 
	function	class_add_key(newClass, name, getter, setter)
	{
		// Get
		var fn = new Function('return this.JSValueForJSName("_' + name + '")')
		if (getter)	
		{
			if (typeof getter != 'function')	throw 'key getter not a function (' + getter + ')'
			fn = getter
		}
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(name, newClass, fn, objc_encoding('id'))

		// Set
		var setMethod = 'set' + name.substr(0, 1).toUpperCase() + name.substr(1) + ':'
//		var fn = new Function('v', 'this.set({jsValue:v, forJsName : "' + name + '"})')
		var fn = new Function('outlet', 'this.setJSValue_forJSName(outlet, "_' + name + '")')
		if (setter)	
		{
			if (typeof setter != 'function')	throw 'key setter not a function (' + setter + ')'
			fn = setter
		}
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(setMethod, newClass, fn, objc_encoding('void', 'id'))
	}
	
	//
	// Vanilla instance method add. Wrapper for JSCocoaController's addInstanceMethod
	// 
	function	class_add_instance_method(newClass, name, fn, encoding)
	{
		JSCocoa.addInstanceMethod_class_jsFunction_encoding_(name, newClass, fn, encoding)
	}
	//
	// Vanilla class method add. Wrapper for JSCocoaController's addClassMethod
	// 
	function	class_add_class_method(newClass, name, fn, encoding)
	{
		JSCocoa.addClassMethod_class_jsFunction_encoding_(name, newClass, fn, encoding)
	}
	
	//
	// Swizzlers !
	//
	function	class_swizzle_instance_method(newClass, name, fn)
	{
		JSCocoa.swizzleInstanceMethod_class_jsFunction_(name, newClass, fn)
	}
	function	class_swizzle_class_method(newClass, name, fn)
	{
		JSCocoa.swizzleClassMethod_class_jsFunction_(name, newClass, fn)
	}
	
	//
	// Add raw javascript method
	//	__globalJSFunctionRepository__ holds [className][jsFunctionName] = fn
	if (!this.__globalJSFunctionRepository__)	var __globalJSFunctionRepository__ = {}
	function	class_add_js_function(newClass, name, fn)
	{
		var className = String(newClass)
		if (!__globalJSFunctionRepository__[className])	__globalJSFunctionRepository__[className] = {}
		__globalJSFunctionRepository__[className][name] = fn
	}

	
	
	//
	//
	//	Second kind of class definitions
	//	http://code.google.com/p/jscocoa/issues/detail?id=19
	//
	//
	
	// React on set
	function	class_set_definition(definition)
	{
		__classHelper__.methods = {}
		__classHelper__.outlets = {}
		__classHelper__.actions = {}
		__classHelper__.keys = {}
		__classHelper__.jsFunctions = {}
		definition()
		class_create_from_helper(__classHelper__)
	}
	function	class_create_from_helper(h)
	{
		var inherit = h.className
		var s = inherit.split('<')

		// Adding methods to an existing class
		if (s.length == 1)
		{
			var className = s[0].replace(/ /gi, '')
			var newClass = this[className]
			if (!newClass)	throw 'Adding methods to unknown class (' + inherit + ')'
		}
		else
		// 
		{
			if (s.length != 2)	throw 'New class must specify parent class name (' + inherit + ')'
			var className = s[0].replace(/ /gi, '')
			var parentClassName = s[1].replace(/ /gi, '')
			if (className.length == 0 || parentClassName.length == 0)	throw 'Invalid class definition : ' + inherit

			// Get parent class
			var parentClass = this[parentClassName]
			if (!parentClass)											throw 'Parent class ' + parentClassName + ' not found'
			var newClass = JSCocoa.createClass_parentClass_(className, parentClassName)
		}
		
		// Add outlets, actions and keys before methods as methods could override outlet setters and getters

		//
		// Outlets
		//
		for (var outlet in h.outlets)
			class_add_outlet(newClass, outlet, h.outlets[outlet].setter)

		//
		// Actions
		//
		for (var action in h.actions)
			class_add_action(newClass, action, h.actions[action])

		//
		// Keys
		//
		for (var key in h.keys)
			class_add_key(newClass, key, h.keys[key].getter, h.keys[key].setter)

		//
		// Overloaded and new methods
		//
		for (var method in h.methods)
		{
//			log('method.type=' + h.methods[method].type + ' ' + method)
			var isInstanceMethod = parentClass ? parentClass.instancesRespondToSelector(method) : false
			var isOverload = parentClass ? parentClass.respondsToSelector(method) || isInstanceMethod : false
//			JSCocoaController.log('adding method *' + method + '* to ' + className + ' isOverload=' + isOverload + ' isInstanceMethod=' + isInstanceMethod)
			
			// Swizzling cancels overloading
			if (h.methods[method].swizzle)
			{
				var fn = h.methods[method].fn
				if (!fn || (typeof fn) != 'function')	throw 'Swizzled method ' + method + ' not a function'
				if (h.methods[method].type == 'class method')	class_swizzle_class_method(newClass, method, fn)
				else											class_swizzle_instance_method(newClass, method, fn)
			}
			else			
			if (isOverload)
			{
				var fn = h.methods[method].fn
				if (!fn || (typeof fn) != 'function')	throw 'Method ' + method + ' not a function'

				if (isInstanceMethod)	JSCocoa.overloadInstanceMethod_class_jsFunction_(method, newClass, fn)
				else					JSCocoa.overloadClassMethod_class_jsFunction_(method, newClass, fn)
			}
			else
			{
				// Extract method
				var fn = h.methods[method].fn
				if (!fn || (typeof fn) != 'function')	throw 'New method ' + method + ' not a function'

				var encodings = h.methods[method].encodingArray || h.methods[method].encoding.split(' ')
				var encoding = objc_encoding.apply(null, encodings)
//				log('encoding='  + encoding + ' class=' + newClass + ' method=' + method)
				if (h.methods[method].type == 'class method')	class_add_class_method(newClass, method, fn, encoding)
				else											class_add_instance_method(newClass, method, fn, encoding)
			}
		}
			
		//
		// JS Functions
		//
		for (var f in h.jsFunctions)
			class_add_js_function(newClass, f, h.jsFunctions[f])
	}
	function	class_set_encoding(encoding)
	{
		__classHelper__.methods[__classHelper__.name].encoding = encoding
		return	__classHelper__
	}
	function	class_set_encoding_array(encodingArray)
	{
		__classHelper__.methods[__classHelper__.name].encodingArray = encodingArray
		return	__classHelper__
	}
	function	class_set_function(fn)
	{
		// Method
		if (__classHelper__.type == 'method')				__classHelper__.methods[__classHelper__.name].fn = fn
		// Action
		else	if (__classHelper__.type == 'action')		__classHelper__.actions[__classHelper__.name] = fn
		// Function
		else	if (__classHelper__.type == 'jsFunction')	__classHelper__.jsFunctions[__classHelper__.name] = fn
	}

	function	class_set_setter(fn)
	{
		// Outlet
		if (__classHelper__.type == 'outlet')	__classHelper__.outlets[__classHelper__.name].setter = fn
		// Key
		else									__classHelper__.keys[__classHelper__.name].setter = fn
	}
	function	class_set_getter(fn)
	{
		__classHelper__.keys[__classHelper__.name].getter = fn
	}

	// Definition functions
	function	Class(name)
	{
		__classHelper__.className = name
		return	__classHelper__
	}
	function	Method(name)
	{
		__classHelper__.type 	= 'method'
		__classHelper__.name	= name
		__classHelper__.methods[__classHelper__.name] = { type : 'method' }
		return	__classHelper__
	}
	function	ClassMethod(name)
	{
		__classHelper__.type 	= 'method'
		__classHelper__.name	= name
		__classHelper__.methods[__classHelper__.name] = { type : 'class method' }
		return	__classHelper__
	}
	function	SwizzleMethod(name)
	{
		__classHelper__.type 	= 'method'
		__classHelper__.name	= name
		__classHelper__.methods[__classHelper__.name] = { type : 'method', swizzle : true }
		return	__classHelper__
	}
	function	SwizzleClassMethod(name)
	{
		__classHelper__.type 	= 'method'
		__classHelper__.name	= name
		__classHelper__.methods[__classHelper__.name] = { type : 'class method', swizzle : true }
		return	__classHelper__
	}
	function	JSFunction(name)
	{
		__classHelper__.type 	= 'jsFunction'
		__classHelper__.name	= name
		return	__classHelper__
	}
	function	IBAction(name)
	{
		__classHelper__.type	= 'action'
		__classHelper__.name	= name
		return	__classHelper__
	}
	function	IBOutlet(name)
	{
		__classHelper__.type	= 'outlet'
		__classHelper__.name	= name
		__classHelper__.outlets[name] = {}
		return	__classHelper__
	}
	function	Key(name)
	{
		__classHelper__.type	= 'key'
		__classHelper__.name	= name
		if (!__classHelper__.keys[name])	__classHelper__.keys[name] = {}
		return	__classHelper__
	}


	// Shadow object collecting class definition data
	var __classHelper__ = { encoding : class_set_encoding, encodingArray : class_set_encoding_array }
	__classHelper__.__defineSetter__('definition',	class_set_definition)
	__classHelper__.__defineSetter__('fn', 			class_set_function)
	__classHelper__.__defineSetter__('getter',		class_set_getter)
	__classHelper__.__defineSetter__('setter',		class_set_setter)
	
	
	// Running ObjC GC ?
	var hasObjCGC = false
	if (('NSGarbageCollector' in this) && !!NSGarbageCollector.defaultCollector) hasObjCGC = true
	
	
	function	loadFramework(name)
	{
		__jsc__.loadFrameworkWithName(name)
	}
	
	
	//
	// Describe struct
	//	(Test 28)
	//	point = new CGPoint(12, 27)
	//	describeStruct(point)
	//	-> <CGPoint {x:12, y:27}>
	//
	function	describeStruct(o, level)
	{
		if (level == undefined)	level = 0
		// Bail if structure contains a cycle
		if (level > 100)		return ''
		
		var str = ''
		if (typeof(o) == 'object' || typeof(o) == 'function')
		{
			str += '{'
			var elements = []
			for (var i in o)
				elements.push(i + ':' + describeStruct(o[i], level+1))
			str += elements.join(', ')
			str += '}'
		}
		else
			str += o

		return	str
	}
	

	//
	// type o
	//
	function	outArgument()
	{
		// Derive to store some javascript data in the internal hash
		if (!('outArgument2' in this))
			JSCocoa.createClass_parentClass_('JSCocoaOutArgument2', 'JSCocoaOutArgument')

		var o = JSCocoaOutArgument2.instance
		o.isOutArgument = true
		if (arguments.length == 2)	o.mateWithMemoryBuffer_atIndex_(arguments[0], arguments[1])

		return	o
	}

	
	function	memoryBuffer(types)
	{
		var o = JSCocoaMemoryBuffer.instanceWithTypes(types)
		o.isOutArgument = true
		return	o
	}


	//
	// Dump the call stack with arguments.calle.caller (Called from JSCocoa)
	//	
	//	Eric Wendelin's Javascript stacktrace in any browser
	//	http://eriwen.com/javascript/js-stack-trace/
	//
	function	dumpCallStack()
	{
		var maxDumpDepth = 100
		var dumpDepth = 0
		var caller = arguments.callee.caller
		// Skip ourselves
		caller = caller.caller

		// Build call stack
		var stack = []
		while (caller && dumpDepth < maxDumpDepth)
		{
			var fn = caller.toString()
			var fname = fn.substring(fn.indexOf("function") + 9, fn.indexOf("(")) || "anonymous";
			var str = fname
			if (caller.arguments.length)
			{
				str += ' ('
				for (var i=0; i<caller.arguments.length; i++)	
				{
					str += caller.arguments[i]
					if (i < caller.arguments.length-1)
						str += ', '
				}
				str += ')'
			}
//			if (caller.arguments.length) str += caller.arguments.join(',')
			stack.push(str)
			dumpDepth++
			caller = caller.caller
		}
		
		// Dump call stack
		var str = ''
		for (var i=0; i<stack.length; i++)
			str += '(' + (stack.length-i) + ') ' + stack[i] + '\n'
		return str
	}
	

	// JSLint
	function	__logToken(token)
	{
		__lintTokens.push(token)
	}
	if (!('JSLintWithLogs' in this))	JSLintWithLogs = function () { return function () {} }
	var __JSLINT = JSLintWithLogs({ logToken : __logToken })
	var __jslint = __JSLINT()
	var __lintTokens

	//
	// Expand script, log errors into errorArray (or to console if there are none)
	//
	function	expandJSMacros(script, scriptURL, errorArray)
	{
		if (!__jslint)
			return null
		__lintTokens = []
		var lines	= script.split('\n')
		var options	= { forin : true, laxbreak : true, indent : true, evil : true }
		var lintRes	= __jslint(lines, options)
		var str = 'LINT=' + lintRes
		for (var i=0; i<__JSLINT.errors.length; i++)
		{
			var e = __JSLINT.errors[i]
			if (!e)	continue
			var error				= 'JSLint error'
			if (scriptURL)
				error += ' in ' + scriptURL + ' '
																								
			error += '(' + e.line + ', ' + e.character + ')=' + e.reason
			var errorLine			= lines[e.line]
			var str = ''
			for (var j=0; j<e.character-1; j++) str += ' '
			str += '^'
			var errorPosition		= str
			if (errorArray)
			{
				var o =  { error : error } 
				if (errorLine)	o.line = errorLine, o.position = errorPosition
				errorArray.addObject(o)
			}
			else
			{
				log(error)
				log(errorLine)
				log(errorPosition)
			}
		}
		var useAutoCall = __jsc__.useAutoCall
		if (typeof useAutoCall === 'function') useAutoCall = __jsc__.useAutoCall()


		var tokens = __lintTokens

		var str	= ''
		var str2 = ''
		var currentParameterCount
		var tokenStream		= []
		var token, prevtoken= tokens[0]
		for (var i=0; i<tokens.length; i++)
		{
			token = tokens[i]
			var v = tv = token.rawValue
			
			if (token.id == '(endline)')
			{
				tokenStream.push('\n')
				continue
			}
			var line = lines[token.line]
			if (!line) continue
			
			// Add whitespace - either the start of the line if we switched lines, or the span between this token and the previous one
			var whitespace = prevtoken.line != token.line ? line.substr(0, token.from) : line.substr(prevtoken.character, token.from-prevtoken.character)
			tokenStream.push(String(whitespace.match(/\s*/)))

			prevtoken = token

			// Handle shortcut function token
			if (token.value == 'ƒ')
			{
				token.rawValue = 'function'
				
				// Add parens if they're missing
				if (tokens[i+1].type == '(identifier)')
				{
					if (tokens[i+2].value != '(')	tokens[i+1].rawValue += '()'
				}
				else
					if (tokens[i+1].value != '(')	tokens[i].rawValue += '()'
			}
			else if (token.value == '__FILE__' || token.value == '__LINE__')
			{
				var v = token.value == '__FILE__' ? 'sourceURL' : 'line'
				token.rawValue = 'function(){try{throw{}}catch(e){return e.' + v + '}}()'
			}

			// Handle ObjC classes
			if (token.isObjCClassStart)
			{
				if (tokens[i+2].value == '<' || tokens[i+2].value == ':')
				{
					tokenStream.push("Class('" + tokens[i+1].value + ' < ' + tokens[i+3].value + "').definition = function ()")
					i += 3
				}
				else
				{
					tokenStream.push("Class('" + tokens[i+1].value + "').definition = function ()")
					i += 1
				}
				if (token.value == '@implementation')	tokenStream.push('{\n')
				continue
			}
			// Class var list @implementation Class : ParentClass { var list }
			if (token.isObjCVarList)
			{
				while (token && token.value != '}')
				{
					i++
					token = tokens[i]
					if (!token)	return false
				}
				i++
				continue
			}
			// Class category
			if (token.isObjCCategory)
			{
				while (token && token.value != ')')
				{
					i++
					token = tokens[i]
					if (!token)	return false
				}
				i++
				continue
			}
			// Handle ObjC methods
			if (token.isObjCClassItemStart)
			{
				var methodToken = token
				var dataHolder = token
				var isSwizzle = false
				if (token.value.toLowerCase() == 'swizzle')
				{
					methodToken = token = tokens[++i]
					isSwizzle = true
				}
				// Method start
				if (token.value == '-' || token.value == '+')
				{
					// Skip method definition
					while (tokens[i+1] && tokens[i+1].value != '{')
						i++

					var str = "('" + dataHolder.objCMethodName + "').encodingArray([" + dataHolder.objCMethodEncodings + "]).fn = function (" + dataHolder.objCMethodParamNames + ")"
					str = (isSwizzle ? 'Swizzle' : '') + (methodToken.value == '-' ? 'Method' : 'ClassMethod') + str
					tokenStream.push(str)
					continue
				}
				else
				// Outlet
				if (token.value == 'IBOutlet')
				{
					tokenStream.push("IBOutlet('" + tokens[i+1].value + "')")
					if (tokens[i+2].value == '(')
					{
						tokenStream.push('.setter = function (' + tokens[i+3].value + ')')
						i += 3
					}
					i += 1
					continue
				}
				else
				// Action
				if (token.value == 'IBAction')
				{
					var actionName = tokens[i+1].value
					
					var paramName = 'sender'
					if (tokens[i+2].value == '(')
					{
						paramName = tokens[i+3].value
						i += 3
					}

					tokenStream.push("IBAction('" + actionName + "').fn = function (" + paramName + ")")
					i += 1
					continue
				}
				else
				// Key
				if (token.value == 'Key')
				{
					tokenStream.push("Key('" + tokens[i+1].value + "')")
					i += 1
					continue
				}
				else
				// js function
				if (token.isClassJSFunction)
				{
					tokenStream.push("JSFunction('" + token.jsFunctionName.rawValue + "').fn = ")
					token.jsFunctionName.rawValue = ''
				}
			}
			else
			// String immediates
			if (token.id == '@')
			{
				var nexttoken = tokens[i+1]
				// This can start a message : [@'hello' writeTo...]
				tokenStream.push('NSString.stringWithString(' + nexttoken.rawValue + ')')
				// Delete string token
				nexttoken.rawValue = ''
				continue
			}
			else
			// Selectors
			if (token.id == '@selector')
			{
				tokenStream.push("'" + tokens[i+2].rawValue + "'")
				i += 3
				continue						
			}
			else
			// Class definition ending
			if (token.value == '@end')
			{
				i++
				tokenStream.push('}\n')
				continue
			}
			else
			// setValueForKey shortcut
			if (token.id == '@=')
			{
				function	backtrack(stream, tokenIndex, search)
				{
					var i = tokenIndex
					var match
					var matchIndex
					var counterpart
					var leftCount	= 0
					var rightCount	= 0
					for (; i>0; i--)
					{
						// Look for token
						if (!match && search[stream[i]])
						{
							match = stream[i]
							if (typeof search[stream[i]] == 'string')	counterpart = search[stream[i]]
							matchIndex = i
							if (!counterpart)	return { left : i, right : tokenIndex }
						}
						if (stream[i] == match)			rightCount++
						if (stream[i] == counterpart)	leftCount++
						if (leftCount > 0 && leftCount == rightCount)	return { left : i, right : matchIndex }
					}
					return { left : -1, right : -1 }
				}
				
				function	trackRightFromOperator(stream, tokenIndex, operator)
				{
					var right = operator.right
					var lastToken
					while (right)
					{
						lastToken = right
						right = right.rightParen || right.right
					}
					if (!lastToken)	return -1
					var l = stream.length-1
					for (; tokenIndex<l; tokenIndex++)
						if (stream[tokenIndex] == lastToken)	return tokenIndex
					return -1
				}
				
				var idx1 = backtrack(tokenStream, tokenStream.length-1, { '.' : true, ']' : '[' })
				var idx2 = trackRightFromOperator(tokens, i, token)
				var left = tokenStream[idx1.left]
				var right= tokens[idx2]

				// Reconstruct key name
				var key = ''
				for (var j=idx1.left+1; j<idx1.right; j++)
				{
					if (left == '[')	key += tokenStream[j]
					else
						if (!tokenStream[j].match(/(\/\*)|^\s*$/))	
							key += "'" + tokenStream[j] + "'"
				}

				// Delete key from output stream
				for (var j=idx1.left; j<=idx1.right; j++)
					tokenStream[j] = ''
				
				// Patch key in input stream
				tokens.splice(idx2+1, 0, { rawValue : ' ,' + key + ')', line : right.line })

				// Convert @= to setValue:forKey:
				tokenStream.push('.setValue_forKey_(')
				continue
			}
			else
			// If return
			if (token.isIfReturn)
			{
				token.isIfReturn = false
				
				var j = i
				var returnOpenerIndex = i-1
				// Skip return tokens
				while (tokens[j+1] && !tokens[j+1].isIfReturnOpener) j++
				var ifReturnOpenerIndex = j+1
				// Skip if tokens
				while (tokens[j] && !tokens[j].isIfReturnCloser) j++
				var ifReturnCloserIndex = j
				
				// Switch unless (...) to if (!(...))
				if (tokens[ifReturnOpenerIndex].value == 'unless')
				{
					tokens[ifReturnOpenerIndex].rawValue = 'if'
					tokens[ifReturnOpenerIndex+1].rawValue = '(!' + tokens[ifReturnOpenerIndex+1].rawValue
					tokens[ifReturnCloserIndex].rawValue += ')'
				}

				// Splice : delete index, delete item count, replacement
				var r = tokens.splice(i, ifReturnOpenerIndex-returnOpenerIndex-1)

				// Push delete item count and delete index on top of replacing tokens
				r.unshift(0)
				r.unshift(i+ifReturnCloserIndex-ifReturnOpenerIndex+1)
				Array.prototype.splice.apply(tokens, r)

				token = tokens[i]
			}

			var v = token.rawValue
			//
			// ObjC message handling
			//
			
			// Skip '[' and ':'
			if (token.isObjCCallOpener || token.isObjCParameterSeparator) continue

			if (token.isObjCCallCloser && token.isObjCFirstCall) v = ''

			// Instance : add '.' to get method
			if (token.isObjCFirstCall)
			{
				if (token.isObjCSuperCall)	v = 'this.' + (token.value=='super'?'Super':'Original') + '(arguments, '
				currentParameterCount = token.objCParameterCountOpener
				// Special case for 'class', must be bracketed ['class']
				if (tokens[i+1].rawValue != 'class' && !token.isObjCSuperCall)
					v += '.'
			}
			// Special case for class
			if (token.isObjCCall && token.rawValue == 'class')	v = "['class']"
			// First selector part : retrieve full selector name
			if (token.isObjCFirstParam)
			{
				if (currentParameterCount)
				{
					v = token.objCJSSelector
					if (token.isObjCSuperCall)	v = "'" + v.replace(/_/g, ':') + "', new Array"
					v += '('
				}
				else
				{
					if (token.isObjCSuperCall)	v = "'" + v + "'" + ', new Array()'
					else
					if (!useAutoCall)			v += '()'
				}
			}
			// Selector part : ignore name and add ',' separator
			if (token.isObjCMultiCall)
			{
				v = ''
				if (!token.isObjCCallCloser) 
					v += ','
			}
			// Ignore ']', add ')' if we're closing a parameter message
			if (token.isObjCCallCloser)
			{
				if (!token.isObjCFirstCall)
					v = ''
				if (token.objCParameterCountCloser)
					v = ')' + (v||'')
				if (token.isObjCSuperCall) v += ')'
			}
			tokenStream.push(v)
		}
		var transformed = tokenStream.join('')
//		log('Transformed' + script + '->' + transformed)
		return	transformed
	}
