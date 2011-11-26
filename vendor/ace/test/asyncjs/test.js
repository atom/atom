/*!
 * async.js
 * Copyright(c) 2010 Fabian Jakobs <fabian.jakobs@web.de>
 * MIT Licensed
 */

define(function(require, exports, module) {

var oop = require("pilot/oop")
var async = require("asyncjs/async")
require("asyncjs/utils")

exports.TestGenerator = function(source) {
    async.Generator.call(this, source)
}

oop.inherits(exports.TestGenerator, async.Generator)

;(function() {
    
    this.exec = function() {
        this.run().report().summary(function(err, passed) {
            console.log("DONE")
        })
    }
    
    this.run = function() {
        return this.setupTest()
            .each(function(test, next) {
                if (test.setUpSuite)
                    test.setUpSuite(next)
                else
                    next()
            })
            .each(function(test, next) {
                test.test(function(err, passed) {
                    test.err = err
                    test.passed = passed
                    next()
                })
            })
            .each(function(test, next) {
                if (test.tearDownSuite)
                    test.tearDownSuite(next)
                else
                    next()
            })
    }
    
    this.report = function() {
        return this.each(function(test, next) {
            var color = test.passed ? "\x1b[32m" : "\x1b[31m"
            var name = test.name
            if (test.suiteName)
                name = test.suiteName + ": " + test.name
            console.log(color + "[" + test.count + "/" + test.index + "] " + name + " " + (test.passed ? "OK" : "FAIL") + "\x1b[0m")
            if (!test.passed)                
                if (test.err.stack)
                    console.log(test.err.stack)
                else
                    console.log(test.err)
                    
            next()
        })
    }
    
    this.summary = function(callback) {
        var passed = 0
        var failed = 0
        
        this.each(function(test) {
            if (test.passed)
                passed += 1
            else
                failed += 1
        }).end(function() {
            console.log("")
            console.log("Summary:")
            console.log("")
            console.log(                  "Total number of tests: " + (passed + failed))
            passed && console.log("\x1b[32mPassed tests:          " + passed + "\x1b[0m")
            failed && console.log("\x1b[31mFailed tests:          " + failed + "\x1b[0m")
            console.log("")            
            callback(null, failed == 0)
        })
    }
    
    this.setupTest = function() {
        return this.each(function(test, next) {
            var empty = function(next) { next() }
            var context = test.context || this
            
            if (test.setUp)
                var setUp = async.makeAsync(0, test.setUp, context)
            else 
                setUp = empty

            tearDownCalled = false
            if (test.tearDown)
                var tearDownInner = async.makeAsync(0, test.tearDown, context)
            else
                tearDownInner = empty
                
            function tearDown(next) {
                tearDownCalled = true
                tearDownInner.call(test.context, next)
            }

            var testFn = async.makeAsync(0, test.fn, context)
                
            test.test = function(callback) {    
                var called            
                function errorListener(e) {
                    if (called)
                        return
                    called = true
                    //process.removeListener('uncaughtException', errorListener)
                    if (!tearDownCalled) {
                        async.list([tearDown])
                            .call()
                            .timeout(test.timeout)
                            .end(function() {
                                callback(e, false)
                            })                    }
                    else
                        callback(e, false)
                }
                //process.addListener('uncaughtException', errorListener)
                
                async.list([setUp, testFn, tearDown])
                    .delay(0)
                    .call(context)
                    .timeout(test.timeout)
                    .toArray(false, function(errors, values) {
                        if (called)
                            return
                        called = true
                        var err = errors[1]
                        //process.removeListener('uncaughtException', errorListener)                            
                        callback(err, !err)                        
                    })
            }
            
            next()
        })
    }
    
}).call(exports.TestGenerator.prototype)

exports.testcase = function(testcase, suiteName, timeout) {
    var methods = []
    for (var method in testcase)
        methods.push(method)
        
    var setUp = testcase.setUp || null
    var tearDown = testcase.tearDown || null
    
    var single
    methods.forEach(function(name) {
        if (name.charAt(0) == '>')
           single = name
    })
    if (single)
        methods = [single]
    
    var testNames = methods.filter(function(method) { 
        return method.match(/^>?test/) && typeof(testcase[method]) == "function"
    })
    var count = testNames.length
    var i=1
    tests = testNames.map(function(name) {
        return {
            suiteName: suiteName || testcase.name || "",
            name: name,
            setUp: setUp,
            tearDown: tearDown,
            context: testcase,
            timeout: timeout === undefined ? 3000 : timeout,
            fn: testcase[name],
            count: count,
            index: i++
        }
    })

    if (testcase.setUpSuite) {
        tests[0].setUpSuite = async.makeAsync(0, testcase.setUpSuite, testcase)
    }
    if (testcase.tearDownSuite) {
        tests[tests.length-1].tearDownSuite = async.makeAsync(0, testcase.tearDownSuite, testcase)
    }

    return async.list(tests, exports.TestGenerator)
}

})