"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.compositionSelectorDragDataToSymbolicatedStack = exports.parseCompositionSelectorDragData = exports.hasCompositionSelectorDragData = exports.makeCompositionSelectorDragData = void 0;
const MIME_TYPE = 'application/remotion-composition-selector-reorder';
const isSafeString = (value, maxLength) => {
    return (typeof value === 'string' &&
        value.length > 0 &&
        value.length <= maxLength &&
        !value.includes('\0'));
};
const isCompositionOrFolder = (value) => {
    if (typeof value !== 'object' || value === null) {
        return false;
    }
    const item = value;
    if (item.type === 'composition') {
        return isSafeString(item.compositionId, 500);
    }
    return (item.type === 'folder' &&
        isSafeString(item.folderName, 500) &&
        (item.parentName === null || isSafeString(item.parentName, 2000)));
};
const isSafeSourceFile = (value) => {
    return (value === null ||
        (isSafeString(value, 2000) &&
            !value.includes('\\') &&
            !value.startsWith('/') &&
            !value.split('/').includes('..')));
};
const makeCompositionSelectorDragData = ({ item, sourceFile, }) => {
    const data = {
        type: 'remotion-composition-selector',
        version: 1,
        item,
        sourceFile,
    };
    return { mimeType: MIME_TYPE, payload: JSON.stringify(data), data };
};
exports.makeCompositionSelectorDragData = makeCompositionSelectorDragData;
const hasCompositionSelectorDragData = (mimeTypes) => {
    return Array.from(mimeTypes).includes(MIME_TYPE);
};
exports.hasCompositionSelectorDragData = hasCompositionSelectorDragData;
const parseCompositionSelectorDragData = (dataTransfer) => {
    if (!(0, exports.hasCompositionSelectorDragData)(dataTransfer.types)) {
        return null;
    }
    try {
        const parsed = JSON.parse(dataTransfer.getData(MIME_TYPE));
        if (parsed.type !== 'remotion-composition-selector' ||
            parsed.version !== 1 ||
            !isCompositionOrFolder(parsed.item) ||
            !isSafeSourceFile(parsed.sourceFile)) {
            return null;
        }
        return {
            type: 'remotion-composition-selector',
            version: 1,
            item: parsed.item,
            sourceFile: parsed.sourceFile,
        };
    }
    catch (_a) {
        return null;
    }
};
exports.parseCompositionSelectorDragData = parseCompositionSelectorDragData;
const compositionSelectorDragDataToSymbolicatedStack = (dragData) => {
    if (dragData.sourceFile === null) {
        return null;
    }
    return {
        originalColumnNumber: null,
        originalFileName: dragData.sourceFile,
        originalFunctionName: null,
        originalLineNumber: null,
        originalScriptCode: null,
    };
};
exports.compositionSelectorDragDataToSymbolicatedStack = compositionSelectorDragDataToSymbolicatedStack;
