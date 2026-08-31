/** Vercel Speed Insights — loads only on production / preview Vercel hosts. */
(function () {
  var host = location.hostname;
  if (host !== "tomato.tmarhguy.com" && !/\.vercel\.app$/.test(host)) return;

  window.si =
    window.si ||
    function () {
      (window.siq = window.siq || []).push(arguments);
    };

  var tag = document.createElement("script");
  tag.defer = true;
  tag.src = "/_vercel/speed-insights/script.js";
  (document.head || document.documentElement).appendChild(tag);
})();
