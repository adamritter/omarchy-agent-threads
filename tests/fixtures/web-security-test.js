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

    try {
      await window.AgentChat.setState({
        messages: [{ id: "security", role: "assistant", content: payload }]
      });
      const message = document.querySelector("article.message");
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
      const passed = window.agentChatSecurityProbe === "clean"
        && !unsafeElement && !eventAttribute && !unsafeLink && safeLink;
      document.documentElement.dataset.securityStatus = passed ? "pass" : "fail";
    } catch (error) {
      document.documentElement.dataset.securityStatus = "error";
      document.documentElement.dataset.securityError = String(error).slice(0, 200);
    }
  });
}());
