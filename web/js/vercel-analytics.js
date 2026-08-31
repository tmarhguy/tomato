/** Vercel Web Analytics — loads only on production / preview Vercel hosts. */
(function () {
  var host = location.hostname;
  if (host !== "tomato.tmarhguy.com" && !/\.vercel\.app$/.test(host)) return;

  window.va =
    window.va ||
    function () {
      (window.vaq = window.vaq || []).push(arguments);
    };

  var tag = document.createElement("script");
  tag.defer = true;
  tag.src = "/_vercel/insights/script.js";
  (document.head || document.documentElement).appendChild(tag);
})();
