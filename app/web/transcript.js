(function () {
  "use strict";

  const transcript = document.getElementById("transcript");
  const conversationTitle = document.getElementById("conversation-title");
  const conversationDetail = document.getElementById("conversation-detail");
  const emptyState = document.getElementById("empty-state");
  const busyIndicator = document.getElementById("busy-indicator");
  const maximumDocumentCharacters = 200000;
  let renderRevision = 0;
  const { renderMarkdown } = window.AgentChatMarkdown;
  const { textElement, looksLikeDiff, diffElement, decorateMarkdownDiffs } = window.AgentChatDiff;

  async function updateMessage(node, message, signature) {
    const role = String(message.role || "assistant");
    const revision = String(++renderRevision);
    node.dataset.renderRevision = revision;
    node.className = `message ${role}`;

    if (role === "user" || role === "error") {
      node.textContent = String(message.content || "");
    } else if (role === "tool") {
      const details = document.createElement("details");
      details.append(textElement("summary", "", message.title || "Tool"));
      const content = String(message.content || "");
      const body = message.kind === "file" || looksLikeDiff(content)
        ? diffElement(content) : textElement("pre", "details-body", content);
      details.append(body);
      const output = String(message.output || "");
      if (output.trim())
        details.append(textElement("pre", `patch-output ${message.status === "failed" ? "error" : ""}`, output));
      node.replaceChildren(details);
    } else if (role === "reasoning") {
      const details = document.createElement("details");
      details.append(textElement("summary", "", "Reasoning"));
      const body = document.createElement("div");
      body.className = "details-body";
      details.append(body);
      await renderMarkdown(body, message.content || "");
      if (node.dataset.renderRevision !== revision) return;
      node.replaceChildren(details);
    } else {
      const body = document.createElement("div");
      await renderMarkdown(body, message.content || "");
      if (node.dataset.renderRevision !== revision) return;
      decorateMarkdownDiffs(body);
      node.replaceChildren(...Array.from(body.childNodes));
    }
    if (node.dataset.renderRevision === revision) node.dataset.signature = signature;
  }

  async function setState(state) {
    const messages = Array.isArray(state && state.messages) ? state.messages : [];
    const busy = Boolean(state && state.busy);
    const loading = Boolean(state && state.loading);
    const stickToBottom = document.documentElement.scrollHeight - window.innerHeight - window.scrollY < 90;
    const header = state && state.header && typeof state.header === "object"
      ? state.header : {};
    conversationTitle.textContent = String(header.title || "New conversation");
    conversationDetail.textContent = String(header.detail || "");
    const existing = new Map(Array.from(transcript.children).map((node) => [node.dataset.key, node]));
    const retained = new Set();
    const updates = [];

    messages.forEach((message, index) => {
      const role = String(message && message.role || "assistant");
      const key = String(message && message.id || `${role}-${index}`);
      const signature = JSON.stringify([
        role,
        String(message && message.title || ""),
        String(message && message.content || ""),
        String(message && message.status || ""),
        String(message && message.kind || ""),
        String(message && message.output || "")
      ]);
      let node = existing.get(key);
      if (!node) {
        node = document.createElement("article");
        node.dataset.key = key;
      }
      retained.add(key);
      transcript.append(node);
      if (node.dataset.signature !== signature) updates.push(updateMessage(node, message || {}, signature));
    });

    for (const [key, node] of existing) if (!retained.has(key)) node.remove();
    emptyState.hidden = messages.length > 0 || busy || loading;
    busyIndicator.hidden = !busy;
    await Promise.all(updates);
    if (stickToBottom || busy) window.scrollTo({ top: document.documentElement.scrollHeight });
  }

  function scrollPage(direction) {
    const sign = Number(direction) < 0 ? -1 : 1;
    window.scrollBy({
      top: Math.round(window.innerHeight * 0.85) * sign,
      behavior: "smooth"
    });
  }

  function scrollEdge(edge) {
    window.scrollTo({
      top: Number(edge) < 0 ? 0 : document.documentElement.scrollHeight,
      behavior: "smooth"
    });
  }

  window.AgentChat = { setState, scrollPage, scrollEdge };
}());
