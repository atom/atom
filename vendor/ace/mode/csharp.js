define(function(require, exports, module) {

var oop = require("pilot/oop");
var TextMode = require("ace/mode/text").Mode;
var Tokenizer = require("ace/tokenizer").Tokenizer;
var CSharpHighlightRules = require("ace/mode/csharp_highlight_rules").CSharpHighlightRules;
var MatchingBraceOutdent = require("ace/mode/matching_brace_outdent").MatchingBraceOutdent;
var CstyleBehaviour = require("ace/mode/behaviour/cstyle").CstyleBehaviour;

var Mode = function() {
    this.$tokenizer = new Tokenizer(new CSharpHighlightRules().getRules());
    this.$outdent = new MatchingBraceOutdent();
    this.$behaviour = new CstyleBehaviour();
};
oop.inherits(Mode, TextMode);

(function() {
    
	  this.getNextLineIndent = function(state, line, tab) {
	      var indent = this.$getIndent(line);

	      var tokenizedLine = this.$tokenizer.getLineTokens(line, state);
	      var tokens = tokenizedLine.tokens;
	      var endState = tokenizedLine.state;

	      if (tokens.length && tokens[tokens.length-1].type == "comment") {
	          return indent;
	      }
      
	      if (state == "start") {
	          var match = line.match(/^.*[\{\(\[]\s*$/);
	          if (match) {
	              indent += tab;
	          }
	      }

	      return indent;
	  };

	  this.checkOutdent = function(state, line, input) {
	      return this.$outdent.checkOutdent(line, input);
	  };

	  this.autoOutdent = function(state, doc, row) {
	      this.$outdent.autoOutdent(doc, row);
	  };


    this.createWorker = function(session) {
        return null;
    };

}).call(Mode.prototype);

exports.Mode = Mode;
});
