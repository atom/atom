// source: MooTools DOM branch -> https://raw.github.com/arian/DOM/matcher-specificity/Source/specificity.js
// changed to be compatible with our require system
// change line
//    for (var ii = nots.length; ii--;) s += this.specificity(nots[ii]);
//    for (var ii = nots.length; ii--;) s += nots[ii];

var Slick = require('./slick');

module.exports = function(selector){
  var parsed = Slick.parse(selector);
  var expressions = parsed.expressions;
  var specificity = -1;
  for (var j = 0; j < expressions.length; j++){
    var b = 0, c = 0, d = 0, s = 0, nots = [];
    for (var i = 0; i < expressions[j].length; i++){
      var expression = expressions[j][i], pseudos = expression.pseudos;
      if (expression.id) b++;
      if (expression.attributes) c += expression.attributes.length;
      if (expression.classes) c += expression.classes.length;
      if (expression.tag && expression.tag != '*') d++;
      if (pseudos){
        d += pseudos.length;
        for (var p = 0; p < pseudos.length; p++) if (pseudos[p].key == 'not'){
          nots.push(pseudos[p].value);
          d--;
        }
      }
    }
    s = b * 1e6 + c * 1e3 + d;
    for (var ii = nots.length; ii--;) s += nots[ii];
    if (s > specificity) specificity = s;
  }
  return specificity;
};
