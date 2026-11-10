// Shared by every site published here: publish.sh adds <script src="/cache-verification.js"> to the site's index.html.
// Only checks the cache: the build information is static in the page (data-build-* on <html>).
// - cache.json, next to index.html, holds the build online now ({"buildVersion": <number>}); read with the current
//   date and time in the query, it never comes from a cache.
// - When the page's data-build-version is lower, the page came from a cache: reloads once with ?build=<number>, a URL
//   never cached; when the URL already has it, keeps the page (no loop).
(function () {
  var vPageVersion = Number(document.documentElement.getAttribute("data-build-version"));

  fetch("cache.json?t=" + encodeURIComponent(new Date().toISOString()), { cache: "no-store" })
    .then(function (pResponse) {
      return pResponse.ok ? pResponse.json() : null;
    })
    .then(function (pCache) {
      if (!pCache || !(vPageVersion < pCache.buildVersion)) {
        return;
      }
      var vUrl = new URL(window.location.href);
      if (vUrl.searchParams.get("build") === String(pCache.buildVersion)) {
        return;
      }
      vUrl.searchParams.set("build", pCache.buildVersion);
      window.location.replace(vUrl.toString());
    })
    .catch(function () {});
})();
