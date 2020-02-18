const generate = require('@babel/generator').default;

module.exports = function({types: t}) {
  return {
    name: 'assert-messages',
    visitor: {
      CallExpression(path, state) {
        // assuming `assert.something(arg1, arg2)`

        // assert.something
        const callee = path.node.callee;
        if (!t.isMemberExpression(callee)) { return; }

        if (!t.isIdentifier(callee.object, {name: 'assert'})) { return; }
        if (t.isIdentifier(callee.property, {name: 'isRejected'})) { return; }
        if (!t.isIdentifier(callee.property)) { return; }

        try {
          const code = generate(path.node).code;
          path.node.arguments.push(t.stringLiteral(code));
        } catch (err) {
          // nothing
        }
      },
    },
  };
};
