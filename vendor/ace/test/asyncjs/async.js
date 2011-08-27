/*!
 * async.js
 * Copyright(c) 2010 Fabian Jakobs <fabian.jakobs@web.de>
 * MIT Licensed
 */

define(function(require, exports, module) {

var STOP = exports.STOP = {}

exports.Generator = function(source) {
    if (typeof source == "function")
        this.source = {
            next: source
        }
    else
        this.source = source
}

;(function() {
    this.next = function(callback) {
        this.source.next(callback)
    }

    this.map = function(mapper) {
        if (!mapper)
            return this
            
        mapper = makeAsync(1, mapper)
        
        var source = this.source
        this.next = function(callback) {
            source.next(function(err, value) {
                if (err)
                    callback(err)
                else {
                    mapper(value, function(err, value) {
                        if (err)
                            callback(err)
                        else
                            callback(null, value)
                    })
                }
            })
        }
        return new this.constructor(this)
    }
    
    this.filter = function(filter) {
        if (!filter)
            return this
            
        filter = makeAsync(1, filter)
        
        var source = this.source
        this.next = function(callback) {
            source.next(function handler(err, value) {
                if (err)
                    callback(err)
                else {
                    filter(value, function(err, takeIt) {
                        if (err)
                            callback(err)
                        else if (takeIt)
                            callback(null, value)
                        else
                            source.next(handler)
                    })
                }
            })
        }
        return new this.constructor(this)
    }

    this.slice = function(begin, end) {
        var count = -1
        if (!end || end < 0)
            var end = Infinity
        
        var source = this.source
        this.next = function(callback) {
            source.next(function handler(err, value) {
                count++
                if (err)
                    callback(err)
                else if (count >= begin && count < end)
                    callback(null, value)
                else if (count >= end)
                    callback(STOP)
                else
                    source.next(handler)
            })
        }
        return new this.constructor(this)
    }
    
    this.reduce = function(reduce, initialValue) {
        reduce = makeAsync(3, reduce)

        var index = 0
        var done = false
        var previousValue = initialValue
        
        var source = this.source
        this.next = function(callback) {
            if (done)
                return callback(STOP)

            if (initialValue === undefined) {
                source.next(function(err, currentValue) {
                    if (err)
                        return callback(err, previousValue)
                    
                    previousValue = currentValue
                    reduceAll()
                })
            }
            else
                reduceAll()

            function reduceAll() {
                source.next(function handler(err, currentValue) {                    
                    if (err) {
                        done = true
                        if (err == STOP)                            
                            return callback(null, previousValue)
                        else
                            return(err)
                    }
                    reduce(previousValue, currentValue, index++, function(err, value) {
                        previousValue = value
                        source.next(handler)
                    })
                })
            }            
        }
        return new this.constructor(this)
    }
    
    this.forEach =
    this.each = function(fn) {
        fn = makeAsync(1, fn)
            
        var source = this.source
        this.next = function(callback) {
            source.next(function handler(err, value) {
                if (err) 
                    callback(err)
                else {
                    fn(value, function(err) {
                        callback(err, value)
                    })
                }
            })
        }
        return new this.constructor(this)
    }
    
    this.some = function(condition) {
        condition = makeAsync(1, condition)
        
        var source = this.source
        var done = false
        this.next = function(callback) {
            if (done)
                return callback(STOP)
            
            source.next(function handler(err, value) {
                if (err)
                    return callback(err)
                    
                condition(value, function(err, result) {
                    if (err) {
                        done = true
                        if (err == STOP)
                            callback(null, false)
                        else
                            callback(err)
                    }                        
                    else if (result) {
                        done = true
                        callback(null, true)
                    }
                    else 
                        source.next(handler)
                })
            })
        }
        return new this.constructor(this)
    }
    
    this.every = function(condition) {
        condition = makeAsync(1, condition)
        
        var source = this.source
        var done = false
        this.next = function(callback) {
            if (done)
                return callback(STOP)
            
            source.next(function handler(err, value) {
                if (err)
                    return callback(err)
                    
                condition(value, function(err, result) {
                    if (err) {
                        done = true
                        if (err == STOP)
                            callback(null, true)
                        else
                            callback(err)
                    }                        
                    else if (!result) {
                        done = true
                        callback(null, false)
                    }
                    else 
                        source.next(handler)
                })
            })
        }
        return new this.constructor(this)
    }
    
    this.call = function(context) {
        var source = this.source
        return this.map(function(fn, next) {
            fn = makeAsync(0, fn, context)
            fn.call(context, function(err, value) {
                next(err, value)
            })
        })
    }
    
    this.concat = function(generator) {
        var generators = [this]
        generators.push.apply(generators, arguments)
        var index = 0
        var source = generators[index++]
        
        return new this.constructor(function(callback) {            
            source.next(function handler(err, value) {
                if (err) {
                    if (err == STOP) {
                        source = generators[index++]
                        if (!source)
                            return callback(STOP)
                        else
                            return source.next(handler)
                    }
                    else
                        return callback(err)
                }
                else
                    return callback(null, value)
            })
        })
    }
    
    this.zip = function(generator) {
        var generators = [this]
        generators.push.apply(generators, arguments)
        
        return new this.constructor(function(callback) {
            exports.list(generators)
                .map(function(gen, next) {                    
                    gen.next(next)
                })
                .toArray(callback)
        })
    }
    
    this.expand = function(inserter, constructor) {
       if (!inserter)
            return this
            
        var inserter = makeAsync(1, inserter)
        var constructor = constructor || this.constructor
        var source = this.source;
        var spliced = null;
        
        return new constructor(function next(callback) {
            if (!spliced) {
                source.next(function(err, value) {
                    if (err)
                        return callback(err)
                        
                    inserter(value, function(err, toInsert) {
                        if (err)
                            return callback(err)
                            
                        spliced = toInsert                        
                        next(callback)
                    })

                })
            } 
            else {
                spliced.next(function(err, value) {
                    if (err == STOP) {
                        spliced = null
                        return next(callback)
                    }
                    else if (err)
                        return callback(err)
                    
                    callback(err, value)
                })
            }
        })
    }

    this.sort = function(compare) {
        var self = this
        var arrGen
        this.next = function(callback) {
            if (arrGen)
                return arrGen.next(callback)

            self.toArray(function(err, arr) {
                if (err)
                    callback(err)
                else {
                    arrGen = exports.list(arr.sort(compare))
                    arrGen.next(callback)
                }
            })            
        }
        return new this.constructor(this)
    }

    this.join = function(separator) {
        return this.$arrayOp(Array.prototype.join, separator !== undefined ? [separator] : null)
    }
    
    this.reverse = function() {
        return this.$arrayOp(Array.prototype.reverse)
    }
    
    this.$arrayOp = function(arrayMethod, args) {
        var self = this
        var i = 0
        this.next = function(callback) {
            if (i++ > 0)
                return callback(STOP)
                
            self.toArray(function(err, arr) {
                if (err)
                    callback(err, "")
                else {
                    if (args)
                        callback(null, arrayMethod.apply(arr, args))
                    else
                        callback(null, arrayMethod.call(arr))
                }
            })
        }
        return new this.constructor(this)
        
    }
    
    this.end = function(breakOnError, callback) {
    	if (!callback) {
            callback = arguments[0]
            breakOnError = true
        }

        var source = this.source
        var last
        var lastError
        source.next(function handler(err, value) {
            if (err) {
                if (err == STOP)
                    callback && callback(lastError, last)
                else if (!breakOnError) {
                    lastError = err
                    source.next(handler)
                }
                else
                    callback && callback(err, value)
            }
            else  {
                last = value
                source.next(handler)
            }
        })
    }

    this.toArray = function(breakOnError, callback) {
        if (!callback) {
            callback = arguments[0]
            breakOnError = true
        }
        
        var values = []
        var errors = []
        var source = this.source
        
        source.next(function handler(err, value) {
            if (err) {
                if (err == STOP) {
                    if (breakOnError)
                        return callback(null, values)
                    else {
                        errors.length = values.length
                        return callback(errors, values)
                    }
                }
                else {
                    if (breakOnError)
                        return callback(err)
                    else
                        errors[values.length] = err
                }
            }

            values.push(value)
            source.next(handler)
        })
    }

}).call(exports.Generator.prototype)

var makeAsync = exports.makeAsync = function(args, fn, context) {
    if (fn.length > args) 
        return fn
    else {
        return function() {
            var value
            var next = arguments[args]
            try {
                value = fn.apply(context || this, arguments)
            } catch(e) {
                return next(e)
            }
            next(null, value)
        }
    }
}

exports.list = function(arr, construct) {
    var construct = construct || exports.Generator
    var i = 0
    var len = arr.length
    
    return new construct(function(callback) {
        if (i < len)
            callback(null, arr[i++])
        else
            callback(STOP)
    })
}

exports.values = function(map, construct) {
    var values = []
    for (var key in map) 
        values.push(map[key])
        
    return exports.list(values, construct)
}

exports.keys = function(map, construct) {
    var keys = []
    for (var key in map) 
        keys.push(key)
        
    return exports.list(keys, construct)
}

/**
 * range([start,] stop[, step]) -> generator of integers
 *
 * Return a generator containing an arithmetic progression of integers.
 * range(i, j) returns [i, i+1, i+2, ..., j-1] start (!) defaults to 0.
 * When step is given, it specifies the increment (or decrement).
 */ 
exports.range = function(start, stop, step, construct) {
    var construct = construct || exports.Generator
    start = start || 0
    step = step || 1
    
    if (stop === undefined || stop === null)
        stop = step > 0 ? Infinity : -Infinity
        
    var value = start
    
    return new construct(function(callback) {
        if (step > 0 && value >= stop || step < 0 && value <= stop)
            callback(STOP)
        else {
            var current = value
            value += step
            callback(null, current)
        }
    })
}

exports.concat = function(first, varargs) {
    if (arguments.length > 1)
        return first.concat.apply(first, Array.prototype.slice.call(arguments, 1))
    else
        return first
}

exports.zip = function(first, varargs) {
    if (arguments.length > 1)
        return first.zip.apply(first, Array.prototype.slice.call(arguments, 1))
    else
        return first.map(function(item, next) {
            next(null, [item])
        })
}


exports.plugin = function(members, constructors) {
    if (members) {
        for (var key in members) {
            exports.Generator.prototype[key] = members[key]
        }
    }

    if (constructors) {
        for (var key in constructors) {
            exports[key] = constructors[key]
        }
    }    
}

})