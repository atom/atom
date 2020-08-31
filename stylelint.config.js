const path = require('path');

module.exports = {
  extends: 'stylelint-config-standard',
  ignoreFiles: [path.resolve(__dirname, 'static', 'atom.less')],
  rules: {
    'color-hex-case': null, // TODO: enable?
    'max-empty-lines': null, // TODO: enable?
    'selector-type-no-unknown': null,
    'function-comma-space-after': null, // TODO: enable?
    'font-family-no-missing-generic-family-keyword': null, // needed for octicons (no sensible fallback)
    'block-opening-brace-space-before': null,
    'block-closing-brace-empty-line-before': null,
    'declaration-colon-space-after': null,
    'declaration-block-single-line-max-declarations': null,
    'declaration-empty-line-before': null, // TODO: enable?
    'declaration-block-trailing-semicolon': null, // TODO: enable
    'no-descending-specificity': null,
    'number-leading-zero': null, // TODO: enable?
    'no-duplicate-selectors': null,
    'selector-pseudo-element-colon-notation': null, // TODO: enable?
    'selector-list-comma-newline-after': null, // TODO: enable?
    'rule-empty-line-before': null, // TODO: enable?
    'at-rule-empty-line-before': null, // TODO: enable?
    'font-family-no-duplicate-names': null, // TODO: enable?
    'unit-no-unknown': [true, { ignoreUnits: ['x'] }] // Needed for -webkit-image-set 1x/2x units
  }
};
