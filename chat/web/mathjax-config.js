// Purpose: Configures MathJax rendering for the Agent Chat transcript.
window.MathJax = {
  tex: {
    packages: ["base", "ams", "newcommand", "noundefined"],
    maxBuffer: 20000
  },
  chtml: {
    displayAlign: "left",
    displayIndent: "0"
  },
  options: {
    enableMenu: false
  },
  startup: {
    typeset: false
  }
};
