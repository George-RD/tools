"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useCopyFeedback = void 0;
const react_1 = require("react");
const useCopyFeedback = () => {
    const [copyCount, setCopyCount] = (0, react_1.useState)(0);
    (0, react_1.useEffect)(() => {
        if (copyCount === 0) {
            return;
        }
        const timeout = setTimeout(() => setCopyCount(0), 2000);
        return () => clearTimeout(timeout);
    }, [copyCount]);
    const markCopied = (0, react_1.useCallback)(() => {
        setCopyCount((currentCopyCount) => currentCopyCount + 1);
    }, []);
    return { copied: copyCount > 0, markCopied };
};
exports.useCopyFeedback = useCopyFeedback;
