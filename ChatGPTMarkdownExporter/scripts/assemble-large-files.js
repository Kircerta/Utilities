"use strict";

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const root = path.resolve(__dirname, "..");
const targets = [
  {
    parts: "source-parts/chatgpt-adapter",
    output: "src/export/chatgpt-adapter.js",
    sha256: "b01cb39750e7350569de4682df64f4a211334c650afd8f460d018442261d1a27"
  },
  {
    parts: "source-parts/turndown",
    output: "vendor/turndown.js",
    sha256: "503e455e10504afe36fd557c869f439f3e06f3f86724ab58624c9353ba508eb6"
  }
];

for (const target of targets) {
  const partsDir = path.join(root, target.parts);
  const encoded = fs.readdirSync(partsDir)
    .filter((name) => /^part-\d+$/.test(name))
    .sort()
    .map((name) => fs.readFileSync(path.join(partsDir, name), "utf8").trim())
    .join("");
  const bytes = Buffer.from(encoded, "base64");
  const digest = crypto.createHash("sha256").update(bytes).digest("hex");
  if (digest !== target.sha256) throw new Error(`Checksum mismatch for ${target.output}`);
  const output = path.join(root, target.output);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, bytes);
  console.log(`assembled ${target.output}`);
}
