import type { AnyRenderJob } from '../components/RenderQueue/context';
import type { ModalState } from '../state/modals';
export declare const setCurrentCanvasContentId: (id: string | null) => void;
export declare const setRenderJobs: (jobs: AnyRenderJob[]) => void;
export declare const setCurrentModal: (modal: ModalState | null) => void;
