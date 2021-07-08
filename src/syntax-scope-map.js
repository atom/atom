const parser = require('postcss-selector-parser');

module.exports = class SyntaxScopeMap {
  constructor(resultsBySelector) {
    this.namedScopeTable = {};
    this.anonymousScopeTable = {};
    for (let selector in resultsBySelector) {
      this.addSelector(selector, resultsBySelector[selector]);
    }
    setTableDefaults(this.namedScopeTable);
    setTableDefaults(this.anonymousScopeTable, this.namedScopeTable);
    setTableResults(this.namedScopeTable);
    setTableResults(this.anonymousScopeTable);
  }

  addSelector(selector, result) {
    parser(parseResult => {
      for (let selectorNode of parseResult.nodes) {
        let currentTable = null;
        let currentIndex = null;

        for (let i = selectorNode.nodes.length - 1; i >= 0; i--) {
          const termNode = selectorNode.nodes[i];

          if (termNode.type === 'string') {
            if (!currentTable) currentTable = this.anonymousScopeTable;
            termNode.value = termNode.value.slice(1, -1).replace(/\\"/g, '"');
          }

          if (
            termNode.type === 'tag' ||
            termNode.type === 'string' ||
            termNode.type === 'universal'
          ) {
            if (!currentTable) currentTable = this.namedScopeTable;
            if (!currentTable[termNode.value])
              currentTable[termNode.value] = {};
            currentTable = currentTable[termNode.value];
            if (!currentTable.indices) currentTable.indices = {};
            if (currentIndex == null) currentIndex = '*';
            if (!currentTable.indices[currentIndex])
              currentTable.indices[currentIndex] = {};
            currentTable = currentTable.indices[currentIndex];
            currentIndex = null;
            continue;
          }

          if (termNode.type === 'combinator') {
            if (!currentTable || currentIndex != null || termNode.value !== '>')
              rejectSelector(selector);
            if (!currentTable.parents) currentTable.parents = {};
            currentTable = currentTable.parents;
            continue;
          }

          if (termNode.type === 'pseudo') {
            if (currentIndex != null || termNode.value !== ':nth-child')
              rejectSelector(selector);
            currentIndex = termNode.nodes[0].nodes[0].value;
            continue;
          }

          rejectSelector(selector);
        }

        currentTable.results = [result];
      }
    }).process(selector);
  }

  get(nodeTypes, childIndices, leafIsNamed = true) {
    let results;
    let i = nodeTypes.length - 1;
    let currentTable = leafIsNamed
      ? this.namedScopeTable[nodeTypes[i]]
      : this.anonymousScopeTable[nodeTypes[i]];

    if (!currentTable) currentTable = this.namedScopeTable['*'];

    while (currentTable) {
      if (currentTable.results != null) results = currentTable.results;

      if (currentTable.indices) {
        currentTable =
          currentTable.indices[childIndices[i]] || currentTable.indices['*'];
        continue;
      }

      if (i === 0 || !currentTable.parents) break;

      currentTable =
        currentTable.parents[nodeTypes[--i]] || currentTable.parents['*'];
    }

    return results;
  }
};

function setTableDefaults(table, defaultTable) {
  defaultTable = defaultTable || table;

  if (defaultTable['*']) {
    for (let key in table) {
      if (key === '*' && defaultTable === table) continue;
      mergeTable(table[key], defaultTable['*']);
    }
  }

  for (let key in table) {
    if (table[key].indices) setTableDefaults(table[key].indices);
    if (table[key].parents) setTableDefaults(table[key].parents);
  }
}

function mergeTable(table, defaultTable) {
  if (defaultTable.results)
    table.results = [].concat(defaultTable.results, table.results || []);

  if (
    (defaultTable.indices &&
      (defaultTable = defaultTable.indices) &&
      (table.indices = table.indices || {}) &&
      (table = table.indices)) ||
    (defaultTable.parents &&
      (defaultTable = defaultTable.parents) &&
      (table.parents = table.parents || {}) &&
      (table = table.parents))
  ) {
    for (let key in defaultTable) {
      if (!table[key]) table[key] = {};
      mergeTable(table[key], defaultTable[key]);
    }
  }
}

function setTableResults(table, results) {
  for (let key in table) {
    for (let index in table[key].indices) {
      const node = table[key].indices[index];
      if (results) node.results = [].concat(results, node.results || []);
      setTableResults(node.parents, node.results);
    }
  }
}

function rejectSelector(selector) {
  throw new TypeError(`Unsupported selector '${selector}'`);
}
