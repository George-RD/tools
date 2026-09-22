// See all configuration options: https://remotion.dev/docs/config
// Each option also is available as a CLI flag: https://remotion.dev/docs/cli

// Note: When using the Node.JS APIs, the config file doesn't apply. Instead, pass options directly to the APIs

import {Config} from "@remotion/cli/config";
import {existsSync} from "node:fs";
import path from "node:path";

Config.setRspack(true);
Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);

// Point Remotion at the browser pinned inside this project, run through the
// launcher that supplies the vendored system libraries (needed on minimal
// hosts: no Chrome dependencies installed).
// Set REMOTION_USE_DEFAULT_BROWSER=1 to let Remotion manage its own browser.
// (Config is loaded as CJS, so resolve paths via __dirname when available.)
const configDir: string =
  typeof __dirname !== "undefined" ? __dirname : path.resolve(".");
const launcher = path.join(configDir, "bin", "browser-executable.sh");
if (!process.env.REMOTION_USE_DEFAULT_BROWSER && existsSync(launcher)) {
  Config.setBrowserExecutable(launcher);
}
