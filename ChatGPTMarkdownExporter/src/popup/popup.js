"use strict";

const MESSAGE_TYPE = "CGME_EXPORT_AND_DOWNLOAD";
const exportButton = document.getElementById("export-current-chat");
const statusNode = document.getElementById("status");

function setStatus(value) { statusNode.textContent = value; }
async function getActiveTab() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  return tabs[0];
}
function isChatGPTUrl(url) {
  try {
    const host = new URL(url).hostname;
    return host === "chatgpt.com" || host === "chat.openai.com";
  } catch (_error) { return false; }
}

exportButton.addEventListener("click", async () => {
  exportButton.disabled = true;
  setStatus("Exporting…");
  try {
    const tab = await getActiveTab();
    if (!tab || !isChatGPTUrl(tab.url)) throw new Error("Open a ChatGPT conversation first.");
    const result = await chrome.tabs.sendMessage(tab.id, { type: MESSAGE_TYPE });
    if (!result || !result.ok) throw new Error((result && result.error) || "Export failed.");
    setStatus(result.partial ? `Downloaded ${result.messageCount} messages (partial warning)` : `Downloaded ${result.messageCount} messages`);
  } catch (error) {
    setStatus(`Error: ${error.message}`);
  } finally {
    exportButton.disabled = false;
  }
});
