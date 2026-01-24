// Apex Server Dashboard
const API_BASE = '/api/v1';
const WS_BASE = `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/api/v1`;
let token = localStorage.getItem('apex_token');
let currentSprintId = null;
let polling = null;
let ws = null; // WebSocket connection
let wsReconnectTimeout = null;
let knownFiles = new Set();
let lastLogId = 0;
let activeWorkerCounts = {}; // Track count of active workers per type
let currentQuestionId = null; // Track current pending question
let selectedTeam = 'a-team'; // Default team

// Log filtering
let logFilterMode = 'highlights'; // 'highlights' or 'all'
let allLogs = []; // Store all logs for re-filtering

// Regex to detect emoji/unicode characters (covers most common emojis)
const EMOJI_REGEX = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2300}-\u{23FF}]|[\u{2B50}]|[\u{2705}]|[\u{274C}]|[\u{26A0}]|[\u{1F4C4}]|[\u{1F4C1}]|[\u{1F527}]|[\u{2699}]|[\u{1F3A8}]|[\u{1F3D7}]|[\u{1F5BC}]|[\u{1F9EA}]|[\u{1F50D}]|[\u{1F510}]|[\u{1F680}]/gu;

// Important log types that should always show in highlights
const HIGHLIGHT_LOG_TYPES = ['phase', 'worker_start', 'worker_done', 'parallel_start', 'parallel_done', 'error', 'success', 'question', 'answer'];

function hasEmoji(text) {
    return EMOJI_REGEX.test(text);
}

function isHighlightLog(log) {
    // Show if it's an important log type
    if (HIGHLIGHT_LOG_TYPES.includes(log.log_type)) {
        return true;
    }
    // Show if message contains emoji
    if (hasEmoji(log.message)) {
        return true;
    }
    return false;
}

// Log type icons and colors
const LOG_ICONS = {
    'info': 'i',
    'phase': '=',
    'worker_start': '>',
    'worker_done': '<',
    'tool_call': '*',
    'tool_result': '-',
    'thinking': '?',
    'parallel_start': '||',
    'parallel_done': '||',
    'question': '?',
    'answer': '!',
    'error': 'X',
    'success': '!'
};

// Auth helpers
function getHeaders() {
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
    };
}

// WebSocket functions
function connectWebSocket(sprintId) {
    if (ws) {
        ws.close();
        ws = null;
    }

    if (wsReconnectTimeout) {
        clearTimeout(wsReconnectTimeout);
        wsReconnectTimeout = null;
    }

    const wsUrl = `${WS_BASE}/sprints/${sprintId}/ws?token=${token}`;
    console.log('Connecting WebSocket:', wsUrl);

    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
        console.log('WebSocket connected');
        // Stop polling if WebSocket is connected
        if (polling) {
            clearInterval(polling);
            polling = null;
        }
        // Start ping interval to keep connection alive
        ws._pingInterval = setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send('ping');
            }
        }, 30000);
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            handleWebSocketMessage(msg);
        } catch (e) {
            console.error('Failed to parse WebSocket message:', e);
        }
    };

    ws.onclose = (event) => {
        console.log('WebSocket closed:', event.code, event.reason);
        if (ws && ws._pingInterval) {
            clearInterval(ws._pingInterval);
        }
        ws = null;

        // Reconnect if sprint is still running
        if (currentSprintId === sprintId) {
            wsReconnectTimeout = setTimeout(() => {
                console.log('Attempting WebSocket reconnect...');
                connectWebSocket(sprintId);
            }, 2000);
        }
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        // Fall back to polling on error
        if (!polling && currentSprintId) {
            console.log('Falling back to polling...');
            polling = setInterval(pollLogs, 1000);
        }
    };
}

function disconnectWebSocket() {
    if (wsReconnectTimeout) {
        clearTimeout(wsReconnectTimeout);
        wsReconnectTimeout = null;
    }
    if (ws) {
        if (ws._pingInterval) {
            clearInterval(ws._pingInterval);
        }
        ws.close();
        ws = null;
    }
}

function handleWebSocketMessage(msg) {
    switch (msg.type) {
        case 'log':
            addLogFromServer(msg.data);
            lastLogId = msg.data.id;
            break;

        case 'tokens':
            updateTokenDisplay(msg.data);
            break;

        case 'status':
            handleStatusUpdate(msg.data);
            break;

        case 'pong':
            // Heartbeat response, ignore
            break;

        default:
            console.log('Unknown WebSocket message type:', msg.type);
    }
}

function updateTokenDisplay(data) {
    const inputTokens = data.input_tokens || 0;
    const outputTokens = data.output_tokens || 0;
    const totalCost = data.cost_usd || 0;

    const formatTokens = (n) => n >= 1000 ? `${(n / 1000).toFixed(0)}k` : n;
    const costText = totalCost >= 0.01 ? `$${totalCost.toFixed(2)}` : `$${totalCost.toFixed(3)}`;

    document.getElementById('tokens').textContent = `${formatTokens(inputTokens)} in / ${formatTokens(outputTokens)} out (${costText})`;
}

function updateGitHubLink(url) {
    const link = document.getElementById('github-link');
    if (url) {
        link.href = url;
        link.style.display = 'flex';
    } else {
        link.style.display = 'none';
    }
}

function handleStatusUpdate(data) {
    const status = data.status;

    if (status === 'completed' || status === 'failed' || status === 'cancelled') {
        // Sprint is done
        disconnectWebSocket();
        stopFilePolling();

        const statusMap = {
            'completed': { class: 'terminal-status done', text: 'done' },
            'failed': { class: 'terminal-status', text: 'failed' },
            'cancelled': { class: 'terminal-status', text: 'cancelled' }
        };
        const statusInfo = statusMap[status];
        document.getElementById('status').className = statusInfo.class;
        document.getElementById('status').textContent = statusInfo.text;
        document.getElementById('start').disabled = false;
        document.getElementById('cancel').style.display = 'none';
        document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
        hideQuestionModal();
        loadSprintHistory();

        // Update token display one final time
        updateTokenDisplay(data);

        // Final file update
        updateFiles();
    }
}

async function login() {
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    const errorEl = document.getElementById('login-error');

    try {
        const response = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });

        const data = await response.json();

        if (!response.ok) {
            errorEl.textContent = data.detail || 'Fel vid inloggning';
            return;
        }

        token = data.access_token;
        localStorage.setItem('apex_token', token);
        showDashboard(data.user);
    } catch (e) {
        errorEl.textContent = 'Kunde inte ansluta till servern';
        console.error(e);
    }
}

function logout() {
    token = null;
    localStorage.removeItem('apex_token');
    document.getElementById('dashboard').style.display = 'none';
    document.getElementById('login-screen').style.display = 'block';
}

function showDashboard(user) {
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('dashboard').style.display = 'block';
    document.getElementById('user-info').textContent = user?.email || '';
    // Pre-load history (but keep it collapsed)
    loadSprintHistory();
}

// Check if already logged in
async function checkAuth() {
    if (!token) return;

    try {
        const response = await fetch(`${API_BASE}/auth/me`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const user = await response.json();
            showDashboard(user);
        } else {
            logout();
        }
    } catch (e) {
        console.error(e);
    }
}

// Sprint functions
let filePolling = null; // Separate polling for files

async function startSprint() {
    const task = document.getElementById('task').value;
    if (!task) return;

    document.getElementById('start').disabled = true;
    document.getElementById('cancel').style.display = 'inline-block';
    document.getElementById('status').className = 'terminal-status running';
    document.getElementById('status').textContent = 'running';
    document.getElementById('tokens').textContent = '0 in / 0 out ($0.00)';
    document.getElementById('log').innerHTML = '';
    document.getElementById('files-list').innerHTML = '<div class="file-item" style="color: #444;">Vantar pa filer...</div>';
    knownFiles = new Set();
    allLogs = []; // Reset logs for filtering
    lastLogId = 0;
    activeWorkerCounts = {}; // Reset worker counts

    // Reset all dots to inactive and remove worker count classes
    document.querySelectorAll('.team-member').forEach(el => {
        el.classList.remove('active', 'workers-2', 'workers-3');
        el.querySelectorAll('.dot').forEach(dot => dot.classList.remove('active'));
    });

    document.getElementById('team-chef').classList.add('active');
    updateGitHubLink(null); // Reset GitHub link
    addLogLine('Startar sprint...', 'info');

    try {
        const response = await fetch(`${API_BASE}/sprints`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ task, team: selectedTeam })
        });

        const data = await response.json();

        if (!response.ok) {
            addLogLine('Error: ' + (data.detail || 'Kunde inte starta sprint'), 'error');
            document.getElementById('start').disabled = false;
            document.getElementById('status').className = 'terminal-status';
            document.getElementById('status').textContent = 'error';
            return;
        }

        currentSprintId = data.id;

        // Connect via WebSocket for real-time logs
        connectWebSocket(data.id);

        // Start file polling (WebSocket doesn't handle files)
        filePolling = setInterval(pollFilesAndQuestions, 2000);

    } catch (e) {
        disconnectWebSocket();
        stopFilePolling();
        addLogLine('Error: ' + e.message, 'error');
        document.getElementById('start').disabled = false;
        console.error(e);
    }
}

function stopFilePolling() {
    if (filePolling) {
        clearInterval(filePolling);
        filePolling = null;
    }
}

async function pollFilesAndQuestions() {
    if (!currentSprintId) return;

    try {
        // Update files
        await updateFiles();

        // Check for pending questions
        await checkForQuestion();
    } catch (e) {
        console.error('Error polling files/questions:', e);
    }
}

async function cancelSprint() {
    if (!currentSprintId) return;

    document.getElementById('cancel').disabled = true;
    addLogLine('Avbryter sprint...', 'info');

    try {
        const response = await fetch(`${API_BASE}/sprints/${currentSprintId}/cancel`, {
            method: 'POST',
            headers: getHeaders()
        });

        if (!response.ok) {
            const data = await response.json();
            addLogLine('Kunde inte avbryta: ' + (data.detail || 'Okänt fel'), 'error');
            document.getElementById('cancel').disabled = false;
        }
        // If successful, the pollLogs will pick up the cancelled status
    } catch (e) {
        addLogLine('Fel vid avbrytning: ' + e.message, 'error');
        document.getElementById('cancel').disabled = false;
        console.error(e);
    }
}

async function pollLogs() {
    if (!currentSprintId) return;

    try {
        // Fetch new logs
        const logsResponse = await fetch(`${API_BASE}/sprints/${currentSprintId}/logs?since_id=${lastLogId}`, {
            headers: getHeaders()
        });

        if (logsResponse.ok) {
            const logsData = await logsResponse.json();

            for (const log of logsData.logs) {
                addLogFromServer(log);
                lastLogId = log.id;
            }
        }

        // Also update files
        await updateFiles();

        // Check for pending questions
        await checkForQuestion();

        // Check sprint status
        const statusResponse = await fetch(`${API_BASE}/sprints/${currentSprintId}`, {
            headers: getHeaders()
        });

        if (statusResponse.ok) {
            const sprint = await statusResponse.json();

            // Update token counter with server-calculated cost
            const inputTokens = sprint.input_tokens || 0;
            const outputTokens = sprint.output_tokens || 0;
            const totalCost = sprint.cost_usd || 0;

            // Format token counts (k for thousands)
            const formatTokens = (n) => n >= 1000 ? `${(n / 1000).toFixed(0)}k` : n;
            const costText = totalCost >= 0.01 ? `$${totalCost.toFixed(2)}` : `$${totalCost.toFixed(3)}`;

            document.getElementById('tokens').textContent = `${formatTokens(inputTokens)} in / ${formatTokens(outputTokens)} out (${costText})`;

            if (sprint.status === 'completed' || sprint.status === 'failed' || sprint.status === 'cancelled') {
                // Sprint is done - stop polling
                clearInterval(polling);
                polling = null;
                stopFilePolling();
                disconnectWebSocket();

                const statusMap = {
                    'completed': { class: 'terminal-status done', text: 'done' },
                    'failed': { class: 'terminal-status', text: 'failed' },
                    'cancelled': { class: 'terminal-status', text: 'cancelled' }
                };
                const statusInfo = statusMap[sprint.status];
                document.getElementById('status').className = statusInfo.class;
                document.getElementById('status').textContent = statusInfo.text;
                document.getElementById('start').disabled = false;
                document.getElementById('cancel').style.display = 'none';
                document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
                hideQuestionModal(); // Hide modal if sprint ends
                loadSprintHistory(); // Refresh history list
            }
        }

    } catch (e) {
        console.error(e);
    }
}

// Question modal functions
async function checkForQuestion() {
    if (!currentSprintId) return;

    try {
        const response = await fetch(`${API_BASE}/sprints/${currentSprintId}/question`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const question = await response.json();

            if (question && question.id !== currentQuestionId) {
                // New question - show modal
                currentQuestionId = question.id;
                showQuestionModal(question);
            }
        }
    } catch (e) {
        console.error('Error checking for question:', e);
    }
}

function showQuestionModal(question) {
    const modal = document.getElementById('question-modal');
    const questionText = document.getElementById('modal-question-text');
    const optionsContainer = document.getElementById('modal-options');
    const customInput = document.getElementById('modal-custom-answer');

    // Set question text
    questionText.textContent = question.question;

    // Clear and populate options
    optionsContainer.innerHTML = '';
    if (question.options && question.options.length > 0) {
        question.options.forEach(option => {
            const btn = document.createElement('button');
            btn.className = 'modal-option';
            btn.textContent = option;
            btn.onclick = () => submitAnswer(option);
            optionsContainer.appendChild(btn);
        });
    }

    // Clear custom input
    customInput.value = '';

    // Show modal
    modal.style.display = 'flex';
}

function hideQuestionModal() {
    document.getElementById('question-modal').style.display = 'none';
    currentQuestionId = null;
}

async function submitAnswer(answer) {
    if (!currentSprintId || !currentQuestionId) return;

    try {
        const response = await fetch(`${API_BASE}/sprints/${currentSprintId}/question/${currentQuestionId}/answer`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ answer })
        });

        if (response.ok) {
            hideQuestionModal();
            addLogLine(`Du svarade: ${answer}`, 'answer');
        } else {
            console.error('Failed to submit answer');
        }
    } catch (e) {
        console.error('Error submitting answer:', e);
    }
}

function sendCustomAnswer() {
    const customInput = document.getElementById('modal-custom-answer');
    const answer = customInput.value.trim();

    if (answer) {
        submitAnswer(answer);
    }
}

function addLogFromServer(log) {
    // Store log for re-filtering
    allLogs.push(log);

    // Check if this log contains a GitHub repo URL (always process this)
    if (log.message && log.message.includes('GitHub repo:')) {
        const match = log.message.match(/GitHub repo:\s*(https:\/\/github\.com\/[^\s]+)/);
        if (match) {
            updateGitHubLink(match[1]);
        }
    }

    // Update team status based on worker (always process this)
    updateTeamFromLog(log);

    // Only render if passes filter
    if (logFilterMode === 'all' || isHighlightLog(log)) {
        renderLogEntry(log);
    }
}

function renderLogEntry(log) {
    const logEl = document.getElementById('log');
    const entry = document.createElement('div');

    // Map log type to CSS class
    const typeClass = log.log_type.replace('_', '-');
    entry.className = `log-entry ${typeClass}`;

    // Format timestamp
    const time = new Date(log.timestamp).toLocaleTimeString('sv-SE', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });

    // Get icon
    const icon = LOG_ICONS[log.log_type] || '>';

    // Worker prefix
    const workerPrefix = log.worker ? `[${log.worker.toUpperCase()}] ` : '';

    entry.innerHTML = `
        <span class="log-time">${time}</span>
        <span class="log-icon">${icon}</span>
        <span class="log-message">${workerPrefix}${log.message}</span>
    `;

    logEl.appendChild(entry);
    logEl.scrollTop = logEl.scrollHeight;
}

function toggleLogFilter() {
    // Toggle filter mode
    logFilterMode = logFilterMode === 'highlights' ? 'all' : 'highlights';

    // Update toggle UI
    const toggle = document.getElementById('log-filter-toggle');
    toggle.querySelectorAll('.filter-option').forEach(opt => {
        opt.classList.toggle('active', opt.dataset.filter === logFilterMode);
    });

    // Re-render all logs with new filter
    rerenderLogs();
}

function rerenderLogs() {
    const logEl = document.getElementById('log');
    logEl.innerHTML = '';

    const logsToShow = logFilterMode === 'all'
        ? allLogs
        : allLogs.filter(isHighlightLog);

    if (logsToShow.length === 0) {
        logEl.innerHTML = '<div class="log-entry"><span class="log-time"></span><span class="log-message" style="color: #444;">Inga highlights än...</span></div>';
        return;
    }

    logsToShow.forEach(log => renderLogEntry(log));
}

function updateTeamFromLog(log) {
    if (!log.worker) return;

    // Map all workers to their badge IDs
    const workerMap = {
        'chef': 'team-chef',
        'devops': 'team-devops',
        'ad': 'team-ad',
        'architect': 'team-architect',
        'backend': 'team-backend',
        'frontend': 'team-frontend',
        'tester': 'team-tester',
        'reviewer': 'team-reviewer'
    };

    // Extract base worker type from instance ID (e.g., "frontend-2" -> "frontend")
    const workerRaw = log.worker.toLowerCase();
    const workerType = workerRaw.replace(/-\d+$/, ''); // Remove -N suffix if present
    const teamId = workerMap[workerType];
    if (!teamId) return;

    const element = document.getElementById(teamId);
    if (!element) return;

    // Initialize count if needed
    if (!activeWorkerCounts[workerType]) {
        activeWorkerCounts[workerType] = 0;
    }

    // Worker started -> increment count
    if (log.log_type === 'worker_start') {
        activeWorkerCounts[workerType]++;
    }
    // Worker done -> decrement count
    else if (log.log_type === 'worker_done') {
        activeWorkerCounts[workerType] = Math.max(0, activeWorkerCounts[workerType] - 1);
    }

    // Update the dots based on count
    const count = activeWorkerCounts[workerType];
    const dots = element.querySelectorAll('.dot');

    // Remove old worker count classes
    element.classList.remove('workers-2', 'workers-3');

    // Add class to show extra dots if needed
    if (count >= 3) {
        element.classList.add('workers-3');
    } else if (count >= 2) {
        element.classList.add('workers-2');
    }

    // Light up the right number of dots (max 3)
    dots.forEach((dot, index) => {
        if (index < count) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });

    // Badge is active if any workers are running
    if (count > 0) {
        element.classList.add('active');
    } else {
        element.classList.remove('active');
    }
}

async function updateFiles() {
    if (!currentSprintId) return;

    try {
        const response = await fetch(`${API_BASE}/sprints/${currentSprintId}/files`, {
            headers: getHeaders()
        });

        const data = await response.json();

        // Parse files string (it's a formatted list)
        const filesText = data.files || '';
        const fileLines = filesText.split('\n').filter(line => line.trim());

        if (fileLines.length > 0) {
            document.getElementById('files-count').textContent = fileLines.length + ' filer';
            const filesList = document.getElementById('files-list');

            // Clear waiting message on first file
            if (knownFiles.size === 0 && fileLines.length > 0) {
                filesList.innerHTML = '';
            }

            fileLines.forEach(line => {
                // Parse line format: "  filename (size)"
                const match = line.match(/^\s*(.+?)\s*\((.+?)\)\s*$/);
                if (match && !knownFiles.has(match[1])) {
                    const name = match[1];
                    const size = match[2];
                    knownFiles.add(name);

                    const item = document.createElement('div');
                    item.className = 'file-item';
                    item.innerHTML = `<span class="file-icon">></span><span class="file-name">${name}</span><span class="file-size">${size}</span>`;
                    item.onclick = () => showFileContent(name);
                    filesList.appendChild(item);
                }
            });
        }
    } catch (e) {
        console.error(e);
    }
}

// File viewer modal functions
async function showFileContent(filePath) {
    if (!currentSprintId) return;

    const modal = document.getElementById('file-modal');
    const pathEl = document.getElementById('file-modal-path');
    const contentEl = document.getElementById('file-modal-content');

    // Show modal with loading state
    pathEl.textContent = filePath;
    contentEl.textContent = 'Laddar...';
    modal.style.display = 'flex';

    try {
        const response = await fetch(`${API_BASE}/sprints/${currentSprintId}/files/${encodeURIComponent(filePath)}`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const data = await response.json();
            contentEl.textContent = data.content;
        } else {
            contentEl.textContent = 'Kunde inte ladda filen.';
        }
    } catch (e) {
        contentEl.textContent = 'Fel vid laddning: ' + e.message;
        console.error(e);
    }
}

function hideFileModal() {
    document.getElementById('file-modal').style.display = 'none';
}

function closeFileModal(event) {
    // Close if clicking outside the modal content
    if (event.target.id === 'file-modal') {
        hideFileModal();
    }
}

function addLogLine(message, type = 'info') {
    const log = document.getElementById('log');
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;

    const time = new Date().toLocaleTimeString('sv-SE', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    const icon = LOG_ICONS[type] || '>';
    entry.innerHTML = `<span class="log-time">${time}</span><span class="log-icon">${icon}</span><span class="log-message">${message}</span>`;
    log.appendChild(entry);
    log.scrollTop = log.scrollHeight;
}

// Event listeners
document.getElementById('task').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') startSprint();
});

document.getElementById('login-email').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') login();
});

document.getElementById('login-password').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') login();
});

document.getElementById('modal-custom-answer').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendCustomAnswer();
});

// Close file modal with Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        hideFileModal();
    }
});

// Team toggle handler
function updateTeamLabels() {
    const isGroq = document.getElementById('team-toggle').checked;
    selectedTeam = isGroq ? 'groq-team' : 'a-team';

    document.getElementById('team-label-a').classList.toggle('active', !isGroq);
    document.getElementById('team-label-groq').classList.toggle('active', isGroq);
}

document.getElementById('team-toggle').addEventListener('change', updateTeamLabels);

// Sprint History functions
let historyOpen = false;

function toggleHistory() {
    historyOpen = !historyOpen;
    const body = document.getElementById('history-body');
    const toggle = document.getElementById('history-toggle');

    body.style.display = historyOpen ? 'block' : 'none';
    toggle.classList.toggle('open', historyOpen);

    if (historyOpen) {
        loadSprintHistory();
    }
}

async function loadSprintHistory() {
    const listEl = document.getElementById('history-list');

    try {
        const response = await fetch(`${API_BASE}/sprints`, {
            headers: getHeaders()
        });

        if (!response.ok) {
            listEl.innerHTML = '<div class="history-empty">Kunde inte ladda historik</div>';
            return;
        }

        const data = await response.json();
        const sprints = data.sprints || [];

        if (sprints.length === 0) {
            listEl.innerHTML = '<div class="history-empty">Inga tidigare sprints</div>';
            return;
        }

        listEl.innerHTML = sprints.map(sprint => {
            const date = new Date(sprint.created_at);
            const dateStr = date.toLocaleDateString('sv-SE', {
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });

            const cost = sprint.cost_usd || 0;
            const costStr = cost >= 0.01 ? `$${cost.toFixed(2)}` : `$${cost.toFixed(3)}`;

            const isActive = sprint.id === currentSprintId;

            return `
                <div class="history-item ${isActive ? 'active' : ''}" onclick="loadSprint('${sprint.id}')">
                    <span class="history-status ${sprint.status}"></span>
                    <div class="history-info">
                        <div class="history-task">${escapeHtml(sprint.task)}</div>
                        <div class="history-meta">
                            <span class="history-date">${dateStr}</span>
                            <span class="history-cost">${costStr}</span>
                            <span class="history-team">${sprint.team || 'a-team'}</span>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

    } catch (e) {
        console.error('Error loading history:', e);
        listEl.innerHTML = '<div class="history-empty">Fel vid laddning</div>';
    }
}

async function loadSprint(sprintId) {
    // Stop any existing connections/polling
    disconnectWebSocket();
    stopFilePolling();
    if (polling) {
        clearInterval(polling);
        polling = null;
    }

    // Set current sprint
    currentSprintId = sprintId;
    lastLogId = 0;
    knownFiles = new Set();
    allLogs = []; // Reset logs for filtering
    activeWorkerCounts = {};

    // Reset UI
    document.getElementById('log').innerHTML = '<div class="log-entry"><span class="log-time"></span><span class="log-message" style="color: #444;">Laddar loggar...</span></div>';
    document.getElementById('files-list').innerHTML = '<div class="file-item" style="color: #444;">Laddar filer...</div>';
    document.getElementById('files-count').textContent = '0 filer';
    updateGitHubLink(null); // Reset GitHub link
    document.querySelectorAll('.team-member').forEach(el => {
        el.classList.remove('active', 'workers-2', 'workers-3');
        el.querySelectorAll('.dot').forEach(dot => dot.classList.remove('active'));
    });

    try {
        // Fetch sprint details
        const response = await fetch(`${API_BASE}/sprints/${sprintId}`, {
            headers: getHeaders()
        });

        if (!response.ok) {
            addLogLine('Kunde inte ladda sprint', 'error');
            return;
        }

        const sprint = await response.json();

        // Update status display
        const statusMap = {
            'completed': { class: 'terminal-status done', text: 'done' },
            'failed': { class: 'terminal-status', text: 'failed' },
            'cancelled': { class: 'terminal-status', text: 'cancelled' },
            'running': { class: 'terminal-status running', text: 'running' },
            'pending': { class: 'terminal-status', text: 'pending' }
        };
        const statusInfo = statusMap[sprint.status] || { class: 'terminal-status', text: sprint.status };
        document.getElementById('status').className = statusInfo.class;
        document.getElementById('status').textContent = statusInfo.text;

        // Update token counter
        const inputTokens = sprint.input_tokens || 0;
        const outputTokens = sprint.output_tokens || 0;
        const totalCost = sprint.cost_usd || 0;
        const formatTokens = (n) => n >= 1000 ? `${(n / 1000).toFixed(0)}k` : n;
        const costText = totalCost >= 0.01 ? `$${totalCost.toFixed(2)}` : `$${totalCost.toFixed(3)}`;
        document.getElementById('tokens').textContent = `${formatTokens(inputTokens)} in / ${formatTokens(outputTokens)} out (${costText})`;

        // Update task input
        document.getElementById('task').value = sprint.task;

        // Update GitHub link
        updateGitHubLink(sprint.github_repo);

        // Update buttons based on status
        if (sprint.status === 'running') {
            document.getElementById('start').disabled = true;
            document.getElementById('cancel').style.display = 'inline-block';
            document.getElementById('cancel').disabled = false;
            // Connect via WebSocket for running sprint
            connectWebSocket(sprintId);
            // Start file polling
            filePolling = setInterval(pollFilesAndQuestions, 2000);
        } else {
            document.getElementById('start').disabled = false;
            document.getElementById('cancel').style.display = 'none';
        }

        // Load all logs
        await loadAllLogs(sprintId);

        // Load files
        await updateFiles();

        // Update history list to show active state
        loadSprintHistory();

    } catch (e) {
        console.error('Error loading sprint:', e);
        addLogLine('Fel vid laddning: ' + e.message, 'error');
    }
}

async function loadAllLogs(sprintId) {
    const logEl = document.getElementById('log');
    logEl.innerHTML = '';

    try {
        const response = await fetch(`${API_BASE}/sprints/${sprintId}/logs?since_id=0`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const data = await response.json();

            if (data.logs.length === 0) {
                logEl.innerHTML = '<div class="log-entry"><span class="log-time"></span><span class="log-message" style="color: #444;">Inga loggar</span></div>';
                return;
            }

            for (const log of data.logs) {
                addLogFromServer(log);
                lastLogId = log.id;
            }
        }
    } catch (e) {
        console.error('Error loading logs:', e);
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Initialize
checkAuth();
updateTeamLabels(); // Set initial state
