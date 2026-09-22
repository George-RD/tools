import { AbsoluteFill, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { RemotionRiveCanvas } from "@remotion/rive";

// Rive animation rendered offline.
//
// Two things make this work with no network, both wired up in this repository:
//   * the .riv file is served from remotion/public/ via staticFile()
//   * @remotion/rive's WASM loader is repointed at remotion/public/rive.wasm
//     (upstream hardcodes an unpkg.com URL — see
//     scripts/patch-remotion-rive-offline.sh)
//
// The fixture is a 128x96 artboard with a linear animation that rotates a
// rectangle a quarter turn over 60 frames, so successive frames genuinely
// differ — a static frame would not prove the runtime is animating.
export const RiveShowcase: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Fade the backdrop only; the artboard itself is animated by the .riv file.
  const backdrop = `hsl(${(frame / durationInFrames) * 40 + 200} 12% ${12 + (frame % 2)}%)`;

  return (
    <AbsoluteFill style={{ backgroundColor: backdrop, justifyContent: "center", alignItems: "center" }}>
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <RemotionRiveCanvas
          src={staticFile("rive-demo.riv")}
          // The fixture artboard is named "ReferenceAnimated".
          artboard="ReferenceAnimated"
          fit="contain"
          style={{ width: 512, height: 384 }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
