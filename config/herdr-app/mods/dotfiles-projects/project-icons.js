import { exists, mkdir, readFile, writeFile } from "fs/promises";
import { div, image } from "gpui-kit";
import { appHome } from "herdr";

const OVERRIDES = "data/dotfiles-projects/icons";
const CACHE = "data/dotfiles-projects/detected-icons";
const FORMATS = ["png", "webp"];
const STEMS = [".github/logo", "favicon", "public/favicon", "app/icon", "src/app/icon", "logo", "public/logo", "assets/logo", "icon"];
const COLORS = ["#a9cdf8", "#9cddc7", "#edb68d", "#cbb7fc", "#f6a8bb", "#bed991"];
const MAX_BYTES = 256 * 1024;

function hash(text) {
  let value = 2166136261;
  for (let i = 0; i < text.length; i++) value = Math.imul(value ^ text.charCodeAt(i), 16777619);
  return value >>> 0;
}

function validRaster(bytes, format) {
  if (bytes.length > MAX_BYTES) return false;
  return format === "png"
    ? [137, 80, 78, 71, 13, 10, 26, 10].every((n, i) => bytes[i] === n)
    : [82, 73, 70, 70, 87, 69, 66, 80].every((n, i) => bytes[i < 4 ? i : i + 4] === n);
}

async function readRaster(path, format) {
  try {
    if (!await exists(path)) return null;
    const bytes = await readFile(path);
    return validRaster(bytes, format) ? bytes : null;
  } catch { return null; }
}

export async function discoverProjectIcon(id, name, root, local) {
  const home = appHome();
  for (const format of FORMATS) {
    const override = `${OVERRIDES}/${name}.${format}`;
    if (await readRaster(`${home}/${override}`, format)) return override;
  }
  if (!local) return null;
  for (const stem of STEMS) {
    for (const format of FORMATS) {
      const bytes = await readRaster(`${root}/${stem}.${format}`, format);
      if (!bytes) continue;
      // GPUI resolves images from the app home, not from the checkout.
      const file = `${CACHE}/${hash(id).toString(16)}.${format}`;
      await mkdir(`${home}/${CACHE}`, { recursive: true });
      await writeFile(`${home}/${file}`, bytes);
      return file;
    }
  }
  return null;
}

export function projectIcon(id, name, path) {
  const tile = div().size(17).flex_none().rounded(4).overflow_hidden().flex().items_center().justify_center();
  if (path) return tile.child(image(path).size(17).flex_none());
  const initial = name.match(/[\p{L}\p{N}]/u)?.[0].toUpperCase() ?? "?";
  return tile.bg(COLORS[hash(id) % COLORS.length]).text_color("#202020").font_bold().text_size(10).child(initial);
}
