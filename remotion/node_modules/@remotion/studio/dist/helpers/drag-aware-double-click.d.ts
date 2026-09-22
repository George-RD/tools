export type DragAwareDoubleClickTracker = {
    readonly beginPointerGesture: (event: Pick<PointerEvent, 'button'>) => void;
    readonly endPointerGesture: (wasDragged: boolean) => void;
    readonly consumePointerGestureWasDragged: () => boolean;
    readonly acceptClickAsDoubleClick: (event: Pick<MouseEvent, 'button' | 'detail'>) => boolean;
};
export declare const createDragAwareDoubleClickTracker: () => DragAwareDoubleClickTracker;
