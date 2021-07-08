let presets = [
  [
    'babel-preset-atomic',
    {
      targets: {
        electron: 9,
      },
      // some of the packages use non-strict JavaScript in ES6 modules! We need to add this for now. Eventually, we should fix those packages and remove these:
      notStrictDirectiveTriggers: ['use babel'],
      notStrictCommentTriggers: ['@babel', '@flow', '* @babel', '* @flow']
    }
  ]
];

let plugins = [];

module.exports = {
  presets: presets,
  plugins: plugins,
  exclude: 'node_modules/**',
  sourceMap: 'inline'
};
