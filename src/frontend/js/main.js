import gameState from "./state/gameState.js";
import { connect, send } from "./network/websocket.js";
import { draw, animateNewBlock } from "./rendering/canvas.js";

const blockCountEl = document.getElementById("block-count");
const stoneCountEl = document.getElementById("stone-count");
const playerCountEl = document.getElementById("player-count");
const statusBar = document.getElementById("status-bar");
const milestoneProgressEl = document.getElementById("milestone-progress");
const milestoneNoticeEl = document.getElementById("milestone-notification");

const USER_ID_KEY = "hemiunu-user-id";
const MILESTONE_INTERVAL = 100;

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

const setStatus = (value) => {
  if (statusBar) {
    statusBar.textContent = value;
  }
};

let milestoneTimer = null;

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

const flashButton = (button) => {
  if (!button) return;
  button.style.transform = "scale(0.95)";
  button.style.boxShadow = "0 0 15px rgba(212, 160, 23, 0.6)";
  setTimeout(() => {
    button.style.transform = "";
    button.style.boxShadow = "";
  }, 150);
};

const calculatePlacement = () => {
  const maxHeight =
    gameState.pyramid.reduce((currentMax, block) => {
      const y = block && typeof block.y === "number" ? block.y : 0;
      return Math.max(currentMax, y);
    }, -1) + 1;

  return {
    x: 0,
    y: Math.max(0, maxHeight),
    z: 0,
    type: "granite",
  };
};

const lockButtons = () => {
  const mineBtn = document.getElementById("btn-mine");
  if (mineBtn) {
    mineBtn.addEventListener("click", () => {
      flashButton(mineBtn);
      send({ type: "mine_stone", user_id: userId });
    });
  }

  const placeBtn = document.getElementById("btn-place");
  if (placeBtn) {
    placeBtn.addEventListener("click", () => {
      flashButton(placeBtn);
      send({ type: "place_block", user_id: userId, data: calculatePlacement() });
    });
  }
};

connect({
  onStatusChange: setStatus,
  onMilestone: showMilestoneNotification,
  userId: userId,
});
lockButtons();

const frame = () => {
  draw();
  updateHud();
  requestAnimationFrame(frame);
};

requestAnimationFrame(frame);
