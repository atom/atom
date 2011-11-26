if (typeof process !== "undefined") {
    require("../../../support/paths");    
    require("ace/test/mockdom");
}

var assert = require("assert");
var highlighter = require("./static_highlight");
var JavaScriptMode = require("ace/mode/javascript").Mode;

// Execution ORDER: test.setUpSuite, setUp, testFn, tearDown, test.tearDownSuite
module.exports = {
    timeout: 10000,
    
    "test simple snippet": function(next) {
        var theme = require("ace/theme/tomorrow");
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
        var theme = require("ace/theme/tomorrow");
        var snippet = "/** this is a function\n\
*\n\
*/\n\
function hello (a, b, c) {\n\
    console.log(a * b + c + 'sup?');\n\
}";
        var mode = new JavaScriptMode();
        
        var isError = false, result;
        result = highlighter.render(snippet, mode, theme);
        
        assert.equal(result.css, theme.cssText);
        
        next();
    },
    
    "test theme classname should be in output html": function (next) {
        var theme = require("ace/theme/tomorrow");
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

!module.parent && require("asyncjs").test.testcase(module.exports).exec();
