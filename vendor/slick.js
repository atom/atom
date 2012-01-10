// changed at the bottom to export the Slick object

/*
---
name: Slick.Parser
description: Standalone CSS3 Selector parser
provides: Slick.Parser
...
*/

;(function(){

var parsed,
  separatorIndex,
  combinatorIndex,
  reversed,
  cache = {},
  reverseCache = {},
  reUnescape = /\\/g;

var parse = function(expression, isReversed){
  if (expression == null) return null;
  if (expression.Slick === true) return expression;
  expression = ('' + expression).replace(/^\s+|\s+$/g, '');
  reversed = !!isReversed;
  var currentCache = (reversed) ? reverseCache : cache;
  if (currentCache[expression]) return currentCache[expression];
  parsed = {
    Slick: true,
    expressions: [],
    raw: expression,
    reverse: function(){
      return parse(this.raw, true);
    }
  };
  separatorIndex = -1;
  while (expression != (expression = expression.replace(regexp, parser)));
  parsed.length = parsed.expressions.length;
  return currentCache[parsed.raw] = (reversed) ? reverse(parsed) : parsed;
};

var reverseCombinator = function(combinator){
  if (combinator === '!') return ' ';
  else if (combinator === ' ') return '!';
  else if ((/^!/).test(combinator)) return combinator.replace(/^!/, '');
  else return '!' + combinator;
};

var reverse = function(expression){
  var expressions = expression.expressions;
  for (var i = 0; i < expressions.length; i++){
    var exp = expressions[i];
    var last = {parts: [], tag: '*', combinator: reverseCombinator(exp[0].combinator)};

    for (var j = 0; j < exp.length; j++){
      var cexp = exp[j];
      if (!cexp.reverseCombinator) cexp.reverseCombinator = ' ';
      cexp.combinator = cexp.reverseCombinator;
      delete cexp.reverseCombinator;
    }

    exp.reverse().push(last);
  }
  return expression;
};

var escapeRegExp = function(string){// Credit: XRegExp 0.6.1 (c) 2007-2008 Steven Levithan <http://stevenlevithan.com/regex/xregexp/> MIT License
  return string.replace(/[-[\]{}()*+?.\\^$|,#\s]/g, function(match){
    return '\\' + match;
  });
};

var regexp = new RegExp(
/*
#!/usr/bin/env ruby
puts "\t\t" + DATA.read.gsub(/\(\?x\)|\s+#.*$|\s+|\\$|\\n/,'')
__END__
  "(?x)^(?:\
    \\s* ( , ) \\s*               # Separator          \n\
  | \\s* ( <combinator>+ ) \\s*   # Combinator         \n\
  |      ( \\s+ )                 # CombinatorChildren \n\
  |      ( <unicode>+ | \\* )     # Tag                \n\
  | \\#  ( <unicode>+       )     # ID                 \n\
  | \\.  ( <unicode>+       )     # ClassName          \n\
  |                               # Attribute          \n\
  \\[  \
    \\s* (<unicode1>+)  (?:  \
      \\s* ([*^$!~|]?=)  (?:  \
        \\s* (?:\
          ([\"']?)(.*?)\\9 \
        )\
      )  \
    )?  \\s*  \
  \\](?!\\]) \n\
  |   :+ ( <unicode>+ )(?:\
  \\( (?:\
    (?:([\"'])([^\\12]*)\\12)|((?:\\([^)]+\\)|[^()]*)+)\
  ) \\)\
  )?\
  )"
*/
  "^(?:\\s*(,)\\s*|\\s*(<combinator>+)\\s*|(\\s+)|(<unicode>+|\\*)|\\#(<unicode>+)|\\.(<unicode>+)|\\[\\s*(<unicode1>+)(?:\\s*([*^$!~|]?=)(?:\\s*(?:([\"']?)(.*?)\\9)))?\\s*\\](?!\\])|(:+)(<unicode>+)(?:\\((?:(?:([\"'])([^\\13]*)\\13)|((?:\\([^)]+\\)|[^()]*)+))\\))?)"
  .replace(/<combinator>/, '[' + escapeRegExp(">+~`!@$%^&={}\\;</") + ']')
  .replace(/<unicode>/g, '(?:[\\w\\u00a1-\\uFFFF-]|\\\\[^\\s0-9a-f])')
  .replace(/<unicode1>/g, '(?:[:\\w\\u00a1-\\uFFFF-]|\\\\[^\\s0-9a-f])')
);

function parser(
  rawMatch,

  separator,
  combinator,
  combinatorChildren,

  tagName,
  id,
  className,

  attributeKey,
  attributeOperator,
  attributeQuote,
  attributeValue,

  pseudoMarker,
  pseudoClass,
  pseudoQuote,
  pseudoClassQuotedValue,
  pseudoClassValue
){
  if (separator || separatorIndex === -1){
    parsed.expressions[++separatorIndex] = [];
    combinatorIndex = -1;
    if (separator) return '';
  }

  if (combinator || combinatorChildren || combinatorIndex === -1){
    combinator = combinator || ' ';
    var currentSeparator = parsed.expressions[separatorIndex];
    if (reversed && currentSeparator[combinatorIndex])
      currentSeparator[combinatorIndex].reverseCombinator = reverseCombinator(combinator);
    currentSeparator[++combinatorIndex] = {combinator: combinator, tag: '*'};
  }

  var currentParsed = parsed.expressions[separatorIndex][combinatorIndex];

  if (tagName){
    currentParsed.tag = tagName.replace(reUnescape, '');

  } else if (id){
    currentParsed.id = id.replace(reUnescape, '');

  } else if (className){
    className = className.replace(reUnescape, '');

    if (!currentParsed.classList) currentParsed.classList = [];
    if (!currentParsed.classes) currentParsed.classes = [];
    currentParsed.classList.push(className);
    currentParsed.classes.push({
      value: className,
      regexp: new RegExp('(^|\\s)' + escapeRegExp(className) + '(\\s|$)')
    });

  } else if (pseudoClass){
    pseudoClassValue = pseudoClassValue || pseudoClassQuotedValue;
    pseudoClassValue = pseudoClassValue ? pseudoClassValue.replace(reUnescape, '') : null;

    if (!currentParsed.pseudos) currentParsed.pseudos = [];
    currentParsed.pseudos.push({
      key: pseudoClass.replace(reUnescape, ''),
      value: pseudoClassValue,
      type: pseudoMarker.length == 1 ? 'class' : 'element'
    });

  } else if (attributeKey){
    attributeKey = attributeKey.replace(reUnescape, '');
    attributeValue = (attributeValue || '').replace(reUnescape, '');

    var test, regexp;

    switch (attributeOperator){
      case '^=' : regexp = new RegExp(       '^'+ escapeRegExp(attributeValue)            ); break;
      case '$=' : regexp = new RegExp(            escapeRegExp(attributeValue) +'$'       ); break;
      case '~=' : regexp = new RegExp( '(^|\\s)'+ escapeRegExp(attributeValue) +'(\\s|$)' ); break;
      case '|=' : regexp = new RegExp(       '^'+ escapeRegExp(attributeValue) +'(-|$)'   ); break;
      case  '=' : test = function(value){
        return attributeValue == value;
      }; break;
      case '*=' : test = function(value){
        return value && value.indexOf(attributeValue) > -1;
      }; break;
      case '!=' : test = function(value){
        return attributeValue != value;
      }; break;
      default   : test = function(value){
        return !!value;
      };
    }

    if (attributeValue == '' && (/^[*$^]=$/).test(attributeOperator)) test = function(){
      return false;
    };

    if (!test) test = function(value){
      return value && regexp.test(value);
    };

    if (!currentParsed.attributes) currentParsed.attributes = [];
    currentParsed.attributes.push({
      key: attributeKey,
      operator: attributeOperator,
      value: attributeValue,
      test: test
    });

  }

  return '';
};

// Slick NS

var Slick = (this.Slick || {});

Slick.parse = function(expression){
  return parse(expression);
};

Slick.escapeRegExp = escapeRegExp;

this.exports = Slick

}).apply(module);
