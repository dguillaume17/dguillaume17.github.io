// Shared by every site published here: publish.sh adds data-index-version="<build number>" to the <html> tag of the
// site's index.html, and <script src="/build-check.js" data-badge="true|false"> before its </head>.
// - Reads build.json (the build online now) with the current date and time in the query: never served from a cache.
// - Sets data-build-version and data-build-branch on <html>.
// - When data-index-version < data-build-version, the page comes from a cache: reloads once with ?build=<number>,
//   a URL never cached (when the URL already has it, keeps the page: no loop).
// - Shows « n° <index version> · <branch> » in a small badge, unless data-badge="false".
(function () {
  var vRoot = document.documentElement;
  var vIndexVersion = Number(vRoot.getAttribute("data-index-version"));
  var vScript = document.currentScript;
  var vShowBadge = !vScript || vScript.getAttribute("data-badge") !== "false";

  function showBadge(pBranch) {
    var vBadge = document.createElement("div");
    vBadge.textContent = "n° " + vIndexVersion + " · " + pBranch;
    vBadge.setAttribute(
      "style",
      "position:fixed;right:8px;bottom:8px;z-index:2147483647;padding:2px 8px;border-radius:10px;" +
        "background:rgba(0,0,0,.6);color:#fff;font:11px/1.6 system-ui,sans-serif;pointer-events:none"
    );
    document.body.appendChild(vBadge);
  }

  fetch("build.json?t=" + encodeURIComponent(new Date().toISOString()), { cache: "no-store" })
    .then(function (pResponse) {
      return pResponse.ok ? pResponse.json() : null;
    })
    .then(function (pBuild) {
      if (!pBuild) {
        return;
      }
      vRoot.setAttribute("data-build-version", pBuild.number);
      vRoot.setAttribute("data-build-branch", pBuild.branch);

      if (vIndexVersion < pBuild.number) {
        var vUrl = new URL(window.location.href);
        if (vUrl.searchParams.get("build") !== String(pBuild.number)) {
          vUrl.searchParams.set("build", pBuild.number);
          window.location.replace(vUrl.toString());
          return;
        }
      }

      if (vShowBadge) {
        if (document.body) {
          showBadge(pBuild.branch);
        } else {
          document.addEventListener("DOMContentLoaded", function () {
            showBadge(pBuild.branch);
          });
        }
      }
    })
    .catch(function () {});
})();
