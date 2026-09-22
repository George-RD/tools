import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { ThreeCanvas } from "@remotion/three";
import { useRef } from "react";
import { Mesh } from "three";

// three.js scene rendered offline, through @remotion/three + @react-three/fiber.
//
// Everything here is local: three is installed in node_modules, and Remotion's
// own headless Chrome provides WebGL through its software GL renderer, so no
// GPU and no network are needed. The cube rotates with the frame number, so a
// correct render shows motion rather than a still.
export const ThreeShowcase: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const mesh = useRef<Mesh>(null);

  const rotation = (frame / fps) * 0.8;

  return (
    <AbsoluteFill style={{ backgroundColor: "#101014" }}>
      <ThreeCanvas
        width={width}
        height={height}
        // Software GL: this is a GPU-less headless render.
        gl={{ antialias: true }}
        camera={{ fov: 45, position: [0, 0, 5] }}
      >
        <ambientLight intensity={0.6} />
        <directionalLight position={[3, 3, 5]} intensity={2.2} />
        <mesh ref={mesh} rotation={[rotation * 0.6, rotation, 0]}>
          <boxGeometry args={[1.6, 1.6, 1.6]} />
          <meshStandardMaterial color="#b98d3f" />
        </mesh>
      </ThreeCanvas>
    </AbsoluteFill>
  );
};
