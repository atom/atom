if (typeof process !== "undefined") {
    require("amd-loader");
    require("../test/mockdom");
}

define(function(require, exports, module) {
"use strict";

var assert = require("assert");
var highlighter = require("./static_highlight");
var JavaScriptMode = require("../mode/javascript").Mode;

// Execution ORDER: test.setUpSuite, setUp, testFn, tearDown, test.tearDownSuite
module.exports = {
    timeout: 10000,
    
    "test simple snippet": function(next) {
        var theme = require("../theme/tomorrow");
        var snippet = "/** this is a function\n\
*\n\
*/\n\
function hello (a, b, c) {\n\
    console.log(a * b + c + 'sup?');\n\
}";
        var mode = new JavaScriptMode();
        
        var isError = false, result;
        try {
            result = highlighter.render(snippet, mode, theme);
        }
        catch (e) {
            console.log(e);
            isError = true;
        }
        // todo: write something more meaningful
        assert.equal(isError, false);
        
        next();
    },
    
    "test css from theme is used": function(next) {
        var theme = require("../theme/tomorrow");
        var snippet = "/** this is a function\n\
*\n\
*/\n\
function hello (a, b, c) {\n\
    console.log(a * b + c + 'sup?');\n\
}";
        var mode = new JavaScriptMode();
        
        var isError = false, result;
        result = highlighter.render(snippet, mode, theme);
        
        assert.ok(result.css.indexOf(theme.cssText) !== -1);
        
        next();
    },
    
    "test theme classname should be in output html": function (next) {
        var theme = require("../theme/tomorrow");
        var snippet = "/** this is a function\n\
*\n\
*/\n\
function hello (a, b, c) {\n\
    console.log(a * b + c + 'sup?');\n\
}";
        var mode = new JavaScriptMode();
        
        var isError = false, result;
        result = highlighter.render(snippet, mode, theme);
        assert.equal(!!result.html.match(/<div class='ace-tomorrow'>/), true);
        
        next();
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec();
}