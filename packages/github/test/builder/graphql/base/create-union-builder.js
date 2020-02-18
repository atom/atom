const UNSET = Symbol('unset');

class UnionBuilder {
  static resolve() { return this; }

  constructor(...args) {
    this.args = args;
    this._value = UNSET;
  }

  build() {
    if (this._value === UNSET) {
      this[this.defaultAlternative]();
    }

    return this._value;
  }
}

export function createUnionBuilderClass(typeName, alternativeSpec) {
  class Builder extends UnionBuilder {}
  Builder.prototype.typeName = typeName;
  Builder.prototype.defaultAlternative = alternativeSpec.default;

  function installAlternativeMethod(methodName, BuilderClass) {
    Builder.prototype[methodName] = function(block = () => {}) {
      const Resolved = BuilderClass.resolve();
      const b = new Resolved(...this.args);
      block(b);
      this._value = b.build();
      return this;
    };
  }

  for (const methodName in alternativeSpec) {
    const BuilderClass = alternativeSpec[methodName];
    installAlternativeMethod(methodName, BuilderClass);
  }

  return Builder;
}
