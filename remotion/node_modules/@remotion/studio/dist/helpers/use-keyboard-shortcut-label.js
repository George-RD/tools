"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useKeyboardShortcutAriaKeyShortcuts = exports.useKeyboardShortcutLabel = void 0;
const keyboard_shortcuts_1 = require("../components/keyboard-shortcuts");
const client_id_1 = require("./client-id");
const useKeyboardShortcutLabel = (action) => {
    (0, client_id_1.useStudioConfigRevision)();
    return (0, keyboard_shortcuts_1.getKeyboardShortcutLabel)(action);
};
exports.useKeyboardShortcutLabel = useKeyboardShortcutLabel;
const useKeyboardShortcutAriaKeyShortcuts = (action) => {
    (0, client_id_1.useStudioConfigRevision)();
    return (0, keyboard_shortcuts_1.getKeyboardShortcutAriaKeyShortcuts)(action);
};
exports.useKeyboardShortcutAriaKeyShortcuts = useKeyboardShortcutAriaKeyShortcuts;
