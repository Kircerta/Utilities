"use strict";

(function registerTableToMarkdown(root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
    return;
  }

  root.ChatGPTMarkdownExporter = root.ChatGPTMarkdownExporter || {};
  root.ChatGPTMarkdownExporter.TableToMarkdown = factory();
})(typeof globalThis !== "undefined" ? globalThis : this, function createTableToMarkdown() {
  function normalizeCellText(value) {
    return String(value || "")
      .replace(/\r\n?/g, "\n")
      .replace(/\s*\n+\s*/g, " / ")
      .replace(/\s+/g, " ")
      .trim()
      .replace(/\|/g, "\\|");
  }

  function getRowCells(row) {
    return Array.from(row.cells || row.querySelectorAll("th,td"));
  }

  function formatRow(cells, width) {
    const padded = cells.slice();
    while (padded.length < width) {
      padded.push("");
    }
    return `| ${padded.slice(0, width).join(" | ")} |`;
  }

  function tableElementToMarkdown(table) {
    const rows = Array.from(table.querySelectorAll("tr"))
      .map((row) => getRowCells(row).map((cell) => normalizeCellText(cell.textContent)))
      .filter((cells) => cells.some((cell) => cell.length > 0));

    if (rows.length === 0) {
      return "";
    }

    const width = Math.max(...rows.map((row) => row.length));
    const header = rows[0];
    const body = rows.slice(1);
    const separator = Array.from({ length: width }, () => "---");
    const lines = [formatRow(header, width), formatRow(separator, width)];

    for (const row of body) {
      lines.push(formatRow(row, width));
    }

    return lines.join("\n");
  }

  return {
    normalizeCellText,
    tableElementToMarkdown
  };
});

