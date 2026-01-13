/**
 * FactGrid - Newspaper Style with Auto-refresh
 */

const API = 'https://api-production-d232.up.railway.app';
const REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

const PERSP = {
    Conservative: { icon: '🔴', class: 'conservative', label: 'Höger' },
    Progressive: { icon: '🔵', class: 'progressive', label: 'Vänster' },
    Expert: { icon: '📊', class: 'expert', label: 'Experter' },
    International: { icon: '🌍', class: 'international', label: 'Internationellt' },
    Neutral: { icon: '⚪', class: 'neutral', label: 'Neutral' },
};

let stories = [];
let lastUpdate = null;

// Elements
const main = document.getElementById('main');
const articleView = document.getElementById('article-view');
const articleContent = document.getElementById('article-content');
const backBtn = document.getElementById('back-btn');
const dateEl = document.getElementById('date');
const sourcesEl = document.getElementById('sources-count');
const refreshBar = document.getElementById('refresh-bar');
const refreshStatus = document.getElementById('refresh-status');

// Escape HTML
function esc(t) {
    if (!t) return '';
    const d = document.createElement('div');
    d.textContent = t;
    return d.innerHTML;
}

// Format date
function formatDate() {
    const d = new Date();
    const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    return d.toLocaleDateString('sv-SE', options);
}

// Format time
function formatTime(date) {
    return date.toLocaleTimeString('sv-SE', { hour: '2-digit', minute: '2-digit' });
}

// Render news item
function renderNewsItem(story, i) {
    const isFeatured = i === 0;
    const perspectives = (story.perspectives || []).map(p => {
        const cfg = PERSP[p.perspective] || PERSP.Neutral;
        return `<span class="persp-tag">${cfg.icon} ${cfg.label}</span>`;
    }).join('');

    const sources = (story.sources || []).slice(0, 2).join(', ');
    const imageUrl = story.image_url;

    return `
        <div class="news-item ${isFeatured ? 'featured' : ''}" data-index="${i}">
            ${imageUrl ? `<img class="news-image" src="${esc(imageUrl)}" alt="" onerror="this.style.display='none'">` : ''}
            <div class="news-kicker">${esc(sources)}</div>
            <h2 class="news-title">${esc(story.name)}</h2>
            ${story.summary ? `<p class="news-summary">${esc(story.summary)}</p>` : ''}
            <div class="news-meta">${story.article_count || 0} artiklar · ${(story.facts || []).length} fakta</div>
            ${perspectives ? `<div class="news-perspectives">${perspectives}</div>` : ''}
        </div>
    `;
}

// Render article view
function renderArticle(story) {
    const sources = (story.sources || []).join(', ');
    const imageUrl = story.image_url;

    // Facts
    const facts = (story.facts || []).map(f => `
        <div class="fact-item">
            <div class="fact-text">${esc(f.content)}</div>
            <div class="fact-source">Källa: ${esc(f.source)}</div>
        </div>
    `).join('') || '<p style="color:var(--text-muted)">Inga fakta extraherade</p>';

    // Perspectives
    const persps = (story.perspectives || []).map(p => {
        const cfg = PERSP[p.perspective] || PERSP.Neutral;
        const items = [...(p.opinions || []), ...(p.quotes || [])];
        if (!items.length) return '';

        return `
            <div class="persp-group">
                <div class="persp-header ${cfg.class}">
                    <span class="icon">${cfg.icon}</span>
                    <span class="label">${esc(p.label)}</span>
                </div>
                ${items.slice(0, 3).map(item => `
                    <div class="persp-item">
                        <div class="persp-quote">"${esc(item.content)}"</div>
                        <div class="persp-source">— ${esc(item.source)}${item.role ? ', ' + esc(item.role) : ''}${item.affiliation ? ', ' + esc(item.affiliation) : ''}</div>
                    </div>
                `).join('')}
            </div>
        `;
    }).join('') || '<p style="color:var(--text-muted)">Inga perspektiv extraherade</p>';

    return `
        ${imageUrl ? `<img class="article-image" src="${esc(imageUrl)}" alt="" onerror="this.style.display='none'">` : ''}
        <div class="article-kicker">${esc(sources)}</div>
        <h1 class="article-title">${esc(story.name)}</h1>
        <div class="article-meta">${story.article_count || 0} artiklar analyserade</div>

        ${story.summary ? `<p class="article-summary">${esc(story.summary)}</p>` : ''}

        <div class="section">
            <div class="section-header facts">
                <span class="section-title">Verifierade fakta</span>
            </div>
            ${facts}
        </div>

        <div class="section">
            <div class="section-header">
                <span class="section-title">Olika perspektiv</span>
            </div>
            ${persps}
        </div>
    `;
}

// Show article
function showArticle(index) {
    const story = stories[index];
    if (!story) return;

    articleContent.innerHTML = renderArticle(story);
    articleView.classList.remove('hidden');
    window.scrollTo(0, 0);
}

// Hide article
function hideArticle() {
    articleView.classList.add('hidden');
}

// Fetch and render stories
async function fetchStories(showLoading = true) {
    if (showLoading) {
        refreshBar.classList.add('loading');
        refreshStatus.textContent = 'Uppdaterar...';
    }

    try {
        const res = await fetch(`${API}/stories`);
        const data = await res.json();

        stories = data.stories || [];
        const sources = data.sources_used || [];

        sourcesEl.textContent = `${sources.length} källor`;
        lastUpdate = new Date();

        if (!stories.length) {
            main.innerHTML = '<div class="loading">Inga nyheter just nu</div>';
        } else {
            // Render grid
            main.innerHTML = `<div class="news-grid">${stories.map((s, i) => renderNewsItem(s, i)).join('')}</div>`;

            // Click handlers
            main.querySelectorAll('.news-item').forEach(item => {
                item.addEventListener('click', () => {
                    showArticle(parseInt(item.dataset.index, 10));
                });
            });
        }

        refreshBar.classList.remove('loading');
        refreshStatus.textContent = `Live · Uppdaterad ${formatTime(lastUpdate)}`;

    } catch (e) {
        console.error('Failed to fetch stories:', e);
        refreshBar.classList.remove('loading');
        refreshStatus.textContent = 'Kunde inte uppdatera';

        if (!stories.length) {
            main.innerHTML = '<div class="loading">Kunde inte ladda nyheter</div>';
        }
    }
}

// Init
async function init() {
    // Set date
    dateEl.textContent = formatDate();

    // Back button
    backBtn.addEventListener('click', hideArticle);

    // Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') hideArticle();
    });

    // Initial fetch
    await fetchStories();

    // Auto-refresh
    setInterval(() => fetchStories(false), REFRESH_INTERVAL);
}

document.addEventListener('DOMContentLoaded', init);
