import {SpecBuilder} from './builder';
import {makeDefaultGetterName, makeNullableFunctionName, makeAdderFunctionName} from './names';

// Dynamically construct a Builder class that includes *only* fields that are selected by a GraphQL fragment. Adding
// fields to a fragment will cause them to be automatically included when that a Builder instance is created with
// that fragment; when a field is removed from the fragment, attempting to populate it with a setter method at
// build time will fail with an error.
//
// "typeName" is the name of the GraphQL type from the schema being queried. It will be used to determine which
// fragments to include and to generate a builder name for diagnostic messages.
//
// "fieldDescriptions" is an object detailing the *superset* of the fields used by all fragments on this type. Each
// key is a field name, and its value is an object that controls which methods that are generated on the builder:
//
// * "default" may be a constant value or a function. It's used to populate this field if it has not been explicitly
//   set before build() is called.
// * "linked" names another SpecBuilder class used to build a linked compound object.
// * "plural" specifies that this property is an Array. It implicitly defaults to [] and may be constructed
//   incrementally with an addFieldName() method.
// * "nullable" generates a `nullFieldName()` method that may be used to intentionally omit a field that would normally
//   have a default value.
// * "custom" installs its value as a method on the generated Builder with the provided field name.
//
// See the README in this directory for examples.
export function createSpecBuilderClass(typeName, fieldDescriptions, interfaces = '') {
  class Builder extends SpecBuilder {}
  Builder.prototype.typeName = typeName;
  Builder.prototype.builderName = typeName + 'Builder';

  Builder.prototype.allTypeNames = new Set([typeName, ...interfaces.split(/\s*&\s*/)]);

  // These functions are used to install functions on the Builder class that implement specific access patterns. They're
  // implemented here as inner functions to avoid the use of function literals within a loop.

  function installScalarSetter(fieldName) {
    Builder.prototype[fieldName] = function(_value) {
      return this.singularScalarFieldSetter(fieldName, _value);
    };
  }

  function installScalarAdder(pluralFieldName, singularFieldName) {
    Builder.prototype[makeAdderFunctionName(singularFieldName)] = function(_value) {
      return this.pluralScalarFieldAdder(pluralFieldName, _value);
    };
  }

  function installLinkedSetter(fieldName, LinkedBuilder) {
    Builder.prototype[fieldName] = function(_block = () => {}) {
      return this.singularLinkedFieldSetter(fieldName, LinkedBuilder, _block);
    };
  }

  function installLinkedAdder(pluralFieldName, singularFieldName, LinkedBuilder) {
    Builder.prototype[makeAdderFunctionName(singularFieldName)] = function(_block = () => {}) {
      return this.pluralLinkedFieldAdder(pluralFieldName, LinkedBuilder, _block);
    };
  }

  function installNullableFunction(fieldName) {
    Builder.prototype[makeNullableFunctionName(fieldName)] = function() {
      return this.nullField(fieldName);
    };
  }

  function installDefaultGetter(fieldName, descriptionDefault) {
    const defaultGetterName = makeDefaultGetterName(fieldName);
    const defaultGetter = typeof descriptionDefault === 'function' ? descriptionDefault : function() {
      return descriptionDefault;
    };
    Builder.prototype[defaultGetterName] = defaultGetter;
  }

  function installDefaultPluralGetter(fieldName) {
    installDefaultGetter(fieldName, function() {
      return [];
    });
  }

  function installDefaultLinkedGetter(fieldName) {
    installDefaultGetter(fieldName, function() {
      this[fieldName]();
      return this.fields[fieldName];
    });
  }

  // Iterate through field descriptions and install requested methods on the Builder class.

  for (const fieldName in fieldDescriptions) {
    const description = fieldDescriptions[fieldName];

    if (description.custom !== undefined) {
      // Custom method. This is a backdoor to let you add random stuff to the final Builder.
      Builder.prototype[fieldName] = description.custom;
      continue;
    }

    const singularFieldName = description.singularName || fieldName;

    // Object.keys() is used to detect the "linked" key here because, in the relatively common case of a circular
    // import dependency, the description will be `{linked: undefined}`, and I want to provide a better error message
    // when that happens.
    if (!Object.keys(description).includes('linked')) {
      // Scalar field.

      if (description.plural) {
        installScalarAdder(fieldName, singularFieldName);
      } else {
        installScalarSetter(fieldName);
      }
    } else {
      // Linked field.

      if (description.linked === undefined) {
        /* eslint-disable-next-line no-console */
        console.error(
          `Linked field ${fieldName} requested without a builder class in ${name}.\n` +
          'This can happen if you have a circular dependency between builders in different ' +
          'modules. Use defer() to defer loading of one builder to break it.',
          fieldDescriptions,
        );
        throw new Error(`Linked field ${fieldName} requested without a builder class in ${name}`);
      }

      if (description.plural) {
        installLinkedAdder(fieldName, singularFieldName, description.linked);
      } else {
        installLinkedSetter(fieldName, description.linked);
      }
    }

    // Install the appropriate default getter method. Explicitly specified defaults take precedence, then plural
    // fields default to [], and linked fields default to calling the linked builder with an empty block to get
    // the sub-builder's defaults.

    if (description.default !== undefined) {
      installDefaultGetter(fieldName, description.default);
    } else if (description.plural) {
      installDefaultPluralGetter(fieldName);
    } else if (description.linked) {
      installDefaultLinkedGetter(fieldName);
    }

    // Install the "explicitly null me out" method.

    if (description.nullable) {
      installNullableFunction(fieldName);
    }
  }

  return Builder;
}
