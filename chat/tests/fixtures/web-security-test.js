(function () {
  "use strict";

  window.addEventListener("load", async () => {
    window.agentChatSecurityProbe = "clean";
    const payload = [
      "<script>window.agentChatSecurityProbe = 'script-ran'</script>",
      "<img src=x onerror=\"window.agentChatSecurityProbe='event-ran'\">",
      "<svg onload=\"window.agentChatSecurityProbe='svg-ran'\"></svg>",
      "[unsafe script](javascript:window.agentChatSecurityProbe='link-ran')",
      "[unsafe file](file:///etc/passwd)",
      "[safe link](https://example.test/path)"
    ].join("\n\n");

    const check = (condition, message) => {
      if (!condition) throw new Error(message);
    };

    try {
      check(window.AgentChat && typeof window.AgentChat.setState === "function",
        "transcript API did not load");
      check(window.AgentChatMarkdown && window.AgentChatDiff && window.marked
        && window.MathJax, "local renderer dependencies did not load");
      const policy = document.querySelector(
        'meta[http-equiv="Content-Security-Policy"]');
      check(policy && /connect-src 'none'/.test(policy.content),
        "network connections are not disabled");

      await window.AgentChat.setState({ messages: [], loading: true });
      check(document.getElementById("empty-state").hidden,
        "loading state exposed the empty prompt");

      await window.AgentChat.setState({
        header: { title: "Behavior contract", detail: "/work/demo · local" },
        messages: [
          { id: "security", role: "assistant", content: payload },
          { id: "math", role: "assistant", content: "# Result\n\n$x^2 = 4$" },
          {
            id: "patch",
            role: "tool",
            title: "Updated src/a.js",
            kind: "file",
            status: "failed",
            content: [
              "diff --git a/src/a.js b/src/a.js",
              "--- a/src/a.js",
              "+++ b/src/a.js",
              "@@ -1 +1 @@",
              "-old",
              "+new"
            ].join("\n"),
            output: "patch rejected"
          }
        ]
      });
      check(document.getElementById("conversation-title").textContent
        === "Behavior contract", "conversation title was not rendered");
      check(document.getElementById("conversation-detail").textContent
        === "/work/demo · local", "conversation detail was not rendered");
      check(document.getElementById("empty-state").hidden,
        "rendered messages did not hide the empty prompt");

      const message = document.querySelector('[data-key="security"]');
      const unsafeElement = message.querySelector("script,img,svg,iframe,object,style");
      const eventAttribute = Array.from(message.querySelectorAll("*"))
        .some((element) => Array.from(element.attributes)
          .some((attribute) => attribute.name.toLowerCase().startsWith("on")));
      const links = Array.from(message.querySelectorAll("a"));
      const unsafeLink = links.some((link) => {
        const href = link.getAttribute("href") || "";
        return href !== "" && !/^(https?:|mailto:)/i.test(href);
      });
      const safeLink = links.some((link) =>
        link.href === "https://example.test/path");
      check(window.agentChatSecurityProbe === "clean" && !unsafeElement
        && !eventAttribute && !unsafeLink && safeLink,
      "unsafe markdown reached the rendered document");

      const math = document.querySelector('[data-key="math"]');
      check(math.querySelector("h1") && math.querySelector("mjx-container"),
        "Markdown or LaTeX did not render");
      const patch = document.querySelector('[data-key="patch"]');
      const addition = patch.querySelector(".diff-addition");
      const deletion = patch.querySelector(".diff-deletion");
      const output = patch.querySelector(".patch-output.error");
      check(patch.querySelectorAll(".diff-file-card").length === 1
        && patch.querySelector(".diff-card-stats")
        && addition && deletion, "file diff was not rendered as a card");
      check(output && output.textContent === "patch rejected",
        "tool output was not rendered with failure state");
      check(getComputedStyle(addition).backgroundColor
        !== getComputedStyle(deletion).backgroundColor,
      "diff addition and deletion styles were not applied");
      check(getComputedStyle(document.getElementById("conversation-header"))
        .borderBottomStyle !== "none", "header stylesheet was not applied");

      let scrollOperation = "";
      window.scrollBy = (options) => { scrollOperation = `page:${options.top}`; };
      window.AgentChat.scrollPage(-1);
      check(scrollOperation.startsWith("page:-"), "page-up routing failed");
      window.scrollTo = (options) => { scrollOperation = `edge:${options.top}`; };
      window.AgentChat.scrollEdge(-1);
      check(scrollOperation === "edge:0", "top-edge routing failed");

      document.documentElement.dataset.securityStatus = "pass";
      document.documentElement.dataset.behaviorStatus = "pass";
    } catch (error) {
      document.documentElement.dataset.securityStatus = "error";
      document.documentElement.dataset.behaviorStatus = "error";
      document.documentElement.dataset.securityError = String(error).slice(0, 200);
    }
  });
}());
