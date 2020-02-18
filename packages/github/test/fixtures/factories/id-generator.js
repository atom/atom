const IDGEN = Symbol('id-generator');

export default class IDGenerator {
  static nextID = 0;

  static fromOpts(opts = {}) {
    return opts[IDGEN] || new this();
  }

  generate(prefix = '') {
    const id = this.constructor.nextID;
    this.constructor.nextID++;
    return `${prefix}${id}`;
  }

  embed() {
    return {[IDGEN]: this};
  }
}
