(function () {
  "use strict";

  document.documentElement.classList.remove("no-js");
  document.documentElement.classList.add("js");

  var clamp = function (value, min, max) {
    return Math.min(Math.max(value, min), max);
  };

  var segment = function (value, start, end) {
    var t = clamp((value - start) / (end - start), 0, 1);
    return t * t * (3 - 2 * t);
  };

  var dispatch = function (name, detail) {
    document.dispatchEvent(new CustomEvent(name, { detail: detail }));
  };

  var motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  var hero = document.querySelector(".book-hero");
  var framePending = false;
  var openingStarted = false;
  var openingCompleted = false;

  var setHeroProgress = function () {
    framePending = false;
    if (!hero || motionQuery.matches) return;

    var rect = hero.getBoundingClientRect();
    var available = Math.max(hero.offsetHeight - window.innerHeight, 1);
    var progress = clamp(-rect.top / available, 0, 1);
    var openCover = segment(progress, 0.12, 0.58);
    var leafOne = segment(progress, 0.25, 0.54);
    var leafTwo = segment(progress, 0.31, 0.60);
    var leafThree = segment(progress, 0.37, 0.66);
    var leafFour = segment(progress, 0.43, 0.72);
    var settle = segment(progress, 0.06, 0.76);
    var before = 1 - segment(progress, 0.05, 0.23);
    var after = segment(progress, 0.68, 0.9);
    var light = segment(progress, 0.36, 0.78);
    var spreadReveal = segment(progress, 0.08, 0.35);
    var insideReveal = segment(progress, 0.38, 0.52);
    var isCompact = window.matchMedia("(max-width: 1120px)").matches;
    var isMobile = window.matchMedia("(max-width: 700px)").matches;
    var isShortWide = window.matchMedia("(min-width: 900px) and (max-height: 680px)").matches;

    hero.style.setProperty("--cover-angle", (-178 * openCover).toFixed(2) + "deg");
    hero.style.setProperty("--leaf-one-angle", (-166 * leafOne).toFixed(2) + "deg");
    hero.style.setProperty("--leaf-two-angle", (-151 * leafTwo).toFixed(2) + "deg");
    hero.style.setProperty("--leaf-three-angle", (-135 * leafThree).toFixed(2) + "deg");
    hero.style.setProperty("--leaf-four-angle", (-119 * leafFour).toFixed(2) + "deg");
    hero.style.setProperty("--book-tilt", (58 - 46 * settle).toFixed(2) + "deg");
    hero.style.setProperty("--book-roll", (-8 + 8 * settle).toFixed(2) + "deg");
    hero.style.setProperty("--book-scale", (0.84 - 0.06 * settle).toFixed(3));
    hero.style.setProperty("--book-x", (isCompact && !isShortWide ? 0 : 22 * settle).toFixed(2) + "vw");
    var bookY = isMobile ? 5 - 25 * settle : (isCompact && !isShortWide ? 5 - 21 * settle : 5 - 5 * settle);
    hero.style.setProperty("--book-y", bookY.toFixed(2) + "vh");
    hero.style.setProperty("--closed-shift", (-25 * (1 - spreadReveal)).toFixed(2) + "%");
    hero.style.setProperty("--closed-inset", (50 * (1 - spreadReveal)).toFixed(2) + "%");
    hero.style.setProperty("--cover-front-opacity", (1 - insideReveal).toFixed(3));
    hero.style.setProperty("--cover-inside-opacity", insideReveal.toFixed(3));
    hero.style.setProperty("--before-opacity", before.toFixed(3));
    hero.style.setProperty("--before-y", (-32 * (1 - before)).toFixed(2) + "px");
    hero.style.setProperty("--after-opacity", after.toFixed(3));
    hero.style.setProperty("--after-y", (32 * (1 - after)).toFixed(2) + "px");
    hero.style.setProperty("--book-light-opacity", (0.78 * light).toFixed(3));
    hero.style.setProperty("--hero-progress", (progress * 100).toFixed(2) + "%");

    if (progress > 0.04 && !openingStarted) {
      openingStarted = true;
      dispatch("victoria:book-open-start", { progress: progress });
    }
    if (progress < 0.02) openingStarted = false;

    if (progress >= 0.995 && !openingCompleted) {
      openingCompleted = true;
      dispatch("victoria:book-open-complete", { progress: 1 });
    }
    if (progress < 0.9) openingCompleted = false;
  };

  var requestHeroFrame = function () {
    if (framePending) return;
    framePending = true;
    window.requestAnimationFrame(setHeroProgress);
  };

  if (hero && !motionQuery.matches) {
    var sceneObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        hero.classList.toggle("scene-active", entry.isIntersecting);
      });
    }, { rootMargin: "15% 0px" });
    sceneObserver.observe(hero);
    window.addEventListener("scroll", requestHeroFrame, { passive: true });
    window.addEventListener("resize", requestHeroFrame, { passive: true });
    requestHeroFrame();
  }

  var pathways = {
    leer: {
      heading: "Abre la Biblia sin perderte entre herramientas.",
      copy: "Lee por libro y capítulo, busca un pasaje, escucha el texto o compara dos versiones desde una misma lectura.",
      features: ["Lectura y búsqueda", "Audio y vista paralela", "Guardados y notas"],
      href: "ayuda.html#biblia-completa",
      link: "Aprender a usar la Biblia"
    },
    orar: {
      heading: "Convierte lo que llevas dentro en una oración concreta.",
      copy: "Organiza peticiones, recuerda por quién estás orando y reconoce respuestas sin exponer tu proceso en público.",
      features: ["Mapa de Oración", "Peticiones privadas", "Devocionales y versículos"],
      href: "ayuda.html#vida-espiritual",
      link: "Conocer las herramientas de oración"
    },
    aprender: {
      heading: "Estudia con contexto y avanza paso a paso.",
      copy: "Usa introducciones, mapas, líneas de tiempo, concordancia y recursos de estudio junto con Escuela del Reino y sus series.",
      features: ["Escuela del Reino", "Mapas y cronología", "Comentarios y conexiones"],
      href: "ayuda.html#crecimiento",
      link: "Explorar aprendizaje y estudio"
    },
    apoyo: {
      heading: "Pide apoyo sin convertir tu historia en espectáculo.",
      copy: "Conecta con una persona de confianza o participa de forma seudónima en la comunidad, usando los controles de reporte y bloqueo.",
      features: ["Compañero de Batalla", "Muro moderado", "Reporte, bloqueo y privacidad"],
      href: "ayuda.html#comunidad",
      link: "Entender el acompañamiento"
    }
  };

  var pathwayButtons = Array.prototype.slice.call(document.querySelectorAll(".pathway-tab"));
  var pathwayHeading = document.getElementById("pathway-heading");
  var pathwayCopy = document.getElementById("pathway-copy");
  var pathwayFeatures = document.getElementById("pathway-features");
  var pathwayLink = document.getElementById("pathway-link");

  pathwayButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      var key = button.getAttribute("data-pathway");
      var pathway = pathways[key];
      if (!pathway) return;

      pathwayButtons.forEach(function (item) {
        var active = item === button;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-pressed", active ? "true" : "false");
      });
      pathwayHeading.textContent = pathway.heading;
      pathwayCopy.textContent = pathway.copy;
      pathwayFeatures.replaceChildren();
      pathway.features.forEach(function (feature) {
        var item = document.createElement("li");
        item.textContent = feature;
        pathwayFeatures.appendChild(item);
      });
      pathwayLink.href = pathway.href;
      pathwayLink.textContent = pathway.link;
      dispatch("victoria:pathway-select", { pathway: key });
    });
  });

  var normalizeText = function (value) {
    return value.toLocaleLowerCase("es").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();
  };

  var helpSearch = document.getElementById("help-search");
  var filterButtons = Array.prototype.slice.call(document.querySelectorAll(".filter-button"));
  var guideCards = Array.prototype.slice.call(document.querySelectorAll(".guide-card"));
  var guideGroups = Array.prototype.slice.call(document.querySelectorAll(".guide-group"));
  var helpEmpty = document.getElementById("help-empty");
  var activeFilter = "todos";

  var filterGuides = function () {
    if (!helpSearch) return;
    var query = normalizeText(helpSearch.value);
    var visibleCount = 0;

    guideCards.forEach(function (card) {
      var categoryMatch = activeFilter === "todos" || card.getAttribute("data-category") === activeFilter;
      var searchable = normalizeText(card.textContent + " " + (card.getAttribute("data-keywords") || ""));
      var queryMatch = !query || searchable.indexOf(query) !== -1;
      var visible = categoryMatch && queryMatch;
      card.hidden = !visible;
      if (visible) visibleCount += 1;
    });

    guideGroups.forEach(function (group) {
      group.hidden = !group.querySelector(".guide-card:not([hidden])");
    });

    if (helpEmpty) helpEmpty.classList.toggle("is-visible", visibleCount === 0);
  };

  if (helpSearch) {
    helpSearch.addEventListener("input", filterGuides);
    filterButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        activeFilter = button.getAttribute("data-filter") || "todos";
        filterButtons.forEach(function (item) {
          var active = item === button;
          item.classList.toggle("is-active", active);
          item.setAttribute("aria-pressed", active ? "true" : "false");
        });
        filterGuides();
      });
    });
  }

  guideCards.forEach(function (guide) {
    guide.addEventListener("toggle", function () {
      if (guide.open) {
        dispatch("victoria:tutorial-open", { tutorialId: guide.id });
      }
    });
  });

  document.querySelectorAll(".site-nav a").forEach(function (link) {
    link.addEventListener("click", function () {
      var disclosure = link.closest("details");
      if (disclosure) disclosure.removeAttribute("open");
    });
  });

  var navDisclosures = Array.prototype.slice.call(document.querySelectorAll(".nav-disclosure"));
  var syncNavigation = function () {
    var compact = window.matchMedia("(max-width: 700px)").matches;
    navDisclosures.forEach(function (disclosure) {
      if (compact) {
        disclosure.removeAttribute("open");
      } else {
        disclosure.setAttribute("open", "");
      }
    });
  };
  syncNavigation();
  window.addEventListener("resize", syncNavigation, { passive: true });
})();
