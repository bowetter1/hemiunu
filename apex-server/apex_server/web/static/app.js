// Apex Server Dashboard
const API_BASE = '/api/v1';
let token = localStorage.getItem('apex_token');
let currentSprintId = null;
let polling = null;
let knownFiles = new Set();
let lastLogId = 0;
let activeWorkerCounts = {}; // Track count of active workers per type

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
async function startSprint() {
    const task = document.getElementById('task').value;
    if (!task) return;

    document.getElementById('start').disabled = true;
    document.getElementById('status').className = 'terminal-status running';
    document.getElementById('status').textContent = 'running';
    document.getElementById('log').innerHTML = '';
    document.getElementById('files-list').innerHTML = '<div class="file-item" style="color: #444;">Vantar pa filer...</div>';
    knownFiles = new Set();
    lastLogId = 0;
    activeWorkerCounts = {}; // Reset worker counts

    // Reset all dots to inactive
    document.querySelectorAll('.team-member').forEach(el => {
        el.classList.remove('active');
        el.querySelectorAll('.dot').forEach(dot => dot.classList.remove('active'));
    });

    document.getElementById('team-chef').classList.add('active');
    addLogLine('Startar sprint...', 'info');

    try {
        // Start polling immediately for logs
        polling = setInterval(pollLogs, 1000);

        const response = await fetch(`${API_BASE}/sprints`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ task })
        });

        const data = await response.json();

        if (!response.ok) {
            clearInterval(polling);
            addLogLine('Error: ' + (data.detail || 'Kunde inte starta sprint'), 'error');
            document.getElementById('start').disabled = false;
            document.getElementById('status').className = 'terminal-status';
            document.getElementById('status').textContent = 'error';
            return;
        }

        currentSprintId = data.id;

        // Sprint runs in background - keep polling until done
        // The polling interval is already running, just let it continue

    } catch (e) {
        clearInterval(polling);
        addLogLine('Error: ' + e.message, 'error');
        document.getElementById('start').disabled = false;
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

        // Check sprint status
        const statusResponse = await fetch(`${API_BASE}/sprints/${currentSprintId}`, {
            headers: getHeaders()
        });

        if (statusResponse.ok) {
            const sprint = await statusResponse.json();

            if (sprint.status === 'completed' || sprint.status === 'failed') {
                // Sprint is done - stop polling
                clearInterval(polling);
                polling = null;

                document.getElementById('status').className = sprint.status === 'completed' ? 'terminal-status done' : 'terminal-status';
                document.getElementById('status').textContent = sprint.status === 'completed' ? 'done' : 'failed';
                document.getElementById('start').disabled = false;
                document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
            }
        }

    } catch (e) {
        console.error(e);
    }
}

function addLogFromServer(log) {
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

    // Update team status based on worker
    updateTeamFromLog(log);
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
                    filesList.appendChild(item);
                }
            });
        }
    } catch (e) {
        console.error(e);
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

// Initialize
checkAuth();
