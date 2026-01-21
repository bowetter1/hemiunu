let polling = null;
let lastLogCount = 0;
let knownFiles = new Set();

async function startSprint() {
    const task = document.getElementById('task').value;
    if (!task) return;

    document.getElementById('start').disabled = true;
    document.getElementById('status').className = 'terminal-status running';
    document.getElementById('status').textContent = 'running';
    document.getElementById('log').innerHTML = '';
    document.getElementById('files-list').innerHTML = '<div class="file-item" style="color: #444;">Väntar på filer...</div>';
    lastLogCount = 0;
    knownFiles = new Set();

    document.getElementById('team-opus').classList.add('active');

    await fetch('/api/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ task })
    });

    polling = setInterval(pollStatus, 500);
}

async function pollStatus() {
    try {
        // Läs sprint.log direkt för MCP-uppdateringar
        const logResponse = await fetch('/api/log');
        const logData = await logResponse.json();

        if (logData.lines && logData.lines.length > lastLogCount) {
            const newLines = logData.lines.slice(lastLogCount);
            newLines.forEach(line => addLogLine(line));
            lastLogCount = logData.lines.length;
        }

        // Uppdatera filer
        const statusResponse = await fetch('/api/status');
        const statusData = await statusResponse.json();
        if (statusData.project) {
            updateFiles(statusData.project);
        }

        if (!logData.running && lastLogCount > 0) {
            document.getElementById('status').className = 'terminal-status done';
            document.getElementById('status').textContent = 'done';
            document.getElementById('start').disabled = false;
            clearInterval(polling);
            document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
        }
    } catch (e) {
        console.error(e);
    }
}

function addLogLine(line) {
    const log = document.getElementById('log');
    const entry = document.createElement('div');

    // Bestäm typ baserat på innehåll
    let logType = '';
    if (line.includes('mcp_tool:')) logType = 'mcp';
    else if (line.includes('STARTAR')) logType = 'cli_start';
    else if (line.includes('klar')) logType = 'worker_done';
    else if (line.includes('CEO') || line.includes('OPUS')) logType = 'opus';
    else if (line.includes('SPRINT')) logType = 'meeting';

    entry.className = `log-entry ${logType}`;
    entry.innerHTML = `<span class="log-message">${line.trim()}</span>`;
    log.appendChild(entry);
    log.scrollTop = log.scrollHeight;

    // Uppdatera team-status baserat på vem som jobbar
    if (line.includes('STARTAR QWEN') || line.includes('QWEN klar')) {
        document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
        document.getElementById('team-qwen').classList.add('active');
    } else if (line.includes('STARTAR CLAUDE') || line.includes('CLAUDE klar')) {
        document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
        document.getElementById('team-opus').classList.add('active');
    } else if (line.includes('anropat med') || line.includes('CEO') || line.includes('OPUS')) {
        document.querySelectorAll('.team-member').forEach(el => el.classList.remove('active'));
        document.getElementById('team-opus').classList.add('active');
    }
}

async function updateFiles(project) {
    try {
        const response = await fetch('/api/files?project=' + encodeURIComponent(project));
        const files = await response.json();

        if (files.length > 0) {
            document.getElementById('files-count').textContent = files.length + ' filer';
            const filesList = document.getElementById('files-list');

            // Rensa "väntar" meddelande vid första filen
            if (knownFiles.size === 0) {
                filesList.innerHTML = '';
            }
            files.forEach(file => {
                if (!knownFiles.has(file.path)) {
                    knownFiles.add(file.path);
                    const item = document.createElement('div');
                    item.className = 'file-item';
                    const icon = file.name.endsWith('.py') ? '🐍' :
                                 file.name.endsWith('.js') ? '📜' :
                                 file.name.endsWith('.ts') ? '📘' :
                                 file.name.endsWith('.html') ? '🌐' :
                                 file.name.endsWith('.css') ? '🎨' :
                                 file.name.endsWith('.md') ? '📝' :
                                 file.name.endsWith('.json') ? '📋' : '📄';
                    item.innerHTML = `<span class="file-icon">${icon}</span><span class="file-name">${file.name}</span><span class="file-size">${file.size}</span>`;
                    filesList.appendChild(item);
                }
            });
        }
    } catch (e) {
        console.error(e);
    }
}

// Question handling
let questionPolling = null;
let lastQuestionTimestamp = null;

function startQuestionPolling() {
    questionPolling = setInterval(pollQuestion, 1000);
}

async function pollQuestion() {
    try {
        const response = await fetch('/api/question');
        const data = await response.json();

        if (data.question && !data.answered && data.timestamp !== lastQuestionTimestamp) {
            lastQuestionTimestamp = data.timestamp;
            showQuestion(data);
        }
    } catch (e) {
        console.error(e);
    }
}

function showQuestion(data) {
    const modal = document.getElementById('question-modal');
    const textEl = document.getElementById('question-text');
    const optionsEl = document.getElementById('question-options');
    const inputEl = document.getElementById('answer-input');

    textEl.textContent = data.question;
    optionsEl.innerHTML = '';

    if (data.options && data.options.length > 0) {
        data.options.forEach(opt => {
            const btn = document.createElement('div');
            btn.className = 'question-option';
            btn.textContent = opt;
            btn.onclick = () => {
                inputEl.value = opt;
                submitAnswer();
            };
            optionsEl.appendChild(btn);
        });
    }

    inputEl.value = '';
    modal.style.display = 'flex';
    inputEl.focus();
}

async function submitAnswer() {
    const inputEl = document.getElementById('answer-input');
    const answer = inputEl.value.trim();
    if (!answer) return;

    try {
        await fetch('/api/answer', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ answer })
        });

        document.getElementById('question-modal').style.display = 'none';
    } catch (e) {
        console.error(e);
    }
}

// Event listeners
document.getElementById('task').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') startSprint();
});

document.getElementById('answer-input').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') submitAnswer();
});

// Start question polling when page loads
startQuestionPolling();
