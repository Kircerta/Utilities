"use strict";

(function registerMarkdownRenderer(root, factory) {
  if (typeof module === "object" && module.exports) {
    const turndownModule = require("../../vendor/turndown.js");
    const tableToMarkdown = require("./table-to-markdown.js");
    const sanitize = require("./sanitize.js");
    module.exports = factory(turndownModule, tableToMarkdown, sanitize);
    return;
  }

  root.ChatGPTMarkdownExporter = root.ChatGPTMarkdownExporter || {};
  root.ChatGPTMarkdownExporter.MarkdownRenderer = factory(
    root.TurndownService,
    root.ChatGPTMarkdownExporter.TableToMarkdown,
    root.ChatGPTMarkdownExporter.Sanitize
  );
})(typeof globalThis !== "undefined" ? globalThis : this, function createMarkdownRenderer(
  turndownModule,
  tableToMarkdown,
  sanitize
) {
  const TurndownService =
    (turndownModule && (turndownModule.TurndownService || turndownModule.default)) ||
    turndownModule;

  const PARTIAL_WARNING =
    "> Export warning: collection could not prove beginning-to-end turn coverage. The Markdown below is the staged transcript that was successfully captured.";

  function getFenceFor(code) {
    const matches = String(code || "").match(/`{3,}/g) || [];
    const longest = matches.reduce((max, value) => Math.max(max, value.length), 2);
    return "`".repeat(longest + 1);
  }

  function getLanguage(node) {
    const code = node.nodeName === "CODE" ? node : node.querySelector("code");
    const candidates = [
      code && code.getAttribute("data-language"),
      code && code.getAttribute("data-lang"),
      code && code.getAttribute("class"),
      node.getAttribute("class")
    ].filter(Boolean);

    for (const candidate of candidates) {
      const match = String(candidate).match(/(?:language|lang)-([a-z0-9_+#.-]+)/i);
      if (match) {
        return match[1].replace(/[^a-zA-Z0-9_+#.-]/g, "");
      }
    }
    return "";
  }

  function createTurndownService() {
    if (typeof TurndownService !== "function") {
      throw new Error("TurndownService is not available.");
    }

    const service = new TurndownService({
      headingStyle: "atx",
      hr: "---",
      bulletListMarker: "-",
      codeBlockStyle: "fenced",
      fence: "```",
      emDelimiter: "_",
      strongDelimiter: "**",
      linkStyle: "inlined"
    });

    service.addRule("preserveMathPlaceholders", {
      filter(node) {
        return Boolean(node.getAttribute && node.getAttribute("data-cgme-math"));
      },
      replacement(_content, node) {
        const value = String(node.textContent || "").trim();
        if (!value) return "";
        return node.getAttribute("data-cgme-math") === "display"
          ? `\n\n$$\n${value}\n$$\n\n`
          : `$${value}$`;
      }
    });

    service.addRule("removeInterfaceNoise", {
      filter(node) {
        const name = node.nodeName;
        if (["BUTTON", "SCRIPT", "STYLE", "SVG"].includes(name)) return true;
        const label = node.getAttribute && (node.getAttribute("aria-label") || "");
        return /copy|share|more|feedback|thumb|listen|read aloud|good response|bad response|regenerate/i.test(label);
      },
      replacement() {
        return "";
      }
    });

    service.addRule("omitMediaElements", {
      filter: ["img", "picture", "video", "audio", "source", "canvas", "iframe", "object", "embed"],
      replacement() {
        return "";
      }
    });

    service.addRule("preserveCodeBlocks", {
      filter(node) {
        return node.nodeName === "PRE";
      },
      replacement(_content, node) {
        const code = node.querySelector("code") || node;
        const value = String(code.textContent || "").replace(/\n+$/g, "");
        const language = getLanguage(code) || getLanguage(node);
        const fence = getFenceFor(value);
        return `\n\n${fence}${language}\n${value}\n${fence}\n\n`;
      }
    });

    service.addRule("markdownTables", {
      filter: "table",
      replacement(_content, node) {
        const table = tableToMarkdown.tableElementToMarkdown(node);
        return table ? `\n\n${table}\n\n` : "";
      }
    });

    return service;
  }

  function htmlToMarkdown(html) {
    return sanitize.cleanupCitationArtifacts(
      createTurndownService().turndown(String(html || ""))
    ).trim();
  }

  function renderMessage(message) {
    const role = message.role === "user" ? "User" : "Assistant";
    const body = message.role === "user"
      ? sanitize.cleanupCitationArtifacts(message.text || "").trim()
      : (message.html ? htmlToMarkdown(message.html) : sanitize.cleanupCitationArtifacts(message.text || "").trim());
    const attachments = (message.attachments || [])
      .filter((item) => item && item.kind === "omitted")
      .map((item) => `[Attachment omitted: ${item.label || "file"}]`)
      .join("\n");
    const parts = [`## ${role}`];
    if (body) parts.push(body);
    if (attachments) parts.push(attachments);
    return parts.join("\n\n");
  }

  function renderConversation(conversation) {
    const exportedAt = conversation.exportedAt || new Date().toISOString();
    const title = sanitize.stripYamlControl(conversation.title) || "ChatGPT conversation";
    const url = sanitize.stripYamlControl(conversation.url || "");
    const messages = Array.isArray(conversation.messages) ? conversation.messages : [];
    const collection = conversation.collection || {};
    const coverage = collection.coverage || {};
    const parts = [
      "---",
      "source: ChatGPT",
      `url: ${url}`,
      `exported_at: ${exportedAt}`,
      `message_count: ${messages.length}`,
      `collection_status: ${conversation.partial ? "partial" : "complete"}`,
      `collection_sweeps: ${Number.isInteger(collection.sweeps) ? collection.sweeps : 0}`,
      "attachments_policy: uploaded files and media omitted; visible text included",
      "---",
      "",
      `# ${title}`
    ];

    if (conversation.partial) {
      parts.push("", PARTIAL_WARNING);
      if (Array.isArray(coverage.gaps) && coverage.gaps.length) {
        parts.push("", `> Detected missing turn indices: ${coverage.gaps.join(", ")}${coverage.gaps.length >= 100 ? ", …" : ""}`);
      } else if (coverage.allIndexed && coverage.minIndex > 1) {
        parts.push("", `> Earliest captured turn index: ${coverage.minIndex}; the beginning of the conversation was not exposed.`);
      }
    }
    for (const message of messages) parts.push("", renderMessage(message));

    return `${sanitize.cleanupCitationArtifacts(sanitize.collapseBlankLines(parts.join("\n")).trim())}\n`;
  }

  function createFilename(title, exportedAt) {
    return sanitize.createSafeFilename(title || "conversation", exportedAt || new Date());
  }

  return { createFilename, createTurndownService, htmlToMarkdown, renderConversation };
});
