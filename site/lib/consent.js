// Minimal cookie-consent banner.
//
// Microsoft Clarity is non-essential analytics, so under GDPR/ePrivacy it must
// only load AFTER the visitor opts in. We remember the choice in localStorage
// ("granted" | "denied") and re-show the banner only if no choice was made.
(function () {
  var KEY = "tp-cookie-consent";
  var CLARITY_ID = "xehgfqw2i4";

  function loadClarity() {
    if (window.clarity) return;
    (function (c, l, a, r, i, t, y) {
      c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
      t = l.createElement(r); t.async = 1; t.src = "https://www.clarity.ms/tag/" + i;
      y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
    })(window, document, "clarity", "script", CLARITY_ID);
  }

  var choice = null;
  try { choice = localStorage.getItem(KEY); } catch (e) {}

  if (choice === "granted") { loadClarity(); return; }
  if (choice === "denied") { return; }

  function save(v) { try { localStorage.setItem(KEY, v); } catch (e) {} }

  function showBanner() {
    var bar = document.createElement("div");
    bar.setAttribute("role", "dialog");
    bar.setAttribute("aria-label", "Cookie consent");
    bar.style.cssText =
      "position:fixed;left:16px;right:16px;bottom:16px;z-index:9999;max-width:560px;" +
      "margin:0 auto;background:#0a0c16;color:#fff;border-radius:14px;padding:16px 18px;" +
      "box-shadow:0 12px 40px rgba(0,0,0,.28);font:14px/1.5 -apple-system,BlinkMacSystemFont," +
      "'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:flex;flex-wrap:wrap;align-items:center;gap:12px;";

    var txt = document.createElement("div");
    txt.style.cssText = "flex:1 1 240px;min-width:200px;";
    txt.innerHTML =
      'We use optional analytics cookies to improve the site. ' +
      'See our <a href="/privacy" style="color:#a99bff;text-decoration:underline;">Privacy Policy</a>.';

    var btns = document.createElement("div");
    btns.style.cssText = "display:flex;gap:8px;flex:0 0 auto;";

    var decline = document.createElement("button");
    decline.type = "button";
    decline.textContent = "Decline";
    decline.style.cssText =
      "cursor:pointer;border:1px solid rgba(255,255,255,.28);background:transparent;color:#fff;" +
      "border-radius:9px;padding:9px 14px;font:inherit;font-weight:600;";

    var accept = document.createElement("button");
    accept.type = "button";
    accept.textContent = "Accept";
    accept.style.cssText =
      "cursor:pointer;border:0;background:#4b1fe6;color:#fff;border-radius:9px;padding:9px 16px;" +
      "font:inherit;font-weight:600;";

    function close() { if (bar.parentNode) bar.parentNode.removeChild(bar); }
    accept.addEventListener("click", function () { save("granted"); loadClarity(); close(); });
    decline.addEventListener("click", function () { save("denied"); close(); });

    btns.appendChild(decline);
    btns.appendChild(accept);
    bar.appendChild(txt);
    bar.appendChild(btns);
    document.body.appendChild(bar);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", showBanner);
  } else {
    showBanner();
  }
})();
