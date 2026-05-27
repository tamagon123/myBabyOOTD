const STORAGE = {
  checks: 'swift_guide_checks',
  scroll: 'swift_guide_scroll',
  theme: 'swift_guide_theme',
};

let sectionIds = [];
let lastScrollY = 0;

/* ---------- Init ---------- */
document.addEventListener('DOMContentLoaded', () => {
  renderMarkdown();
  restoreTheme();
  restoreChecks();
  setupTOC();
  setupCheckboxes();
  setupCopyButtons();
  setupObservers();
  setupEventListeners();
  setupResume();
  updateProgress();
});

/* ---------- Render ---------- */
function renderMarkdown() {
  const source = document.getElementById('md-source');
  if (!source) return;

  const html = marked.parse(source.textContent);
  document.getElementById('article').innerHTML = html;

  // Syntax highlight
  if (window.Prism) Prism.highlightAll();

  // Inject checkboxes into h2 (Chapters)
  const h2s = document.querySelectorAll('#article h2');
  h2s.forEach((h2, i) => {
    const id = `ch-${i}`;
    h2.id = id;
    sectionIds.push(id);

    const label = document.createElement('label');
    label.className = 'check-label';
    label.innerHTML = `<input type="checkbox" class="section-check" data-id="${id}"> <span>完了</span>`;
    h2.appendChild(label);
  });

  // Give h3 IDs for deep linking
  document.querySelectorAll('#article h3').forEach((h3, i) => {
    if (!h3.id) h3.id = `sec-${i}`;
  });
}

/* ---------- TOC ---------- */
function setupTOC() {
  const toc = document.getElementById('toc');
  if (!toc) return;

  const h2s = document.querySelectorAll('#article h2');
  h2s.forEach(h2 => {
    const a = document.createElement('a');
    a.href = `#${h2.id}`;
    // Extract text excluding checkbox
    const text = h2.childNodes[0]?.textContent?.trim() || h2.id;
    a.textContent = text;
    a.dataset.target = h2.id;
    a.addEventListener('click', e => {
      e.preventDefault();
      const el = document.getElementById(h2.id);
      if (el) {
        const y = el.getBoundingClientRect().top + window.scrollY - 80;
        window.scrollTo({ top: y, behavior: 'smooth' });
        closeSidebar();
      }
    });
    toc.appendChild(a);
  });
}

/* ---------- Progress & Checks ---------- */
function setupCheckboxes() {
  document.querySelectorAll('.section-check').forEach(cb => {
    cb.addEventListener('change', () => {
      saveChecks();
      updateCheckVisual(cb);
    });
  });
}

function updateCheckVisual(checkbox) {
  const label = checkbox.closest('.check-label');
  if (label) {
    label.classList.toggle('checked', checkbox.checked);
  }
}

function restoreChecks() {
  const data = JSON.parse(localStorage.getItem(STORAGE.checks) || '{}');
  document.querySelectorAll('.section-check').forEach(cb => {
    cb.checked = !!data[cb.dataset.id];
    updateCheckVisual(cb);
  });
}

function saveChecks() {
  const data = {};
  document.querySelectorAll('.section-check').forEach(cb => {
    if (cb.checked) data[cb.dataset.id] = true;
  });
  localStorage.setItem(STORAGE.checks, JSON.stringify(data));
  updateProgress();
}

function updateProgress() {
  const total = sectionIds.length;
  const checked = document.querySelectorAll('.section-check:checked').length;
  const pct = total ? Math.round((checked / total) * 100) : 0;

  const fill = document.getElementById('progress-fill');
  const topFill = document.getElementById('top-progress-fill');
  const txt = document.getElementById('progress-text');

  if (fill) fill.style.width = `${pct}%`;
  if (topFill) topFill.style.width = `${pct}%`;
  if (txt) txt.textContent = `${pct}%`;
}

/* ---------- Scroll Save / Resume ---------- */
function setupResume() {
  const y = parseInt(localStorage.getItem(STORAGE.scroll) || '0', 10);
  const btn = document.getElementById('resume-btn');
  if (y > 200 && btn) {
    btn.style.display = 'inline-block';
    btn.addEventListener('click', () => {
      window.scrollTo({ top: y, behavior: 'smooth' });
      btn.style.display = 'none';
    });
  }

  let t;
  window.addEventListener('scroll', () => {
    lastScrollY = window.scrollY;
    clearTimeout(t);
    t = setTimeout(() => {
      localStorage.setItem(STORAGE.scroll, String(Math.floor(lastScrollY)));
    }, 300);
  }, { passive: true });
}

/* ---------- Intersection Observer for TOC ---------- */
function setupObservers() {
  const observer = new IntersectionObserver(
    entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          document.querySelectorAll('.toc a').forEach(a => a.classList.remove('active'));
          const link = document.querySelector(`.toc a[data-target="${entry.target.id}"]`);
          if (link) link.classList.add('active');
        }
      });
    },
    { rootMargin: '-15% 0px -70% 0px' }
  );

  sectionIds.forEach(id => {
    const el = document.getElementById(id);
    if (el) observer.observe(el);
  });
}

/* ---------- Copy Buttons ---------- */
function setupCopyButtons() {
  document.querySelectorAll('pre').forEach(pre => {
    const btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'コピー';
    btn.addEventListener('click', async () => {
      const code = pre.querySelector('code');
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code.textContent);
        btn.textContent = 'コピー済み';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'コピー';
          btn.classList.remove('copied');
        }, 1800);
      } catch (e) {
        btn.textContent = '失敗';
        setTimeout(() => (btn.textContent = 'コピー'), 1500);
      }
    });
    pre.appendChild(btn);
  });
}

/* ---------- Theme ---------- */
function restoreTheme() {
  const saved = localStorage.getItem(STORAGE.theme);
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (saved === 'dark' || (!saved && prefersDark)) {
    document.documentElement.classList.add('dark');
  }
  updateThemeIcon();
}

function toggleTheme() {
  document.documentElement.classList.toggle('dark');
  const isDark = document.documentElement.classList.contains('dark');
  localStorage.setItem(STORAGE.theme, isDark ? 'dark' : 'light');
  updateThemeIcon();
}

function updateThemeIcon() {
  const btn = document.getElementById('theme-toggle');
  if (!btn) return;
  const isDark = document.documentElement.classList.contains('dark');
  btn.textContent = isDark ? '☀️' : '🌙';
}

/* ---------- Event Listeners ---------- */
function setupEventListeners() {
  const menuBtn = document.getElementById('menu-toggle');
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.querySelector('.sidebar-overlay');

  if (menuBtn) {
    menuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      overlay.classList.toggle('show');
    });
  }

  if (overlay) {
    overlay.addEventListener('click', closeSidebar);
  }

  const themeBtn = document.getElementById('theme-toggle');
  if (themeBtn) themeBtn.addEventListener('click', toggleTheme);
}

function closeSidebar() {
  document.querySelector('.sidebar')?.classList.remove('open');
  document.querySelector('.sidebar-overlay')?.classList.remove('show');
}

/* ---------- Keyboard Shortcuts ---------- */
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeSidebar();
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'm') {
    e.preventDefault();
    toggleTheme();
  }
});
