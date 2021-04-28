exports.native = function loadNative(condition) {
    if (condition) {
        return require('../build/Release/native.node');
    } else {
        return null;
    }
}
