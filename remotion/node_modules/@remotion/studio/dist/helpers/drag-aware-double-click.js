"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createDragAwareDoubleClickTracker = void 0;
const createDragAwareDoubleClickTracker = () => {
    let pointerGestureWasDragged = false;
    let previousPointerButton = null;
    let currentPointerButton = null;
    return {
        beginPointerGesture: (event) => {
            pointerGestureWasDragged = false;
            previousPointerButton = currentPointerButton;
            currentPointerButton = event.button;
        },
        endPointerGesture: (wasDragged) => {
            pointerGestureWasDragged = wasDragged;
        },
        consumePointerGestureWasDragged: () => {
            const wasDragged = pointerGestureWasDragged;
            pointerGestureWasDragged = false;
            return wasDragged;
        },
        acceptClickAsDoubleClick: (event) => {
            return (event.button === 0 &&
                event.detail > 0 &&
                event.detail % 2 === 0 &&
                (event.detail > 2 ||
                    (previousPointerButton === 0 && currentPointerButton === 0)));
        },
    };
};
exports.createDragAwareDoubleClickTracker = createDragAwareDoubleClickTracker;
