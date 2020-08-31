module.exports = {
  fromFirstMateScopeId(firstMateScopeId) {
    let atomScopeId = -firstMateScopeId;
    if ((atomScopeId & 1) === 0) atomScopeId--;
    return atomScopeId + 256;
  },

  toFirstMateScopeId(atomScopeId) {
    return -(atomScopeId - 256);
  }
};
