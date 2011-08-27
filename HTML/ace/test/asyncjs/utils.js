/*!
 * async.js
 * Copyright(c) 2010 Fabian Jakobs <fabian.jakobs@web.de>
 * MIT Licensed
 */

define(function(require, exports, module) {

var async = require("asyncjs/async")

async.plugin({
    delay: function(delay) {
        return this.each(function(item, next) {
            setTimeout(function() {
                next();
            }, delay)
        })
    },
    
    timeout: function(timeout) {
        timeout = timeout || 0
        var source = this.source
        
        this.next = function(callback) {
            var called            
            var id = setTimeout(function() {
                called = true
                callback("Source did not respond after " + timeout + "ms!")
            }, timeout)
            
            source.next(function(err, value) {
                if (called)
                    return

                called = true
                clearTimeout(id)
                
                callback(err, value)
            })
        }
        return new this.constructor(this)
    },
    
    get: function(key) {
        return this.map(function(value, next) {
            next(null, value[key])
        })
    },
    
    inspect: function() {
        return this.each(function(item, next) {
            console.log(JSON.stringify(item))
            next()
        })
    },
    
    print: function() {
        return this.each(function(item, next) {
            console.log(item)
            next()
        })
    }    
})

})