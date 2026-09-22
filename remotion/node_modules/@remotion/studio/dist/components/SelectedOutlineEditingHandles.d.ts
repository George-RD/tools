import React from 'react';
import type { SelectedOutline } from './selected-outline-geometry';
import type { SelectedOutlineContextMenuOpenHandler, SelectedOutlineLayoutTarget, SelectedOutlineRotationDragTarget, SelectedOutlineScaleDragTarget, SelectedOutlineTarget } from './selected-outline-types';
import type { TimelineSelection, TimelineSelectionInteraction } from './Timeline/TimelineSelection';
export declare const SelectedOutlineEditingHandles: React.FC<{
    readonly dragging: boolean;
    readonly getAllRotationDragTargets: () => readonly SelectedOutlineRotationDragTarget[];
    readonly getAllScaleDragTargets: () => readonly SelectedOutlineScaleDragTarget[];
    readonly getContextMenuOpenByKey: (key: string) => SelectedOutlineContextMenuOpenHandler | undefined;
    readonly getLatestTargetByKey: (key: string) => SelectedOutlineTarget | undefined;
    readonly layoutTarget: SelectedOutlineLayoutTarget | undefined;
    readonly onContextMenuOpenChange: (open: boolean) => void;
    readonly onDraggingChange: (dragging: boolean) => void;
    readonly onSelect: (item: TimelineSelection, interaction: TimelineSelectionInteraction) => void;
    readonly outline: SelectedOutline;
}>;
