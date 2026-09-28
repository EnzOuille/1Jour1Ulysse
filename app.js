/* ==========================================================
   1 Jour 1 Ulysse — logique du site
   La photo de chaque jour vient du calendrier (photos.js),
   généré par update-photos.ps1 : un jour passé garde toujours
   sa photo. Un jour absent du calendrier reste sans photo,
   jusqu'à ce que de nouvelles photos viennent le compléter.
   ========================================================== */
(() => {
  "use strict";

  // ---------- Configuration ----------
  const START_DATE = "2026-09-18"; // « Jour 1 » du site (AAAA-MM-JJ)
  const BIRTH_DATE = "2023-07-10"; // naissance d'Ulysse
  const PORTRAIT = "photos/portrait.jpg"; // photo de la présentation
  const ARCHIVE_PAGE = 24;         // nombre de jours affichés par « Afficher plus »

  const PHOTOS = Array.isArray(window.ULYSSE_PHOTOS) ? window.ULYSSE_PHOTOS : [];
  const CALENDAR = window.ULYSSE_CALENDAR || {};

  // ---------- Dates ----------
  // Un jour est représenté par un entier (jours depuis 1970), calculé en UTC
  // à partir de la date locale : pas de surprise avec l'heure d'été.
  const DAY_MS = 86400000;
  const parseISO = (s) => { const [y, m, d] = s.split("-").map(Number); return Date.UTC(y, m - 1, d) / DAY_MS; };
  const localToday = () => { const n = new Date(); return Date.UTC(n.getFullYear(), n.getMonth(), n.getDate()) / DAY_MS; };
  const toISO = (n) => new Date(n * DAY_MS).toISOString().slice(0, 10);
  const fmt = (n, opts) => new Date(n * DAY_MS).toLocaleDateString("fr-FR", { timeZone: "UTC", ...opts });
  const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

  const start = parseISO(START_DATE);
  let today = localToday();
  let first = Math.min(start, today);
  let current = today;
  let shown = ARCHIVE_PAGE;

  const dayNumber = (n) => n - start + 1;
  const photoFor = (n) => CALENDAR[toISO(n)] || null;
  const url = (p) => p.split("/").map(encodeURIComponent).join("/");
  const thumb = (p) => p.replace(/^photos\//, "photos/mini/");

  // ---------- Éléments ----------
  const $ = (id) => document.getElementById(id);
  const el = {
    kicker: $("day-kicker"), title: $("day-title"), photo: $("photo"), photoBtn: $("photo-btn"),
    empty: $("empty"), prev: $("prev"), next: $("next"), backToday: $("back-today"),
    grid: $("grid"), more: $("more"), archivesEmpty: $("archives-empty"), archivesCount: $("archives-count"),
    lightbox: $("lightbox"), lightboxImg: $("lightbox-img"), birthday: $("birthday"),
  };

  // ---------- Photo du jour ----------
  function show(n, { scroll = false } = {}) {
    current = Math.max(first, Math.min(today, n));
    const isToday = current === today;
    const p = photoFor(current);

    el.kicker.textContent = (isToday ? "Aujourd'hui · " : "") + "Jour " + dayNumber(current);
    el.title.innerHTML = cap(fmt(current, { weekday: "long", day: "numeric", month: "long" })) +
      ' <span class="year">' + fmt(current, { year: "numeric" }) + "</span>";
    document.title = isToday ? "1 Jour 1 Ulysse" : `${cap(fmt(current, { day: "numeric", month: "long", year: "numeric" }))} · 1 Jour 1 Ulysse`;

    el.photoBtn.hidden = !p;
    el.empty.hidden = !!p;
    if (p) {
      const next = url(p);
      if (el.photo.getAttribute("src") !== next) {
        el.photo.classList.remove("ready");
        el.photo.src = next;
      }
      el.photo.alt = `Ulysse, le ${fmt(current, { day: "numeric", month: "long", year: "numeric" })}`;
      // Précharge les jours voisins pour une navigation fluide
      [current - 1, current + 1].forEach((d) => {
        if (d >= first && d <= today && photoFor(d)) new Image().src = url(photoFor(d));
      });
    }

    el.prev.disabled = current <= first;
    el.next.disabled = current >= today;
    el.backToday.hidden = isToday;

    history.replaceState(null, "", isToday ? location.pathname : `#jour=${toISO(current)}`);

    el.grid.querySelectorAll(".tile").forEach((t) =>
      t.setAttribute("aria-current", String(Number(t.dataset.day) === current)));

    if (scroll) window.scrollTo({ top: 0, behavior: "smooth" });
  }

  el.photo.addEventListener("load", () => el.photo.classList.add("ready"));
  el.photo.addEventListener("error", () => el.photo.classList.add("ready"));

  el.prev.addEventListener("click", () => show(current - 1));
  el.next.addEventListener("click", () => show(current + 1));
  el.backToday.addEventListener("click", () => show(today));
  $("brand").addEventListener("click", (e) => { e.preventDefault(); show(today, { scroll: true }); });

  document.addEventListener("keydown", (e) => {
    if (el.lightbox.open || e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.key === "ArrowLeft") show(current - 1);
    if (e.key === "ArrowRight") show(current + 1);
  });

  // Balayage sur mobile
  let touchX = null;
  el.photoBtn.addEventListener("touchstart", (e) => { touchX = e.touches[0].clientX; }, { passive: true });
  el.photoBtn.addEventListener("touchend", (e) => {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    touchX = null;
    if (Math.abs(dx) > 50) show(current + (dx > 0 ? -1 : 1));
  });

  // Visionneuse plein écran
  el.photoBtn.addEventListener("click", () => {
    if (!el.photo.src) return;
    el.lightboxImg.src = el.photo.src;
    el.lightboxImg.alt = el.photo.alt;
    el.lightbox.showModal();
  });
  el.lightbox.addEventListener("click", (e) => { if (e.target === el.lightbox) el.lightbox.close(); });

  // ---------- Archives ----------
  function renderArchives() {
    const total = today - first; // jours précédents (hors aujourd'hui)
    el.grid.innerHTML = "";
    el.archivesEmpty.hidden = total > 0;
    el.archivesCount.textContent = total > 0 ? `${total} jour${total > 1 ? "s" : ""} d'Ulysse` : "";

    const last = Math.max(first, today - shown);
    const frag = document.createDocumentFragment();
    for (let n = today - 1; n >= last; n--) {
      const li = document.createElement("li");
      const b = document.createElement("button");
      b.className = "tile";
      b.type = "button";
      b.dataset.day = n;
      b.setAttribute("aria-current", String(n === current));
      const p = photoFor(n);
      b.innerHTML =
        (p ? `<div class="tile-img"><img loading="lazy" decoding="async" alt="" src="${url(thumb(p))}"></div>`
           : `<div class="tile-img tile-missing" aria-hidden="true">🐾</div>`) +
        `<span class="tile-date"><b>${fmt(n, { day: "numeric", month: "short" })}</b><small>Jour ${dayNumber(n)}</small></span>`;
      b.setAttribute("aria-label", `Voir la photo du ${fmt(n, { weekday: "long", day: "numeric", month: "long", year: "numeric" })}`);
      b.addEventListener("click", () => show(n, { scroll: true }));
      li.appendChild(b);
      frag.appendChild(li);
    }
    el.grid.appendChild(frag);
    el.more.hidden = last <= first;
  }

  el.more.addEventListener("click", () => { shown += ARCHIVE_PAGE; renderArchives(); });

  // ---------- Présentation ----------
  function renderAbout() {
    const b = new Date(BIRTH_DATE + "T00:00:00");
    const now = new Date();
    let months = (now.getFullYear() - b.getFullYear()) * 12 + (now.getMonth() - b.getMonth());
    if (now.getDate() < b.getDate()) months--;
    const y = Math.floor(months / 12), m = months % 12;
    $("age").textContent = `${y} an${y > 1 ? "s" : ""}` + (m ? ` et ${m} mois` : "");

    const isBirthday = now.getMonth() === b.getMonth() && now.getDate() === b.getDate();
    el.birthday.hidden = !isBirthday;
    if (isBirthday) el.birthday.textContent = `🎂 Joyeux anniversaire Ulysse — ${y} ans aujourd'hui !`;

    $("since").textContent = fmt(start, { day: "numeric", month: "long", year: "numeric" });

    // Portrait : photos/portrait.jpg, ou à défaut la première photo de la liste
    const box = $("about-photo");
    box.innerHTML = "";
    const img = new Image();
    img.alt = "Portrait d'Ulysse";
    img.onerror = () => {
      img.onerror = null;
      if (PHOTOS[0]) img.src = url(PHOTOS[0]); else box.innerHTML = "";
    };
    img.src = url(PORTRAIT);
    box.appendChild(img);
  }

  // ---------- Démarrage ----------
  function init() {
    const m = location.hash.match(/^#jour=(\d{4}-\d{2}-\d{2})$/);
    renderArchives();
    renderAbout();
    show(m ? parseISO(m[1]) : today);
  }

  window.addEventListener("hashchange", () => {
    const m = location.hash.match(/^#jour=(\d{4}-\d{2}-\d{2})$/);
    if (m) show(parseISO(m[1]));
  });

  // Passage à minuit : la nouvelle photo apparaît sans recharger la page
  setInterval(() => {
    const t = localToday();
    if (t === today) return;
    const wasToday = current === today;
    today = t;
    first = Math.min(start, today);
    renderArchives();
    renderAbout();
    show(wasToday ? today : current);
  }, 60000);

  init();
})();
