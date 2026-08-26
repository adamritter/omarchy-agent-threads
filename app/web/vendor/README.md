# Vendored web dependencies

Agent Chat loads these files only from its local Qt WebEngine page. Network
loading is disabled by both WebEngine settings and the page's content security
policy.

| Package | Version | Vendored artifact | SHA-256 |
| --- | --- | --- | --- |
| Marked | 17.0.5 | `marked/marked.umd.js` | `0db7abc826b5ac76f6ed11951ae34074ba50438ce6ea8d52889203779e5cbbad` |
| MathJax | 3.2.2 | `mathjax/es5/tex-chtml.js` | `0a6ded5abbce13331658dd239f34382abd06492c74b71b61e8caa8112ec55fa5` |

The artifacts come from the packages published by the Marked and MathJax
projects. Their upstream license files are included beside the artifacts.
