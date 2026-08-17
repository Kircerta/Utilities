"use strict";

const fs = require("node:fs");
const path = require("node:path");

const scanRoots = ["manifest.json", "src", "vendor"];
const executableRemotePatterns = [
  /importScripts\s*\(\s*["']https?:\/\//i,
  /(?:src|href)\s*=\s*["']https?:\/\//i,
  /fetch\s*\(\s*["']https?:\/\//i,
  /new\s+Worker\s*\(\s*["']https?:\/\//i,
  /chrome\.scripting\.executeScript[\s\S]*https?:\/\//i
];
const allowedLiteralPatterns = [
  /https:\/\/chatgpt\.com\/\*/,
  /https:\/\/chat\.openai\.com\/\*/
];

function listFiles(target) {
  const stat = fs.statSync(target);
  if (stat.isFile()) {
    return [target];
  }

  return fs.readdirSync(target).flatMap((entry) => listFiles(path.join(target, entry)));
}

const problems = [];

for (const file of scanRoots.flatMap(listFiles)) {
  const content = fs.readFileSync(file, "utf8");
  const suspicious = executableRemotePatterns.some((pattern) => pattern.test(content));
  const hasAllowedOnly = allowedLiteralPatterns.some((pattern) => pattern.test(content));

  if (suspicious && !hasAllowedOnly) {
    problems.push(`Remote executable code pattern found in ${file}`);
  }
}

if (problems.length > 0) {
  console.error(problems.join("\n"));
  process.exit(1);
}

console.log("Remote-code scan passed");

