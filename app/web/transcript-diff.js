(function () {
  "use strict";

  function textElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = String(text || "");
    return element;
  }

  function diffLineClass(line) {
    if (/^(diff --git |(?:ADD|DELETE|UPDATE|MOVE)  |--- |\+\+\+ )/.test(line))
      return "diff-file";
    if (/^@@/.test(line)) return "diff-hunk";
    if (/^\+(?!\+\+ )/.test(line)) return "diff-addition";
    if (/^-(?!--- )/.test(line)) return "diff-deletion";
    if (/^(index |new file |deleted file |similarity index |rename (?:from|to) |Binary files )/.test(line))
      return "diff-meta";
    return "diff-context";
  }

  function looksLikeDiff(value) {
    const text = String(value || "");
    return /(^|\n)(?:diff --git |@@ |(?:ADD|DELETE|UPDATE|MOVE)  )/.test(text)
      && /(^|\n)[+-][^+-]/.test(text);
  }

  function diffElement(value) {
    const lines = String(value || "").split("\n");
    const groups = [];
    let group = null;
    lines.forEach((line) => {
      if (/^(?:diff --git |(?:ADD|DELETE|UPDATE|MOVE)  )/.test(line)) {
        group = { lines: [] };
        groups.push(group);
      }
      if (!group) {
        group = { lines: [] };
        groups.push(group);
      }
      group.lines.push(line);
    });

    const fileGroups = [];
    const fileGroupsByPath = new Map();
    groups.filter((entry) => entry.lines.some((line) => line !== "")).forEach((entry) => {
      const gitHeader = entry.lines.find((line) => /^diff --git /.test(line)) || "";
      const operationHeader = entry.lines.find(
        (line) => /^(?:ADD|DELETE|UPDATE|MOVE)  /.test(line)) || "";
      const targetHeader = entry.lines.find((line) => /^\+\+\+ /.test(line)) || "";
      let path = operationHeader.replace(/^[A-Z]+  /, "");
      if (!path && gitHeader) {
        const match = gitHeader.match(/^diff --git (?:"?a\/.*?) (?:"?b\/)?(.+?)"?$/);
        path = match ? match[1] : gitHeader.replace(/^diff --git /, "");
      }
      if (!path && targetHeader) path = targetHeader.replace(/^\+\+\+ (?:b\/)?/, "");
      if (path && fileGroupsByPath.has(path)) {
        const existing = fileGroupsByPath.get(path);
        existing.lines.push("", ...entry.lines);
      } else {
        const next = { path, lines: entry.lines.slice() };
        fileGroups.push(next);
        if (path) fileGroupsByPath.set(path, next);
      }
    });

    const view = document.createElement("div");
    view.className = "details-body diff-view";
    fileGroups.forEach((entry) => {
      const additions = entry.lines.filter((line) => /^\+(?!\+\+ )/.test(line)).length;
      const deletions = entry.lines.filter((line) => /^-(?!--- )/.test(line)).length;

      const card = document.createElement("section");
      card.className = "diff-file-card";
      const header = document.createElement("header");
      header.className = "diff-card-header";
      header.append(textElement("span", "diff-card-path", entry.path || "File changes"));
      const stats = document.createElement("span");
      stats.className = "diff-card-stats";
      stats.append(textElement("span", "diff-stat-add", `+${additions}`));
      stats.append(document.createTextNode(" "));
      stats.append(textElement("span", "diff-stat-delete", `−${deletions}`));
      header.append(stats);
      card.append(header);

      const pre = document.createElement("pre");
      pre.className = "diff-lines";
      entry.lines.forEach((line, index) => {
        pre.append(textElement("span", `diff-line ${diffLineClass(line)}`, line));
        if (index < entry.lines.length - 1) pre.append(document.createTextNode("\n"));
      });
      card.append(pre);
      view.append(card);
    });
    return view;
  }

  function decorateMarkdownDiffs(root) {
    for (const pre of Array.from(root.querySelectorAll("pre"))) {
      const value = pre.textContent || "";
      if (!looksLikeDiff(value)) continue;
      const replacement = diffElement(value);
      replacement.classList.remove("details-body");
      pre.replaceWith(replacement);
    }
  }

  window.AgentChatDiff = {
    textElement, looksLikeDiff, diffElement, decorateMarkdownDiffs
  };
}());
