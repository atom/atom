let ParsedColor = null;

// Essential: A simple color class returned from {Config::get} when the value
// at the key path is of type 'color'.
module.exports = class Color {
  // Essential: Parse a {String} or {Object} into a {Color}.
  //
  // * `value` A {String} such as `'white'`, `#ff00ff`, or
  //   `'rgba(255, 15, 60, .75)'` or an {Object} with `red`, `green`, `blue`,
  //   and `alpha` properties.
  //
  // Returns a {Color} or `null` if it cannot be parsed.
  static parse(value) {
    switch (typeof value) {
      case 'string':
        break;
      case 'object':
        if (Array.isArray(value)) {
          return null;
        }
        break;
      default:
        return null;
    }

    if (!ParsedColor) {
      ParsedColor = require('color');
    }

    try {
      var parsedColor = new ParsedColor(value);
    } catch (error) {
      return null;
    }

    return new Color(
      parsedColor.red(),
      parsedColor.green(),
      parsedColor.blue(),
      parsedColor.alpha()
    );
  }

  constructor(red, green, blue, alpha) {
    this.red = red;
    this.green = green;
    this.blue = blue;
    this.alpha = alpha;
  }

  set red(red) {
    this._red = parseColor(red);
  }

  set green(green) {
    this._green = parseColor(green);
  }

  set blue(blue) {
    this._blue = parseColor(blue);
  }

  set alpha(alpha) {
    this._alpha = parseAlpha(alpha);
  }

  get red() {
    return this._red;
  }

  get green() {
    return this._green;
  }

  get blue() {
    return this._blue;
  }

  get alpha() {
    return this._alpha;
  }

  // Essential: Returns a {String} in the form `'#abcdef'`.
  toHexString() {
    return `#${numberToHexString(this.red)}${numberToHexString(
      this.green
    )}${numberToHexString(this.blue)}`;
  }

  // Essential: Returns a {String} in the form `'rgba(25, 50, 75, .9)'`.
  toRGBAString() {
    return `rgba(${this.red}, ${this.green}, ${this.blue}, ${this.alpha})`;
  }

  toJSON() {
    return this.alpha === 1 ? this.toHexString() : this.toRGBAString();
  }

  toString() {
    return this.toRGBAString();
  }

  isEqual(color) {
    if (this === color) {
      return true;
    }

    if (!(color instanceof Color)) {
      color = Color.parse(color);
    }

    if (color == null) {
      return false;
    }

    return (
      color.red === this.red &&
      color.blue === this.blue &&
      color.green === this.green &&
      color.alpha === this.alpha
    );
  }

  clone() {
    return new Color(this.red, this.green, this.blue, this.alpha);
  }
};

function parseColor(colorString) {
  const color = parseInt(colorString, 10);
  return isNaN(color) ? 0 : Math.min(Math.max(color, 0), 255);
}

function parseAlpha(alphaString) {
  const alpha = parseFloat(alphaString);
  return isNaN(alpha) ? 1 : Math.min(Math.max(alpha, 0), 1);
}

function numberToHexString(number) {
  const hex = number.toString(16);
  return number < 16 ? `0${hex}` : hex;
}
