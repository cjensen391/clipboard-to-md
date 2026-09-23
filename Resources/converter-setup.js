// Glue between Swift and Turndown. Kept as an external file so the page's
// Content-Security-Policy can stay strict (`script-src 'self'`, no inline JS).

// Built once at load; reused for every conversion.
var service = new TurndownService({
  headingStyle: 'atx',
  codeBlockStyle: 'fenced',
  bulletListMarker: '-',
  emDelimiter: '*',
  strongDelimiter: '**',
  linkStyle: 'inlined'
});

// GFM: tables, strikethrough, task lists.
service.use(turndownPluginGfm.gfm);

// Strip Google-Docs' internal wrapper spans that otherwise leak style noise.
service.addRule('stripGoogleDocsSpans', {
  filter: function (node) {
    return node.nodeName === 'SPAN' &&
      node.getAttribute('id') &&
      /^docs-internal-guid/.test(node.getAttribute('id'));
  },
  replacement: function (content) { return content; }
});

// Drop empty comment-anchor / zero-width anchors.
service.addRule('dropEmptyAnchors', {
  filter: function (node) {
    return node.nodeName === 'A' && !node.getAttribute('href') && node.textContent.trim() === '';
  },
  replacement: function () { return ''; }
});

// Exposed to Swift via callAsyncJavaScript. Returns a Markdown string.
window.convertHTMLToMarkdown = function (html) {
  return service.turndown(html);
};
