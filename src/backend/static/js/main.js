import gameState from "./state/gameState.js";
import audioManager from "./audio/audioManager.js";
import { connect, send } from "./network/websocket.js";
import {
  draw,
  flashError,
  getValidPlacements,
  renderGhostBlock,
} from "./rendering/canvas.js";

const blockCountEl = document.getElementById("block-count");
const stoneCountEl = document.getElementById("stone-count");
const playerCountEl = document.getElementById("player-count");
const statusBar = document.getElementById("status-bar");
const milestoneProgressEl = document.getElementById("milestone-progress");
const milestoneNoticeEl = document.getElementById("milestone-notification");
const errorNoticeEl = document.getElementById("error-notification");
const placeWarningEl = document.getElementById("place-warning");
const placeBtn = document.getElementById("btn-place");
const canvas = document.getElementById("game-canvas");
const chatPanel = document.getElementById("chat-panel");
const chatToggleBtn = document.getElementById("chat-toggle");
const chatMessagesEl = document.getElementById("chat-messages");
const chatForm = document.getElementById("chat-form");
const chatInput = document.getElementById("chat-input");
const leaderboardListEl = document.getElementById("leaderboard-list");
const blockTypeButtons = document.querySelectorAll(".block-type-option");
const blockTypeInfoEl = document.getElementById("block-type-info");
const tutorialOverlay = document.getElementById("tutorial-overlay");
const tutorialCloseBtn = document.getElementById("tutorial-close");

const USER_ID_KEY = "hemiunu-user-id";
const CHAT_COLLAPSED_KEY = "hemiunu-chat-collapsed";
const TUTORIAL_SEEN_KEY = "hemiunu-tutorial-seen";
const MILESTONE_INTERVAL = 100;
const ERROR_NOTICE_DURATION = 3000;
const GRID_SIZE = 10;
const MAX_CHAT_MESSAGES = 60;
const LEADERBOARD_LIMIT = 10;
const DEFAULT_BLOCK_TYPE = "limestone";
const BLOCK_TYPE_INFO = {
  granite: {
    description: "Stark bas. +2 sten när en milstolpe nås.",
  },
  limestone: {
    description: "Standardblock. Vanligast i pyramiden.",
  },
  sandstone: {
    description:
      "Lätt att bryta. +1 extra sten vid brytning om du har sandstensblock.",
  },
};

const getUserId = () => {
  const stored = window.localStorage.getItem(USER_ID_KEY);
  if (stored) {
    return stored;
  }
  const generated =
    (window.crypto && window.crypto.randomUUID && window.crypto.randomUUID()) ??
    `user-${Date.now()}`;
  window.localStorage.setItem(USER_ID_KEY, generated);
  return generated;
};

const userId = getUserId();

const getUserName = (id) => {
  if (!id) {
    return "Player";
  }
  const normalized = String(id);
  return `Player ${normalized.slice(0, 4)}`;
};

const getUserLabel = (id) => {
  if (!id) {
    return "Player";
  }
  if (id === userId) {
    return "You";
  }
  return getUserName(id);
};

const currentUserLabel = getUserLabel(userId);
const currentUserName = getUserName(userId);
const chatMessages = [];
let lastLeaderboardSource = null;

const toTimestamp = (value) => {
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === "number") {
    return value < 1000000000000 ? value * 1000 : value;
  }
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return Date.now();
};

const formatTimestamp = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });
};

const normalizeChatMessage = (raw) => {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const payload = raw.data && typeof raw.data === "object" ? raw.data : raw;
  const text =
    typeof payload.message === "string"
      ? payload.message.trim()
      : typeof payload.text === "string"
        ? payload.text.trim()
        : typeof payload.content === "string"
          ? payload.content.trim()
          : "";
  if (!text) {
    return null;
  }
  const senderId =
    payload.user_id ?? payload.userId ?? payload.sender_id ?? payload.senderId ?? null;
  const usernameCandidate =
    typeof payload.username === "string"
      ? payload.username.trim()
      : typeof payload.user_name === "string"
        ? payload.user_name.trim()
        : typeof payload.user === "string"
          ? payload.user.trim()
          : "";
  const username = usernameCandidate || getUserLabel(senderId);
  const timestampValue = toTimestamp(
    payload.timestamp ?? payload.time ?? payload.created_at ?? payload.createdAt,
  );
  return { text, username, timestampValue, userId: senderId };
};

const isDuplicateMessage = (message) => {
  const last = chatMessages[chatMessages.length - 1];
  if (!last) {
    return false;
  }
  return (
    last.userId === message.userId &&
    last.text === message.text &&
    Math.abs(last.timestampValue - message.timestampValue) < 2000
  );
};

const renderChatMessage = (message) => {
  const item = document.createElement("li");
  item.className = "chat-message";
  if (message.userId && message.userId === userId) {
    item.classList.add("is-own");
  }

  const meta = document.createElement("div");
  meta.className = "chat-meta";

  const userSpan = document.createElement("span");
  userSpan.className = "chat-user";
  userSpan.textContent = message.username || "Player";

  const timeEl = document.createElement("time");
  timeEl.className = "chat-time";
  const formatted = formatTimestamp(message.timestampValue);
  timeEl.textContent = formatted;
  if (message.timestampValue) {
    timeEl.dateTime = new Date(message.timestampValue).toISOString();
  }

  meta.append(userSpan, timeEl);

  const textEl = document.createElement("div");
  textEl.className = "chat-text";
  textEl.textContent = message.text;

  item.append(meta, textEl);
  return item;
};

const scrollChatToLatest = () => {
  if (!chatMessagesEl) {
    return;
  }
  requestAnimationFrame(() => {
    chatMessagesEl.scrollTop = chatMessagesEl.scrollHeight;
  });
};

const appendChatMessage = (message) => {
  if (!message || !chatMessagesEl) {
    return;
  }
  if (isDuplicateMessage(message)) {
    return;
  }
  chatMessages.push(message);
  if (chatMessages.length > MAX_CHAT_MESSAGES) {
    chatMessages.shift();
    if (chatMessagesEl.firstElementChild) {
      chatMessagesEl.removeChild(chatMessagesEl.firstElementChild);
    }
  }
  chatMessagesEl.appendChild(renderChatMessage(message));
  scrollChatToLatest();
};

const setChatMessages = (messages) => {
  if (!chatMessagesEl) {
    return;
  }
  chatMessages.length = 0;
  chatMessagesEl.innerHTML = "";
  if (!Array.isArray(messages)) {
    return;
  }
  const fragment = document.createDocumentFragment();
  messages.slice(-MAX_CHAT_MESSAGES).forEach((entry) => {
    const normalized = normalizeChatMessage(entry);
    if (!normalized) {
      return;
    }
    chatMessages.push(normalized);
    fragment.appendChild(renderChatMessage(normalized));
  });
  chatMessagesEl.appendChild(fragment);
  scrollChatToLatest();
};

const extractLeaderboardEntries = (payload) => {
  if (!payload) {
    return [];
  }
  if (Array.isArray(payload)) {
    return payload;
  }
  const candidates = [
    payload.leaderboard,
    payload.top_players,
    payload.topPlayers,
    payload.players,
    payload.entries,
    payload.list,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate;
    }
  }
  return [];
};

const normalizeLeaderboardEntry = (entry, index) => {
  if (!entry || typeof entry !== "object") {
    return { userId: null, name: `Player ${index + 1}`, score: 0 };
  }
  const userId = entry.user_id ?? entry.userId ?? entry.id ?? null;
  const nameCandidate =
    typeof entry.username === "string"
      ? entry.username.trim()
      : typeof entry.name === "string"
        ? entry.name.trim()
        : typeof entry.user === "string"
          ? entry.user.trim()
          : "";
  const name = nameCandidate || getUserLabel(userId) || `Player ${index + 1}`;
  const scoreValue = Number(
    entry.score ??
      entry.blocks ??
      entry.total_blocks ??
      entry.placed_blocks ??
      entry.stone ??
      entry.value ??
      0,
  );
  const score = Number.isFinite(scoreValue) ? Math.floor(scoreValue) : 0;
  return { userId, name, score };
};

const renderLeaderboard = (entries) => {
  if (!leaderboardListEl) {
    return;
  }
  leaderboardListEl.innerHTML = "";
  if (!entries.length) {
    const emptyItem = document.createElement("li");
    emptyItem.className = "leaderboard-empty";
    emptyItem.textContent = "No rankings yet.";
    leaderboardListEl.appendChild(emptyItem);
    return;
  }
  const fragment = document.createDocumentFragment();
  entries.slice(0, LEADERBOARD_LIMIT).forEach((entry, index) => {
    const normalized = normalizeLeaderboardEntry(entry, index);
    const item = document.createElement("li");
    item.className = "leaderboard-entry";
    if (normalized.userId && normalized.userId === userId) {
      item.classList.add("is-current");
    }
    if (
      !normalized.userId &&
      (normalized.name === currentUserLabel || normalized.name === currentUserName)
    ) {
      item.classList.add("is-current");
    }

    const rank = document.createElement("span");
    rank.className = "leaderboard-rank";
    rank.textContent = String(index + 1);

    const name = document.createElement("span");
    name.className = "leaderboard-name";
    name.textContent = normalized.name;

    const score = document.createElement("span");
    score.className = "leaderboard-score";
    score.textContent = Number.isFinite(normalized.score)
      ? normalized.score.toLocaleString()
      : "0";

    item.append(rank, name, score);
    fragment.appendChild(item);
  });
  leaderboardListEl.appendChild(fragment);
};

const updateLeaderboard = (payload) => {
  const entries = extractLeaderboardEntries(payload);
  renderLeaderboard(entries);
};

const syncLeaderboardFromStats = () => {
  if (!leaderboardListEl) {
    return;
  }
  const candidate =
    gameState.stats?.leaderboard ??
    gameState.stats?.top_players ??
    gameState.stats?.topPlayers ??
    null;
  if (!Array.isArray(candidate) || candidate === lastLeaderboardSource) {
    return;
  }
  lastLeaderboardSource = candidate;
  renderLeaderboard(candidate);
};

const setChatCollapsed = (collapsed) => {
  if (!chatPanel) {
    return;
  }
  chatPanel.classList.toggle("collapsed", collapsed);
  if (chatToggleBtn) {
    chatToggleBtn.setAttribute("aria-expanded", (!collapsed).toString());
    chatToggleBtn.textContent = collapsed ? ">>" : "<<";
  }
  window.localStorage.setItem(CHAT_COLLAPSED_KEY, collapsed ? "1" : "0");
};

const initChatPanel = () => {
  if (!chatPanel) {
    return;
  }
  const stored = window.localStorage.getItem(CHAT_COLLAPSED_KEY);
  const isCollapsed = stored === "1";
  setChatCollapsed(isCollapsed);

  if (chatToggleBtn) {
    chatToggleBtn.addEventListener("click", () => {
      setChatCollapsed(!chatPanel.classList.contains("collapsed"));
    });
  }

  if (chatForm && chatInput) {
    chatForm.addEventListener("submit", (event) => {
      event.preventDefault();
      const text = chatInput.value.trim();
      if (!text) {
        return;
      }
      const timestamp = Date.now();
      const outgoing = {
        message: text,
        user_id: userId,
        username: currentUserName,
        timestamp,
      };
      const normalized = normalizeChatMessage(outgoing);
      if (normalized) {
        appendChatMessage(normalized);
      }
      send({ type: "chat_message", user_id: userId, data: outgoing });
      chatInput.value = "";
      chatInput.focus();
    });
  }
};

const hasSeenTutorial = () => {
  try {
    return window.localStorage.getItem(TUTORIAL_SEEN_KEY) === "true";
  } catch {
    return false;
  }
};

const setTutorialVisible = (visible) => {
  if (!tutorialOverlay) {
    return;
  }
  tutorialOverlay.classList.toggle("is-hidden", !visible);
};

const markTutorialSeen = () => {
  try {
    window.localStorage.setItem(TUTORIAL_SEEN_KEY, "true");
  } catch {
  }
};

const initTutorialOverlay = () => {
  if (!tutorialOverlay) {
    return;
  }
  setTutorialVisible(!hasSeenTutorial());
  if (tutorialCloseBtn) {
    tutorialCloseBtn.addEventListener("click", () => {
      setTutorialVisible(false);
      markTutorialSeen();
    });
  }
};

const setStatus = (value) => {
  if (statusBar) {
    statusBar.textContent = value;
  }
};

let milestoneTimer = null;
let errorNoticeTimer = null;
let hoverPlacement = null;
let currentBlockType = DEFAULT_BLOCK_TYPE;

const getBlockTypeInfo = (type) =>
  BLOCK_TYPE_INFO[type] ?? BLOCK_TYPE_INFO[DEFAULT_BLOCK_TYPE];

const setBlockType = (type) => {
  const resolvedType = BLOCK_TYPE_INFO[type] ? type : DEFAULT_BLOCK_TYPE;
  currentBlockType = resolvedType;
  blockTypeButtons.forEach((button) => {
    const isSelected = button.dataset.blockType === resolvedType;
    button.classList.toggle("is-selected", isSelected);
    button.setAttribute("aria-pressed", isSelected.toString());
  });
  if (blockTypeInfoEl) {
    blockTypeInfoEl.textContent = getBlockTypeInfo(resolvedType).description;
  }
  if (hoverPlacement?.placement) {
    hoverPlacement.placement.type = currentBlockType;
  }
};

const initBlockTypeSelector = () => {
  if (!blockTypeButtons.length) {
    return;
  }
  blockTypeButtons.forEach((button) => {
    const type = button.dataset.blockType;
    const info = getBlockTypeInfo(type);
    if (info) {
      button.title = info.description;
    }
    button.addEventListener("click", () => {
      setBlockType(type);
    });
  });
  const preset = Array.from(blockTypeButtons).find(
    (button) => button.getAttribute("aria-pressed") === "true",
  )?.dataset.blockType;
  setBlockType(preset ?? DEFAULT_BLOCK_TYPE);
};

const getTotalBlocks = () => {
  const statsTotal = gameState.stats?.total_blocks;
  if (typeof statsTotal === "number") {
    return statsTotal;
  }
  if (Array.isArray(gameState.pyramid)) {
    return gameState.pyramid.length;
  }
  return 0;
};

const updateHud = () => {
  const totalBlocks = getTotalBlocks();
  if (blockCountEl) {
    blockCountEl.textContent = totalBlocks;
  }
  if (stoneCountEl) {
    stoneCountEl.textContent = gameState.resources?.stone ?? 0;
  }
  if (playerCountEl) {
    playerCountEl.textContent = gameState.stats?.online_players ?? 0;
  }
  if (milestoneProgressEl) {
    const progress = totalBlocks % MILESTONE_INTERVAL;
    milestoneProgressEl.textContent = `${progress}/${MILESTONE_INTERVAL}`;
  }
  updatePlacementState();
  syncLeaderboardFromStats();
};

const showMilestoneNotification = (data) => {
  if (!milestoneNoticeEl) {
    return;
  }
  const totalBlocks =
    typeof data?.total_blocks === "number" ? data.total_blocks : getTotalBlocks();
  milestoneNoticeEl.textContent = `Milestone reached: ${totalBlocks} blocks`;
  milestoneNoticeEl.classList.add("show");
  if (milestoneTimer) {
    window.clearTimeout(milestoneTimer);
  }
  milestoneTimer = window.setTimeout(() => {
    milestoneNoticeEl.classList.remove("show");
  }, 2500);
};

const showErrorNotice = (message) => {
  if (!errorNoticeEl) {
    return;
  }
  const text = message || "Ett fel uppstod.";
  errorNoticeEl.textContent = text;
  errorNoticeEl.classList.add("show");
  if (errorNoticeTimer) {
    window.clearTimeout(errorNoticeTimer);
  }
  errorNoticeTimer = window.setTimeout(() => {
    errorNoticeEl.classList.remove("show");
  }, ERROR_NOTICE_DURATION);
};

const updatePlacementState = () => {
  const stone = Number(gameState.resources?.stone ?? 0);
  const canPlace = Number.isFinite(stone) && stone > 0;

  if (placeBtn) {
    placeBtn.disabled = !canPlace;
  }
  if (placeWarningEl) {
    if (canPlace) {
      placeWarningEl.classList.remove("show");
      placeWarningEl.textContent = "";
    } else {
      placeWarningEl.textContent = "Behöver sten!";
      placeWarningEl.classList.add("show");
    }
  }
};

const handleSocketMessage = (event) => {
  let message;
  try {
    message = JSON.parse(event.data);
  } catch {
    return;
  }

  if (!message || typeof message !== "object") {
    return;
  }

  switch (message.type) {
    case "chat_message": {
      const normalized = normalizeChatMessage(message.data ?? message);
      if (normalized) {
        appendChatMessage(normalized);
      }
      break;
    }
    case "chat_history": {
      const history = Array.isArray(message.data)
        ? message.data
        : message.data?.messages;
      if (Array.isArray(history)) {
        setChatMessages(history);
      }
      break;
    }
    case "leaderboard_update":
    case "leaderboard_sync":
    case "leaderboard": {
      updateLeaderboard(message.data ?? message);
      break;
    }
    case "state_sync": {
      const leaderboardPayload =
        message.data?.leaderboard ??
        message.data?.stats?.leaderboard ??
        message.data?.top_players ??
        message.data?.stats?.top_players ??
        message.data?.topPlayers ??
        message.data?.stats?.topPlayers;
      if (leaderboardPayload) {
        updateLeaderboard(leaderboardPayload);
      }
      break;
    }
    default:
      break;
  }
};

const flashButton = (button) => {
  if (!button) return;
  button.style.transform = "scale(0.95)";
  button.style.boxShadow = "0 0 15px rgba(212, 160, 23, 0.6)";
  setTimeout(() => {
    button.style.transform = "";
    button.style.boxShadow = "";
  }, 150);
};

const positionKey = (x, y, z) => `${x},${y},${z}`;

const buildOccupied = () => {
  const occupied = new Set();
  if (!Array.isArray(gameState.pyramid)) {
    return occupied;
  }
  gameState.pyramid.forEach((block) => {
    if (!block || typeof block !== "object") {
      return;
    }
    const { x, y, z } = block;
    if (Number.isInteger(x) && Number.isInteger(y) && Number.isInteger(z)) {
      occupied.add(positionKey(x, y, z));
    }
  });
  return occupied;
};

const getMaxHeight = () => {
  if (!Array.isArray(gameState.pyramid)) {
    return 0;
  }
  return gameState.pyramid.reduce((maxHeight, block) => {
    if (!block || typeof block !== "object") {
      return maxHeight;
    }
    const z = block.z;
    return Number.isInteger(z) ? Math.max(maxHeight, z) : maxHeight;
  }, 0);
};

const hasSupport = (x, y, z, occupied) => {
  const supportZ = z - 1;
  return (
    occupied.has(positionKey(x - 1, y - 1, supportZ)) &&
    occupied.has(positionKey(x - 1, y + 1, supportZ)) &&
    occupied.has(positionKey(x + 1, y - 1, supportZ)) &&
    occupied.has(positionKey(x + 1, y + 1, supportZ))
  );
};

const findSupportedPlacement = (occupied) => {
  const candidateKeys = new Set();
  if (Array.isArray(gameState.pyramid)) {
    gameState.pyramid.forEach((block) => {
      if (!block || typeof block !== "object") {
        return;
      }
      const { x, y, z } = block;
      if (!Number.isInteger(x) || !Number.isInteger(y) || !Number.isInteger(z)) {
        return;
      }
      const nextZ = z + 1;
      candidateKeys.add(positionKey(x + 1, y + 1, nextZ));
      candidateKeys.add(positionKey(x + 1, y - 1, nextZ));
      candidateKeys.add(positionKey(x - 1, y + 1, nextZ));
      candidateKeys.add(positionKey(x - 1, y - 1, nextZ));
    });
  }

  let best = null;
  let bestDistance = 0;

  candidateKeys.forEach((key) => {
    if (occupied.has(key)) {
      return;
    }
    const [xStr, yStr, zStr] = key.split(",");
    const x = Number(xStr);
    const y = Number(yStr);
    const z = Number(zStr);
    if (!Number.isInteger(x) || !Number.isInteger(y) || !Number.isInteger(z)) {
      return;
    }
    if (z <= 0 || !hasSupport(x, y, z, occupied)) {
      return;
    }
    const distance = Math.abs(x) + Math.abs(y);
    if (
      !best ||
      z > best.z ||
      (z === best.z && distance < bestDistance) ||
      (z === best.z && distance === bestDistance && (x < best.x || (x === best.x && y < best.y)))
    ) {
      best = { x, y, z };
      bestDistance = distance;
    }
  });

  return best;
};

const findBasePlacement = (occupied) => {
  const maxAbs = 100;
  const isFree = (x, y) => !occupied.has(positionKey(x, y, 0));

  if (isFree(0, 0)) {
    return { x: 0, y: 0, z: 0 };
  }

  for (let radius = 1; radius <= maxAbs; radius += 1) {
    const corners = [
      [radius, radius],
      [radius, -radius],
      [-radius, radius],
      [-radius, -radius],
    ];
    for (const [x, y] of corners) {
      if (isFree(x, y)) {
        return { x, y, z: 0 };
      }
    }

    for (let x = -radius + 1; x <= radius - 1; x += 1) {
      if (isFree(x, radius)) {
        return { x, y: radius, z: 0 };
      }
    }
    for (let y = radius - 1; y >= -radius + 1; y -= 1) {
      if (isFree(radius, y)) {
        return { x: radius, y, z: 0 };
      }
    }
    for (let x = radius - 1; x >= -radius + 1; x -= 1) {
      if (isFree(x, -radius)) {
        return { x, y: -radius, z: 0 };
      }
    }
    for (let y = -radius + 1; y <= radius - 1; y += 1) {
      if (isFree(-radius, y)) {
        return { x: -radius, y, z: 0 };
      }
    }
  }

  return { x: 0, y: 0, z: 0 };
};

const getCanvasMetrics = () => {
  if (!canvas) {
    return null;
  }
  const displayWidth = canvas.clientWidth;
  const displayHeight = canvas.clientHeight;
  const blockSize = Math.max(20, Math.min(displayWidth, displayHeight) / 15);
  return {
    blockSize,
    centerX: displayWidth / 2,
    baseY: displayHeight - blockSize,
  };
};

const screenToGrid = (screenX, screenY, metrics) => {
  const { blockSize, centerX, baseY } = metrics;
  const dx = (screenX - centerX) / (blockSize * 0.6);
  const dy = (baseY - screenY) / (blockSize * 0.2);
  const x = Math.round((dx + dy) / 2);
  const y = Math.round((dy - dx) / 2);
  return { x, y };
};

const pickHoverPlacement = (gridX, gridY) => {
  const validPlacements = getValidPlacements(gameState.pyramid);
  let bestPlacement = null;

  validPlacements.forEach((placement) => {
    if (placement.x !== gridX || placement.y !== gridY) {
      return;
    }
    if (!bestPlacement || placement.z < bestPlacement.z) {
      bestPlacement = placement;
    }
  });

  if (bestPlacement) {
    return {
      placement: { ...bestPlacement, type: currentBlockType },
      isValid: true,
    };
  }

  const occupied = buildOccupied();
  const maxHeight = getMaxHeight();
  let candidateZ = 0;

  for (let z = 0; z <= maxHeight + 1; z += 1) {
    if (!occupied.has(positionKey(gridX, gridY, z))) {
      candidateZ = z;
      break;
    }
  }

  return {
    placement: {
      x: gridX,
      y: gridY,
      z: candidateZ,
      type: currentBlockType,
    },
    isValid: false,
  };
};

const updateHoverFromEvent = (event) => {
  if (!canvas) {
    return;
  }
  const rect = canvas.getBoundingClientRect();
  const metrics = getCanvasMetrics();
  if (!metrics) {
    return;
  }
  const screenX = event.clientX - rect.left;
  const screenY = event.clientY - rect.top;
  const { x, y } = screenToGrid(screenX, screenY, metrics);

  if (Math.abs(x) > GRID_SIZE || Math.abs(y) > GRID_SIZE) {
    hoverPlacement = null;
    return;
  }

  const result = pickHoverPlacement(x, y);
  hoverPlacement = result;
};

const clearHoverPlacement = () => {
  hoverPlacement = null;
};

const handleCanvasClick = () => {
  if (!hoverPlacement || !hoverPlacement.isValid) {
    return;
  }
  if (placeBtn && placeBtn.disabled) {
    return;
  }
  audioManager.unlock();
  send({
    type: "place_block",
    user_id: userId,
    data: hoverPlacement.placement,
  });
};

const calculatePlacement = () => {
  const occupied = buildOccupied();
  const supportedPlacement = findSupportedPlacement(occupied);
  const placement = supportedPlacement ?? findBasePlacement(occupied);

  return {
    x: placement.x,
    y: placement.y,
    z: placement.z,
    type: currentBlockType,
  };
};

const lockButtons = () => {
  const mineBtn = document.getElementById("btn-mine");
  const debugClearBtn = document.getElementById("btn-debug-clear");
  const muteBtn = document.getElementById("btn-mute");

  if (muteBtn) {
    muteBtn.addEventListener("click", () => {
      const isMuted = audioManager.toggleMute();
      muteBtn.textContent = isMuted ? "🔇 Sound Off" : "🔊 Sound On";
    });
  }

  if (mineBtn) {
    mineBtn.addEventListener("click", () => {
      flashButton(mineBtn);
      audioManager.playSound("mine");
      send({ type: "mine_stone", user_id: userId });
    });
  }

  if (placeBtn) {
    placeBtn.addEventListener("click", () => {
      if (placeBtn.disabled) {
        return;
      }
      flashButton(placeBtn);
      audioManager.unlock();
      send({ type: "place_block", user_id: userId, data: calculatePlacement() });
    });
  }

  if (debugClearBtn) {
    debugClearBtn.addEventListener("click", () => {
      if (
        !confirm(
          "Are you sure you want to clear the entire pyramid? This cannot be undone.",
        )
      ) {
        return;
      }
      send({ type: "debug_clear_all", user_id: userId });
    });
  }
};

const socket = connect({
  onStatusChange: setStatus,
  onMilestone: (data) => {
    showMilestoneNotification(data);
  },
  onError: (message) => {
    flashError();
    showErrorNotice(message);
  },
  userId: userId,
});
lockButtons();
initBlockTypeSelector();
initChatPanel();
initTutorialOverlay();
renderLeaderboard([]);

if (socket) {
  socket.addEventListener("message", handleSocketMessage);
}

if (canvas) {
  canvas.addEventListener("mousemove", updateHoverFromEvent);
  canvas.addEventListener("mouseleave", clearHoverPlacement);
  canvas.addEventListener("click", handleCanvasClick);
}

const frame = () => {
  draw();
  if (hoverPlacement) {
    renderGhostBlock(
      hoverPlacement.placement.x,
      hoverPlacement.placement.y,
      hoverPlacement.placement.z,
      hoverPlacement.isValid,
      hoverPlacement.placement.type,
    );
  }
  updateHud();
  requestAnimationFrame(frame);
};

requestAnimationFrame(frame);
