// How many times has this exact helper been written?
export function capitalize(word) {
  return word[0].toUpperCase() + word.slice(1);
}

// Format the name of the method used to generate a default value for a field if one is not explicitly provided. For
// example, a fieldName of "someThing" would be "getDefaultSomeThing()".
export function makeDefaultGetterName(fieldName) {
  return `getDefault${capitalize(fieldName)}`;
}

// Format the name of a method used to append a value to the end of a collection. For example, a fieldName of
// "someThing" would be "addSomeThing()".
export function makeAdderFunctionName(fieldName) {
  return `add${capitalize(fieldName)}`;
}

// Format the name of a method used to mark a field as explicitly null and prevent it from being filled out with
// default values. For example, a fieldName of "someThing" would be "nullSomeThing()".
export function makeNullableFunctionName(fieldName) {
  return `null${capitalize(fieldName)}`;
}
