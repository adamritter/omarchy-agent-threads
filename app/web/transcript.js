(function () {
  "use strict";

  const transcript = document.getElementById("transcript");
  const conversationTitle = document.getElementById("conversation-title");
  const conversationDetail = document.getElementById("conversation-detail");
  const emptyState = document.getElementById("empty-state");
  const busyIndicator = document.getElementById("busy-indicator");
  const maximumDocumentCharacters = 200000;
  const maximumFormulaCharacters = 20000;
  const maximumFormulas = 100;
  let renderRevision = 0;

  const allowedTags = new Set([
    "A", "BLOCKQUOTE", "BR", "CODE", "DEL", "EM", "H1", "H2", "H3", "H4",
    "H5", "H6", "HR", "LI", "OL", "P", "PRE", "S", "STRONG", "TABLE",
    "TBODY", "TD", "TH", "THEAD", "TR", "UL"
  ]);

  marked.setOptions({ gfm: true, breaks: false });

  function escapedAt(value, index) {
    let backslashes = 0;
    for (let cursor = index - 1; cursor >= 0 && value[cursor] === "\\"; cursor--) backslashes++;
    return backslashes % 2 === 1;
  }

  function closingIndex(value, delimiter, start, inline) {
    for (let cursor = start; cursor <= value.length - delimiter.length; cursor++) {
      if (inline && value[cursor] === "\n") return -1;
      if (value.startsWith(delimiter, cursor) && !escapedAt(value, cursor)) return cursor;
    }
    return -1;
  }

  function extractMath(source) {
    const value = String(source || "").slice(0, maximumDocumentCharacters);
    const nonce = crypto.getRandomValues(new Uint32Array(2)).join("");
    const formulas = [];
    let markdown = "";
    let cursor = 0;
    let fenced = false;

    while (cursor < value.length) {
      const lineStart = cursor === 0 || value[cursor - 1] === "\n";
      if (lineStart && (value.startsWith("```", cursor) || value.startsWith("~~~", cursor))) {
        const end = value.indexOf("\n", cursor);
        const lineEnd = end < 0 ? value.length : end + 1;
        markdown += value.slice(cursor, lineEnd);
        cursor = lineEnd;
        fenced = !fenced;
        continue;
      }
      if (fenced) {
        markdown += value[cursor++];
        continue;
      }
      if (value[cursor] === "`") {
        const end = closingIndex(value, "`", cursor + 1, true);
        if (end >= 0) {
          markdown += value.slice(cursor, end + 1);
          cursor = end + 1;
          continue;
        }
      }

      let open = "";
      let close = "";
      let display = false;
      if (value.startsWith("$$", cursor) && !escapedAt(value, cursor)) {
        open = close = "$$";
        display = true;
      } else if (value.startsWith("\\[", cursor) && !escapedAt(value, cursor)) {
        open = "\\[";
        close = "\\]";
        display = true;
      } else if (value.startsWith("\\(", cursor) && !escapedAt(value, cursor)) {
        open = "\\(";
        close = "\\)";
      } else if (value[cursor] === "$" && !escapedAt(value, cursor)
          && value[cursor + 1] && !/\s/.test(value[cursor + 1])) {
        open = close = "$";
      }

      if (open && formulas.length < maximumFormulas) {
        const end = closingIndex(value, close, cursor + open.length, !display);
        if (end >= 0 && (display || !/\s/.test(value[end - 1] || ""))) {
          const tex = value.slice(cursor + open.length, end).trim();
          if (tex && tex.length <= maximumFormulaCharacters) {
            const marker = `AGENTCHATMATH${nonce}X${formulas.length}END`;
            formulas.push({ tex, display, marker });
            markdown += display ? `\n\n${marker}\n\n` : marker;
            cursor = end + close.length;
            continue;
          }
        }
      }
      markdown += value[cursor++];
    }
    return { markdown, formulas };
  }

  function safeLink(value) {
    try {
      const url = new URL(String(value || ""), "file:///");
      return ["http:", "https:", "mailto:"].includes(url.protocol) ? url.href : "";
    } catch (_) {
      return "";
    }
  }

  function sanitize(node) {
    for (const child of Array.from(node.children || [])) {
      if (!allowedTags.has(child.tagName)) {
        child.replaceWith(document.createTextNode(child.textContent || ""));
        continue;
      }
      const href = child.tagName === "A" ? safeLink(child.getAttribute("href")) : "";
      for (const attribute of Array.from(child.attributes)) child.removeAttribute(attribute.name);
      if (href) child.setAttribute("href", href);
      sanitize(child);
    }
  }

  function markdownFragment(source) {
    const extracted = extractMath(source);
    const template = document.createElement("template");
    try {
      template.innerHTML = marked.parse(extracted.markdown);
    } catch (_) {
      template.textContent = String(source || "");
    }
    sanitize(template.content);
    return { fragment: template.content, formulas: extracted.formulas };
  }

  async function replaceMath(root, formulas) {
    if (!formulas.length) return;
    await MathJax.startup.promise;
    const byMarker = new Map(formulas.map((formula) => [formula.marker, formula]));
    const markerPattern = /AGENTCHATMATH\d+X\d+END/g;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const textNodes = [];
    while (walker.nextNode()) textNodes.push(walker.currentNode);

    for (const textNode of textNodes) {
      const matches = Array.from(textNode.data.matchAll(markerPattern));
      if (!matches.length) continue;
      const replacement = document.createDocumentFragment();
      let start = 0;
      for (const match of matches) {
        replacement.append(document.createTextNode(textNode.data.slice(start, match.index)));
        const formula = byMarker.get(match[0]);
        if (!formula) {
          replacement.append(document.createTextNode(match[0]));
        } else {
          try {
            replacement.append(await MathJax.tex2chtmlPromise(formula.tex, {
              display: formula.display
            }));
          } catch (_) {
            const error = document.createElement("code");
            error.className = "math-error";
            error.textContent = formula.tex;
            replacement.append(error);
          }
        }
        start = match.index + match[0].length;
      }
      replacement.append(document.createTextNode(textNode.data.slice(start)));
      textNode.replaceWith(replacement);
    }
    const stylesheet = MathJax.chtmlStylesheet();
    const previousStylesheet = document.getElementById("MJX-CHTML-styles");
    if (stylesheet && previousStylesheet) previousStylesheet.replaceWith(stylesheet);
    else if (stylesheet) document.head.append(stylesheet);
  }

  async function renderMarkdown(target, source) {
    const rendered = markdownFragment(source);
    target.replaceChildren(rendered.fragment);
    await replaceMath(target, rendered.formulas);
  }

  function textElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = String(text || "");
    return element;
  }

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
      const body = textElement("pre", "details-body", message.content || "");
      details.append(body);
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
      node.replaceChildren(...Array.from(body.childNodes));
    }
    if (node.dataset.renderRevision === revision) node.dataset.signature = signature;
  }

  async function setState(state) {
    const messages = Array.isArray(state && state.messages) ? state.messages : [];
    const busy = Boolean(state && state.busy);
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
        String(message && message.status || "")
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
    emptyState.hidden = messages.length > 0 || busy;
    busyIndicator.hidden = !busy;
    await Promise.all(updates);
    if (stickToBottom || busy) window.scrollTo({ top: document.documentElement.scrollHeight });
  }

  window.AgentChat = { setState };
}());
