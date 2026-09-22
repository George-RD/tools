"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCurrentError = exports.registerCurrentError = void 0;
const registerCurrentError = (error) => {
    var _a;
    window.remotion_currentErrors = [
        ...((_a = window.remotion_currentErrors) !== null && _a !== void 0 ? _a : []),
        error,
    ];
    return () => {
        var _a;
        window.remotion_currentErrors = (_a = window.remotion_currentErrors) === null || _a === void 0 ? void 0 : _a.filter((candidate) => candidate !== error);
    };
};
exports.registerCurrentError = registerCurrentError;
const getCurrentError = () => {
    var _a;
    var _b;
    return (_b = (_a = window.remotion_currentErrors) === null || _a === void 0 ? void 0 : _a[0]) !== null && _b !== void 0 ? _b : null;
};
exports.getCurrentError = getCurrentError;
