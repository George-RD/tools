type State = {
    editorShowPixelGrid: boolean;
    setEditorShowPixelGrid: (cb: (prevState: boolean) => boolean) => void;
};
export declare const persistEditorShowPixelGridOption: (option: boolean) => void;
export declare const loadEditorShowPixelGridOption: () => boolean;
export declare const EditorShowPixelGridContext: import("react").Context<State>;
export {};
