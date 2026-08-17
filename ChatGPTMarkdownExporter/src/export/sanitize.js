"use strict";

(function registerSanitize(root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
    return;
  }

  root.ChatGPTMarkdownExporter = root.ChatGPTMarkdownExporter || {};
  root.ChatGPTMarkdownExporter.Sanitize = factory();
})(typeof globalThis !== "undefined" ? globalThis : this, function createSanitize() {
  const INVALID_FILENAME_CHARS = /[<>:"/\\|?*\x00-\x1F]/g;
  const COMBINING_MARKS = /[\u0300-\u036f]/g;

  function collapseBlankLines(value) {
    return String(value || "")
      .replace(/\r\n?/g, "\n")
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{3,}/g, "\n\n");
  }

  function cleanupCitationArtifacts(value) {
    return collapseBlankLines(
      String(value || "")
        .replace(/(?:^|\s)(?:cite|filecite|memcite)[^]+/g, " ")
        .replace(/[^]+/g, "")
        .replace(/^\s*\[\s*\]\s*$/gm, "")
    );
  }

  function safeSlug(title) {
    const slug = String(title || "conversation")
      .normalize("NFKD")
      .replace(COMBINING_MARKS, "")
      .replace(INVALID_FILENAME_CHARS, " ")
      .replace(/['`]/g, "")
      .replace(/[^a-zA-Z0-9._ -]+/g, " ")
      .trim()
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^\.+/, "")
      .replace(/[._-]+$/, "")
      .toLowerCase()
      .slice(0, 80);

    return slug || "conversation";
  }

  function pad(value) {
    return String(value).padStart(2, "0");
  }

  function formatFilenameTimestamp(dateValue) {
    const date = dateValue instanceof Date ? dateValue : new Date(dateValue);
    return [date.getFullYear(), pad(date.getMonth() + 1), pad(date.getDate())].join("") + "_" +
      [pad(date.getHours()), pad(date.getMinutes()), pad(date.getSeconds())].join("");
  }

  function createSafeFilename(title, dateValue) {
    const date = dateValue ? new Date(dateValue) : new Date();
    return `chatgpt_${safeSlug(title)}_${formatFilenameTimestamp(date)}.md`;
  }

  function stripYamlControl(value) {
    return String(value || "")
      .replace(/\r?\n/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  return {
    cleanupCitationArtifacts,
    collapseBlankLines,
    createSafeFilename,
    safeSlug,
    stripYamlControl
  };
});
