const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const srcDir = path.join(root, "src");
const distDir = path.join(root, "dist");

fs.mkdirSync(distDir, { recursive: true });

for (const file of ["main.js", "preload.js", "index.html"]) {
  const from = path.join(srcDir, file);
  const to = path.join(distDir, file);
  if (!fs.existsSync(from)) {
    throw new Error(`Missing source file: ${from}`);
  }
  fs.copyFileSync(from, to);
  console.log(`Copied ${file} -> dist/`);
}

console.log("Build finished.");
