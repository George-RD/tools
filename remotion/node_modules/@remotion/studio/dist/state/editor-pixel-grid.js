"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EditorShowPixelGridContext = exports.loadEditorShowPixelGridOption = exports.persistEditorShowPixelGridOption = void 0;
const react_1 = require("react");
const key = 'remotion.editorShowPixelGrid';
const persistEditorShowPixelGridOption = (option) => {
    localStorage.setItem(key, String(option));
};
exports.persistEditorShowPixelGridOption = persistEditorShowPixelGridOption;
const loadEditorShowPixelGridOption = () => {
    const item = localStorage.getItem(key);
    return item !== 'false';
};
exports.loadEditorShowPixelGridOption = loadEditorShowPixelGridOption;
exports.EditorShowPixelGridContext = (0, react_1.createContext)({
    editorShowPixelGrid: true,
    setEditorShowPixelGrid: () => undefined,
});
