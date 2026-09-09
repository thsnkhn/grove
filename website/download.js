const RELEASES_URL = "https://github.com/thsnkhn/grove/releases";
const DOWNLOADS = {
  appleSilicon: "https://github.com/thsnkhn/grove/releases/latest/download/Grove-Apple-Silicon.dmg",
  intel: "https://github.com/thsnkhn/grove/releases/latest/download/Grove-Intel.dmg",
};

const downloadLink = document.querySelector("[data-download-link]");
const downloadLabel = document.querySelector("[data-download-label]");

function setDownloadTarget(architecture) {
  const isAppleSilicon = architecture === "appleSilicon";

  downloadLink.href = DOWNLOADS[architecture];
  downloadLabel.textContent = `Download for ${isAppleSilicon ? "Apple silicon" : "Intel"}`;
}

function detectGraphicsArchitecture() {
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");

  if (!context) return null;

  const extension = context.getExtension("WEBGL_debug_renderer_info");
  const renderer = extension
    ? context.getParameter(extension.UNMASKED_RENDERER_WEBGL)
    : context.getParameter(context.RENDERER);

  if (/Apple M\d|Apple GPU/i.test(renderer)) return "appleSilicon";
  if (/Intel|Iris|UHD|HD Graphics/i.test(renderer)) return "intel";

  return null;
}

async function detectArchitecture() {
  if (navigator.userAgentData?.getHighEntropyValues) {
    try {
      const { architecture } = await navigator.userAgentData.getHighEntropyValues(["architecture"]);

      if (/arm/i.test(architecture)) return "appleSilicon";
      if (/x86|x86_64|amd64/i.test(architecture)) return "intel";
    } catch {
      // Fall through to the Safari-compatible graphics check.
    }
  }

  return detectGraphicsArchitecture();
}

if (downloadLink) {
  const isMac = /Macintosh|Mac OS X/i.test(navigator.userAgent);

  if (isMac) {
    detectArchitecture().then((architecture) => {
      if (architecture) setDownloadTarget(architecture);
    });
  } else {
    // TODO: Keep the fallback as the release page until a non-Mac download exists.
    downloadLink.href = RELEASES_URL;
  }
}
