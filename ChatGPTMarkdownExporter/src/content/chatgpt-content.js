"use strict";

(function attachChatGPTMarkdownExporter(root) {
  const namespace = root.ChatGPTMarkdownExporter || {};
  const adapter = namespace.ChatGPTAdapter;
  const renderer = namespace.MarkdownRenderer;
  const MESSAGE_TYPES = { EXPORT_AND_DOWNLOAD: "CGME_EXPORT_AND_DOWNLOAD" };

  function isChatGPTPage() {
    return root.location.hostname === "chatgpt.com" || root.location.hostname === "chat.openai.com";
  }

  async function buildExport(onProgress) {
    if (!adapter || !renderer) throw new Error("Exporter modules are not available.");
    const conversation = await adapter.extractConversation(document, {
      url: root.location.href,
      lazyLoad: { onProgress }
    });
    if (!conversation.messages.length) throw new Error("No ChatGPT conversation turns were found on this page.");
    return {
      ok: true,
      filename: renderer.createFilename(conversation.title, conversation.exportedAt),
      markdown: renderer.renderConversation(conversation),
      partial: Boolean(conversation.partial),
      messageCount: conversation.messages.length
    };
  }

  function downloadBlob(markdown, filename) {
    const blob = new Blob([markdown], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = "none";
    document.documentElement.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  }

  async function exportAndDownload(onProgress) {
    const result = await buildExport(onProgress);
    downloadBlob(result.markdown, result.filename);
    return { ok: true, filename: result.filename, partial: result.partial, messageCount: result.messageCount };
  }

  function createButton() {
    if (!isChatGPTPage() || document.getElementById("cgme-export-md-button")) return;
    if (!adapter || !document.querySelector("article[data-testid^='conversation-turn-'], [data-message-author-role], article[data-turn]")) return;

    const button = document.createElement("button");
    button.id = "cgme-export-md-button";
    button.type = "button";
    button.textContent = "Export MD";
    button.title = "Export current ChatGPT conversation as Markdown";

    button.addEventListener("click", async () => {
      const previous = button.textContent;
      button.disabled = true;
      button.textContent = "Exporting…";
      try {
        const result = await exportAndDownload((progress) => {
          if (progress && Number.isInteger(progress.staged)) button.textContent = `Collecting ${progress.staged}…`;
        });
        button.textContent = result.partial ? "Downloaded*" : "Downloaded";
      } catch (error) {
        button.textContent = "Error";
        console.error("ChatGPT Markdown Exporter:", error);
      } finally {
        setTimeout(() => {
          button.textContent = previous;
          button.disabled = false;
        }, 1600);
      }
    });

    document.documentElement.appendChild(button);
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (!message || message.type !== MESSAGE_TYPES.EXPORT_AND_DOWNLOAD) return false;
    exportAndDownload().then(sendResponse).catch((error) => sendResponse({ ok: false, error: error.message }));
    return true;
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", createButton, { once: true });
  } else {
    createButton();
  }

  let createButtonTimer = null;
  const observer = new MutationObserver(() => {
    if (createButtonTimer !== null) return;
    createButtonTimer = setTimeout(() => {
      createButtonTimer = null;
      createButton();
    }, 500);
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})(globalThis);
