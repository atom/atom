const presets = [
  [
    'babel-preset-atomic',
    {
      targets: {
        electron: 11,
      },
      // some of the packages use non-strict JavaScript in ES6 modules! We need to add this for now. Eventually, we should fix those packages and remove these:
      notStrictDirectiveTriggers: ['use babel'],
      notStrictCommentTriggers: ['@babel', '@flow', '* @babel', '* @flow']
    }
  ]
];

const plugins = [
  // Though the "loose" option was set to "false" in your @babel/preset-env config, it will not be used for @babel/plugin - proposal - private - property -in -object since the "loose" mode option was set to "true" for @babel/plugin-proposal-private-methods.
  // The "loose" option must be the same for @babel/plugin-proposal-class-properties, @babel/plugin - proposal - private - methods and @babel/plugin-proposal-private-property-in-object (when they are enabled): you can silence this warning by explicitly adding
  ["@babel/plugin-proposal-private-property-in-object", { "loose": true }]
  // to the "plugins" section of your Babel config.
];

module.exports = {
  presets: presets,
  plugins: plugins,
  exclude: 'node_modules/**',
  sourceMap: 'inline'
};
