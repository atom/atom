import {FragmentSpec, QuerySpec} from './spec';
import {makeDefaultGetterName} from './names';

// Private symbol used to identify what fields within a Builder have been populated (by a default setter or an
// explicit setter call). Using this instead of "undefined" lets us actually have "null" or "undefined" values
// if we want them.
const UNSET = Symbol('unset');

// Superclass for Builders that are expected to adhere to the fields requested by a GraphQL fragment.
export class SpecBuilder {

  // Compatibility with deferred-resolution builders.
  static resolve() {
    return this;
  }

  static onFragmentQuery(nodes) {
    if (!nodes || nodes.length === 0) {
      /* eslint-disable-next-line no-console */
      console.error(
        `No parsed query fragments given to \`${this.builderName}.onFragmentQuery()\`.\n` +
        "Make sure you're passing a compiled Relay query (__generated__/*.graphql.js module)" +
        ' to the builder construction function.',
      );
      throw new Error(`No parsed queries given to ${this.builderName}`);
    }

    return new this(typeNameSet => new FragmentSpec(nodes, typeNameSet));
  }

  static onFullQuery(query) {
    if (!query) {
      /* eslint-disable-next-line no-console */
      console.error(
        `No parsed GraphQL queries given to \`${this.builderName}.onFullQuery()\`.\n` +
        "Make sure you're passing GraphQL query text to the builder construction function.",
      );
      throw new Error(`No parsed queries given to ${this.builderName}`);
    }

    let rootQuery = null;
    const fragmentsByName = new Map();
    for (const definition of query.definitions) {
      if (
        definition.kind === 'OperationDefinition' &&
        (definition.operation === 'query' || definition.operation === 'mutation')
      ) {
        rootQuery = definition;
      } else if (definition.kind === 'FragmentDefinition') {
        fragmentsByName.set(definition.name.value, definition);
      }
    }

    if (rootQuery === null) {
      throw new Error('Parsed query contained no root query');
    }

    return new this(typeNameSet => new QuerySpec(rootQuery, typeNameSet, fragmentsByName));
  }

  // Construct a SpecBuilder that builds an instance corresponding to a single GraphQL schema type, including only
  // the fields selected by "nodes".
  constructor(specFn) {
    this.spec = specFn(this.allTypeNames);

    this.knownScalarFieldNames = new Set(this.spec.getRequestedScalarFields());
    this.knownLinkedFieldNames = new Set(this.spec.getRequestedLinkedFields());

    this.fields = {};
    for (const fieldName of [...this.knownScalarFieldNames, ...this.knownLinkedFieldNames]) {
      this.fields[fieldName] = UNSET;
    }
  }

  // Directly populate the builder's value for a scalar (Int, String, ID, ...) field. This will fail if the fragment
  // we're configured with doesn't select the field, or if the field is a linked field instead.
  singularScalarFieldSetter(fieldName, value) {
    if (!this.knownScalarFieldNames.has(fieldName)) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Unselected scalar field name ${fieldName} in ${this.builderName}\n` +
        `"${fieldName}" may not be included in the GraphQL fragments you passed to this builder.\n` +
        'It may also be present, but as a linked field, in which case the builder definitions should be updated.\n' +
        'Otherwise, try re-running "npm run relay" to regenerate the compiled GraphQL modules.',
      );
      throw new Error(`Unselected field name ${fieldName} in ${this.builderName}`);
    }
    this.fields[fieldName] = value;
    return this;
  }

  // Append a scalar value to an Array field. This will fail if the fragment we're configured with doesn't select the
  // field, or if the field is a linked field instead.
  pluralScalarFieldAdder(fieldName, value) {
    if (!this.knownScalarFieldNames.has(fieldName)) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Unselected scalar field name ${fieldName} in ${this.builderName}\n` +
        `"${fieldName}" may not be included in the GraphQL fragments you passed to this builder.\n` +
        'It may also be present, but as a linked field, in which case the builder definitions should be updated.\n' +
        'Otherwise, try re-running "npm run relay" to regenerate the compiled GraphQL modules.',
      );
      throw new Error(`Unselected field name ${fieldName} in ${this.builderName}`);
    }

    if (this.fields[fieldName] === UNSET) {
      this.fields[fieldName] = [];
    }
    this.fields[fieldName].push(value);

    return this;
  }

  // Build a linked object with a different Builder using "block", then set the field's value based on the builder's
  // output. This will fail if the field is not selected by the current fragment, or if the field is actually a
  // scalar field.
  singularLinkedFieldSetter(fieldName, Builder, block) {
    if (!this.knownLinkedFieldNames.has(fieldName)) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Unrecognized linked field name ${fieldName} in ${this.builderName}.\n` +
        `"${fieldName}" may not be included in the GraphQL fragments you passed to this builder.\n` +
        'It may also be present, but as a scalar field, in which case the builder definitions should be updated.\n' +
        'Otherwise, try re-running "npm run relay" to regenerate the compiled GraphQL modules.',
      );
      throw new Error(`Unrecognized field name ${fieldName} in ${this.builderName}`);
    }

    const Resolved = Builder.resolve();
    const specFn = this.spec.getLinkedSpecCreator(fieldName);
    const builder = new Resolved(specFn);
    block(builder);
    this.fields[fieldName] = builder.build();

    return this;
  }

  // Construct a linked object with another Builder using "block", then append the built object to an Array. This will
  // fail if the named field is not selected by the current fragment, or if it's actually a scalar field.
  pluralLinkedFieldAdder(fieldName, Builder, block) {
    if (!this.knownLinkedFieldNames.has(fieldName)) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Unrecognized linked field name ${fieldName} in ${this.builderName}.\n` +
        `"${fieldName}" may not be included in the GraphQL fragments you passed to this builder.\n` +
        'It may also be present, but as a scalar field, in which case the builder definitions should be updated.\n' +
        'Otherwise, try re-running "npm run relay" to regenerate the compiled GraphQL modules.',
      );
      throw new Error(`Unrecognized field name ${fieldName} in ${this.builderName}`);
    }

    if (this.fields[fieldName] === UNSET) {
      this.fields[fieldName] = [];
    }

    const Resolved = Builder.resolve();
    const specFn = this.spec.getLinkedSpecCreator(fieldName);
    const builder = new Resolved(specFn);
    block(builder);
    this.fields[fieldName].push(builder.build());

    return this;
  }

  // Explicitly set a field to `null` and prevent it from being populated with a default value. This will fail if the
  // named field is not selected by the current fragment.
  nullField(fieldName) {
    if (!this.knownScalarFieldNames.has(fieldName) && !this.knownLinkedFieldNames.has(fieldName)) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Unrecognized field name ${fieldName} in ${this.builderName}.\n` +
        `"${fieldName}" may not be included in the GraphQL fragments you provided to this builder.\n` +
        'Try re-running "npm run relay" to regenerate the compiled GraphQL modules.',
      );
      throw new Error(`Unrecognized field name ${fieldName} in ${this.builderName}`);
    }

    this.fields[fieldName] = null;
    return this;
  }

  // Finalize any fields selected by the current query that have not been explicitly populated with their default
  // values. Fail if any unpopulated fields have no specified default value or function. Then, return the selected
  // fields as a plain JavaScript object.
  build() {
    const fieldNames = Object.keys(this.fields);

    const missingFieldNames = [];

    const populators = {};
    for (const fieldName of fieldNames) {
      const defaultGetterName = makeDefaultGetterName(fieldName);
      if (this.fields[fieldName] === UNSET && typeof this[defaultGetterName] !== 'function') {
        missingFieldNames.push(fieldName);
        continue;
      }

      Object.defineProperty(populators, fieldName, {
        get: () => {
          if (this.fields[fieldName] !== UNSET) {
            return this.fields[fieldName];
          } else {
            const value = this[defaultGetterName](populators);
            this.fields[fieldName] = value;
            return value;
          }
        },
      });
    }

    if (missingFieldNames.length > 0) {
      /* eslint-disable-next-line no-console */
      console.error(
        `Missing required fields ${missingFieldNames.join(', ')} in builder ${this.builderName}.\n` +
        'Either give these fields a "default" in the builder or call their setters explicitly before calling "build()".',
      );
      throw new Error(`Missing required fields ${missingFieldNames.join(', ')} in builder ${this.builderName}`);
    }

    for (const fieldName of fieldNames) {
      populators[fieldName];
    }

    return this.fields;
  }
}

// Resolve circular references by deferring the loading of a linked Builder class. Create these instances with the
// exported "defer" function.
export class DeferredSpecBuilder {
  // Construct a deferred builder that will load a named, exported builder class from a module path. Note that, if
  // modulePath is relative, it should be relative to *this* file.
  constructor(modulePath, className) {
    this.modulePath = modulePath;
    this.className = className;
    this.Class = undefined;
  }

  // Lazily load the requested builder. Fail if the named module doesn't exist, or if it does not export a symbol
  // with the requested class name.
  resolve() {
    if (this.Class === undefined) {
      this.Class = require(this.modulePath)[this.className];
      if (!this.Class) {
        throw new Error(`No class ${this.className} exported from ${this.modulePath}.`);
      }
    }
    return this.Class;
  }
}
