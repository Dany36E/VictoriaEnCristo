(function () {
  "use strict";

  var root = document.documentElement;
  root.classList.remove("no-js");
  root.classList.add("js");

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

  var hero = document.querySelector(".book-hero");
  var bookScene = document.querySelector(".book-scene");
  var bookWrapper = document.querySelector(".book-wrapper");
  var bookBackCover = document.querySelector(".book-back-cover");
  var bookPageStack = document.querySelector(".book-page-stack");
  var bookSpread = document.querySelector(".book-spread");
  var frontCover = document.querySelector(".front-cover");
  var coverFront = document.querySelector(".cover-front");
  var coverInside = document.querySelector(".cover-inside");
  var pageLeaves = ["one", "two", "three", "four"].map(function (name) {
    return document.querySelector(".leaf-" + name);
  });
  var openingBefore = document.querySelector(".opening-copy-before");
  var openingAfter = document.querySelector(".opening-copy-after");
  var bookLight = document.querySelector(".book-light");
  var bookBeam = document.querySelector(".book-beam");
  var bookShadow = document.querySelector(".book-shadow");
  var scriptureReveal = document.querySelector(".scripture-reveal");
  var scriptureCite = document.querySelector(".scripture-reveal cite");
  var progressBar = document.querySelector(".hero-progress span");
  var verseSlots = Array.prototype.slice.call(document.querySelectorAll(".word-slot"));
  var verseWords = Array.prototype.slice.call(document.querySelectorAll(".verse-word"));
  var verseTargets = [];
  var compactQuery = window.matchMedia("(max-width: 1120px)");
  var mobileQuery = window.matchMedia("(max-width: 700px)");
  var shortWideQuery = window.matchMedia("(min-width: 900px) and (max-height: 680px)");
  var heroLayout = {
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
    heroHeight: 0,
    sceneWidth: 0,
    sceneHeight: 0,
    isCompact: compactQuery.matches,
    isMobile: mobileQuery.matches,
    isShortWide: shortWideQuery.matches
  };
  var heroLayoutDirty = true;
  var lastBookX = 0;
  var framePending = false;
  var openingStarted = false;
  var openingCompleted = false;
  var heroMotionBound = false;
  var heroReady = false;

  var measureHeroLayout = function (heroRect) {
    heroLayout.viewportWidth = window.innerWidth;
    heroLayout.viewportHeight = window.innerHeight;
    heroLayout.heroHeight = heroRect.height;
    heroLayout.isCompact = compactQuery.matches;
    heroLayout.isMobile = mobileQuery.matches;
    heroLayout.isShortWide = shortWideQuery.matches;

    if (!bookScene) {
      heroLayoutDirty = false;
      return;
    }

    var sceneRect = bookScene.getBoundingClientRect();
    var parentShift = heroLayout.viewportWidth * lastBookX / 100;
    heroLayout.sceneWidth = bookScene.clientWidth;
    heroLayout.sceneHeight = bookScene.clientHeight;
    verseTargets = verseSlots.map(function (slot) {
      var rect = slot.getBoundingClientRect();
      return {
        x: rect.left + rect.width / 2 - sceneRect.left - parentShift,
        y: rect.top + rect.height / 2 - sceneRect.top
      };
    });
    heroLayoutDirty = false;
  };

  var animateVerse = function (progress, bookY, closedShift) {
    if (!bookScene || !verseWords.length) return;

    var sourceX = heroLayout.sceneWidth * (0.5 + closedShift / 100);
    var sourceY = heroLayout.sceneHeight * 0.57 + heroLayout.viewportHeight * bookY / 100;

    verseWords.forEach(function (word, index) {
      var wordProgress = segment(progress, 0.4 + index * 0.026, 0.69 + index * 0.026);
      var target = verseTargets[index] || { x: sourceX, y: sourceY };
      var remaining = 1 - wordProgress;
      var driftX = (sourceX - target.x) * remaining;
      var driftY = (sourceY - target.y) * remaining - Math.sin(Math.PI * wordProgress) * 58;
      var depth = 170 * remaining;
      var turn = (index % 2 === 0 ? -7 : 7) * remaining;
      var scale = 0.56 + 0.44 * wordProgress;
      word.style.opacity = clamp((wordProgress - 0.02) / 0.28, 0, 1).toFixed(3);
      word.style.transform = "translate3d(" + driftX.toFixed(2) + "px," + driftY.toFixed(2) + "px," + depth.toFixed(2) + "px) rotate3d(0,0,1," + turn.toFixed(2) + "deg) scale(" + scale.toFixed(3) + ")";
    });
  };

  var setHeroProgress = function () {
    framePending = false;
    if (!hero) return;

    var rect = hero.getBoundingClientRect();
    if (heroLayoutDirty || verseTargets.length !== verseWords.length) measureHeroLayout(rect);

    var available = Math.max(heroLayout.heroHeight - heroLayout.viewportHeight, 1);
    var progress = clamp(-rect.top / available, 0, 1);
    var openCover = segment(progress, 0.08, 0.5);
    var leafOne = segment(progress, 0.2, 0.48);
    var leafTwo = segment(progress, 0.27, 0.55);
    var leafThree = segment(progress, 0.34, 0.62);
    var leafFour = segment(progress, 0.41, 0.69);
    var settle = segment(progress, 0.05, 0.76);
    var before = 1 - segment(progress, 0.05, 0.23);
    var after = segment(progress, 0.87, 0.98);
    var light = segment(progress, 0.24, 0.76);
    var beam = segment(progress, 0.32, 0.78);
    var spreadReveal = segment(progress, 0.07, 0.31);
    var insideReveal = segment(progress, 0.32, 0.5);
    var isCompact = heroLayout.isCompact;
    var isMobile = heroLayout.isMobile;
    var isShortWide = heroLayout.isShortWide;

    var bookX = isCompact && !isShortWide ? 0 : 22 * settle;
    var bookY = isMobile ? 5 - 9 * settle : (isCompact && !isShortWide ? 5 - 13 * settle : (isShortWide ? 6 + 7 * settle : 7 + 11 * settle));
    var closedShift = -25 * (1 - spreadReveal);

    var coverAngle = -178 * openCover;
    var leafAngles = [-176 * leafOne, -169 * leafTwo, -161 * leafThree, -152 * leafFour];
    var bookTilt = 4 + 54 * settle;
    var bookRoll = -3 + 3 * settle;
    var bookScale = 0.82 + 0.12 * settle;
    var closedInset = 50 * (1 - spreadReveal);
    var beforeY = -32 * (1 - before);
    var afterY = 32 * (1 - after);
    var citeReveal = segment(progress, 0.78, 0.94);
    var shadowScale = 0.58 + 0.42 * settle;

    frontCover.style.transform = "rotate3d(0,1,0," + coverAngle.toFixed(2) + "deg) translate3d(0,0,8px)";
    pageLeaves.forEach(function (leaf, index) {
      if (!leaf) return;
      leaf.style.transform = "rotate3d(0,1,0," + leafAngles[index].toFixed(2) + "deg) translate3d(0,0," + (6 - index) + "px)";
    });
    bookWrapper.style.transform = "translate3d(calc(" + bookX.toFixed(2) + "vw + " + closedShift.toFixed(2) + "% )," + bookY.toFixed(2) + "vh,0) rotate3d(1,0,0," + bookTilt.toFixed(2) + "deg) rotate3d(0,0,1," + bookRoll.toFixed(2) + "deg) scale(" + bookScale.toFixed(3) + ")";
    [bookBackCover, bookPageStack, bookSpread].forEach(function (layer) {
      if (layer) layer.style.clipPath = "inset(0 0 0 " + closedInset.toFixed(2) + "%)";
    });
    coverFront.style.opacity = (1 - insideReveal).toFixed(3);
    coverInside.style.opacity = insideReveal.toFixed(3);
    openingBefore.style.opacity = before.toFixed(3);
    openingBefore.style.transform = "translate3d(-50%," + beforeY.toFixed(2) + "px,0)";
    openingAfter.style.opacity = after.toFixed(3);
    openingAfter.style.transform = isCompact && !isShortWide
      ? "translate3d(-50%," + afterY.toFixed(2) + "px,0)"
      : "translate3d(0,calc(-42% + " + afterY.toFixed(2) + "px),0)";
    bookLight.style.opacity = (0.92 * light).toFixed(3);
    bookLight.style.transform = "translate3d(calc(-50% + " + bookX.toFixed(2) + "vw)," + bookY.toFixed(2) + "vh,0) scale(1.08)";
    bookBeam.style.opacity = (0.84 * beam).toFixed(3);
    bookShadow.style.opacity = (0.28 + 0.42 * settle).toFixed(3);
    bookShadow.style.transform = "translate3d(" + bookX.toFixed(2) + "vw," + bookY.toFixed(2) + "vh,0) scaleX(" + shadowScale.toFixed(3) + ")";
    scriptureReveal.style.transform = "translate3d(calc(-50% + " + bookX.toFixed(2) + "vw),0,0)";
    scriptureCite.style.opacity = citeReveal.toFixed(3);
    scriptureCite.style.transform = "translate3d(0," + (18 * (1 - citeReveal)).toFixed(2) + "px,0)";
    progressBar.style.width = (progress * 100).toFixed(2) + "%";
    var ready = progress >= 0.86;
    if (ready !== heroReady) {
      heroReady = ready;
      hero.classList.toggle("hero-ready", ready);
    }
    animateVerse(progress, bookY, closedShift);
    lastBookX = bookX;

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

  var enableHeroMotion = function () {
    if (!hero || heroMotionBound) {
      requestHeroFrame();
      return;
    }
    heroMotionBound = true;
    var sceneObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        hero.classList.toggle("scene-active", entry.isIntersecting);
      });
    }, { rootMargin: "15% 0px" });
    sceneObserver.observe(hero);
    window.addEventListener("scroll", requestHeroFrame, { passive: true });
    window.addEventListener("resize", function () {
      heroLayoutDirty = true;
      requestHeroFrame();
    }, { passive: true });
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        heroLayoutDirty = true;
        requestHeroFrame();
      });
    }
    requestHeroFrame();
  };

  if (hero) enableHeroMotion();

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

  var openHashGuide = function () {
    if (!window.location.hash) return;
    var targetId;
    try {
      targetId = decodeURIComponent(window.location.hash.slice(1));
    } catch (_) {
      return;
    }
    var target = document.getElementById(targetId);
    if (!target || !target.matches("details.guide-card")) return;
    target.hidden = false;
    target.open = true;
    var group = target.closest(".guide-group");
    if (group) group.hidden = false;
    window.requestAnimationFrame(function () {
      target.scrollIntoView({ block: "start" });
    });
  };

  openHashGuide();
  window.addEventListener("hashchange", openHashGuide);

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
