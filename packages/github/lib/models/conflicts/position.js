class Position {
  constructor(name, cssClass) {
    this.name = name.toLowerCase();

    this.cssClass = cssClass;
  }

  getName() {
    return this.name;
  }

  when(actions) {
    const chosen = actions[this.name] || actions.default || (() => {
      throw new Error(`Unexpected conflict side position: ${this.name}`);
    });
    return chosen();
  }

  getBlockCSSClass() {
    return this.cssClass + 'Block';
  }

  toString() {
    return `<Position: ${this.name.toUpperCase()}>`;
  }
}

export const TOP = new Position('TOP', 'github-ConflictTop');
export const MIDDLE = new Position('MIDDLE', 'github-ConflictMiddle');
export const BOTTOM = new Position('BOTTOM', 'github-ConflictBottom');
