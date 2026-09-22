import type { SequenceNodePathInfo } from './get-timeline-sequence-sort-key';
export type CanvasSelectionItem = {
    readonly type: 'guide';
    readonly guideId: string;
} | {
    readonly type: 'sequence';
    readonly nodePathInfo: SequenceNodePathInfo;
} | {
    readonly type: 'sequence-prop';
    readonly nodePathInfo: SequenceNodePathInfo;
    readonly key: string;
} | {
    readonly type: 'sequence-all-effects';
    readonly nodePathInfo: SequenceNodePathInfo;
} | {
    readonly type: 'sequence-effect';
    readonly nodePathInfo: SequenceNodePathInfo;
    readonly i: number;
} | {
    readonly type: 'sequence-effect-prop';
    readonly nodePathInfo: SequenceNodePathInfo;
    readonly i: number;
    readonly key: string;
} | {
    readonly type: 'keyframe';
    readonly nodePathInfo: SequenceNodePathInfo;
    readonly frame: number;
} | {
    readonly type: 'easing';
    readonly nodePathInfo: SequenceNodePathInfo;
    readonly fromFrame: number;
    readonly toFrame: number;
    readonly segmentIndex: number;
};
export type CanvasSelectionSnapshot = {
    readonly selectedItems: readonly CanvasSelectionItem[];
    readonly anchor: CanvasSelectionItem | null;
};
export type CanvasSelectionInteraction = {
    readonly shiftKey: boolean;
    readonly toggleKey: boolean;
};
export declare const EMPTY_CANVAS_SELECTION: CanvasSelectionSnapshot;
export declare const getCanvasSequenceSelectionKey: (nodePathInfo: SequenceNodePathInfo) => string;
export declare const getCanvasSelectionItemKey: (item: CanvasSelectionItem) => string;
export declare const getCanvasSelectionAfterInteraction: ({ currentState, clickedItem, interaction, allSelectableItems, }: {
    readonly currentState: CanvasSelectionSnapshot;
    readonly clickedItem: CanvasSelectionItem;
    readonly interaction: CanvasSelectionInteraction;
    readonly allSelectableItems: readonly CanvasSelectionItem[];
}) => CanvasSelectionSnapshot;
export type CanvasSelectionController = {
    readonly getSnapshot: () => CanvasSelectionSnapshot;
    readonly subscribe: (listener: () => void) => () => void;
    readonly select: (item: CanvasSelectionItem, interaction: CanvasSelectionInteraction, allSelectableItems: readonly CanvasSelectionItem[]) => void;
    readonly setSelectedItems: (items: readonly CanvasSelectionItem[]) => void;
    readonly setSnapshot: (snapshot: CanvasSelectionSnapshot) => void;
    readonly clear: () => void;
};
export declare const createCanvasSelectionController: () => CanvasSelectionController;
export declare const useCanvasSelectionController: () => CanvasSelectionController;
export declare const useCanvasSelection: (controller: CanvasSelectionController) => CanvasSelectionSnapshot;
