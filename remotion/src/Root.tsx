import { Composition } from "remotion";
import { HelloWorld } from "./HelloWorld";
import { Logo } from "./HelloWorld/Logo";
import { RiveShowcase } from "./Rive/RiveShowcase";
import { ThreeShowcase } from "./Three/ThreeShowcase";

// Each <Composition> is an entry in the sidebar!

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        // You can take the "id" to render a video:
        // npx remotion render HelloWorld
        id="HelloWorld"
        component={HelloWorld}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
        // You can override these props for each render:
        // https://www.remotion.dev/docs/parametrized-rendering
        defaultProps={{
          titleText: "Welcome to Remotion",
          titleColor: "#000000",
          logoColor1: "#91EAE4",
          logoColor2: "#86A8E7",
        }}
      />

      {/* Mount any React component to make it show up in the sidebar and work on it individually! */}
      <Composition
        id="OnlyLogo"
        component={Logo}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          logoColor1: "#91dAE2",
          logoColor2: "#86A8E7",
        }}
      />

      {/* Rive integration — loads the animation and its WASM from local files
          only; see scripts/patch-remotion-rive-offline.sh. */}
      <Composition
        id="RiveShowcase"
        component={RiveShowcase}
        durationInFrames={90}
        fps={30}
        width={512}
        height={384}
      />

      {/* three.js via @remotion/three + @react-three/fiber, software GL. */}
      <Composition
        id="ThreeShowcase"
        component={ThreeShowcase}
        durationInFrames={90}
        fps={30}
        width={640}
        height={480}
      />
    </>
  );
};
