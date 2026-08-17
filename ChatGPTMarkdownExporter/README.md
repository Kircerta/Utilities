# ChatGPT Markdown Exporter

Manifest V3 Chrome extension for exporting the currently open ChatGPT conversation as a tidy local Markdown file.

## What it exports

- User and assistant turns in chronological order.
- Rendered assistant Markdown, including headings, lists, links, fenced code, tables, and common KaTeX/MathJax formulas.
- Visible user text verbatim enough for reuse as agent context.
- Uploaded files/images are not embedded; they are represented as `[Attachment omitted: ...]` when detectable.
- Front matter records the source URL, export time, and message count.

The exporter uses a local `Blob` download. Conversation text is not sent to a backend.


## GitHub checkout

The GitHub copy stores the two largest source files as lossless Base64 parts because of connector transfer limits. After cloning, run:

```bash
node scripts/assemble-large-files.js
```

This reconstructs `src/export/chatgpt-adapter.js` and `vendor/turndown.js` and verifies their SHA-256 hashes. The packaged ZIP already contains both files and needs no assembly.

## Load unpacked in Chrome

1. Unzip the archive.
2. Open `chrome://extensions`.
3. Enable **Developer mode**.
4. Click **Load unpacked**.
5. Select the `ChatGPTMarkdownExporter` folder.
6. Open or reload a ChatGPT conversation.
7. Click the injected **Export MD** button at bottom-right, or use the extension popup.

## Long conversations

Export is deliberately two-stage.

1. **History loading:** the collector drives the oldest rendered turn to the viewport edge and waits for actual transcript progress rather than assuming a fixed delay. It briefly leaves/re-enters the top edge when needed to retrigger intersection/scroll based pagination.
2. **Mutation-driven staging:** a `MutationObserver` runs for the whole collection. Every transient rendered turn is serialized immediately before React can virtualize it away. Down/up sweeps then fill any windows that pagination or layout changes skipped.
3. **Rendering:** only after collection stabilizes does the extension sort the frozen stage and render one Markdown file.

For indexed ChatGPT turns, a collection is considered complete only when the first captured turn is index `0` or `1`, all indices through the newest captured turn are contiguous, and both transcript edges were reached. Otherwise the file is explicitly marked `collection_status: partial` and reports detected gaps when possible.

If export starts near the bottom, the conversation is returned to the bottom afterward; otherwise the original numeric scroll position is restored. The injected button displays the staged turn count while scanning.

Each staged assistant turn captures the complete author-role subtree instead of only the first `.markdown` node, so generated file/artifact cards and tool-result siblings are retained as text/links. Code blocks snapshot rendered `innerText` before DOM cloning to preserve visual line breaks.

## Verification

Run `npm run scan:remote-code` after assembly. The packaged v0.3.0 build was also exercised in Chromium against a synthetic 50-turn virtualized conversation with delayed history pagination, artifact-card capture, and multiline-code preservation.

## Scope / limitations

- Current conversation only; alternate branches that are not visible in the page are not exported.
- Rich UI widgets are reduced to visible text when possible; media itself is omitted.
- ChatGPT DOM structure is not a public stable API, so selectors may require maintenance after UI changes.
