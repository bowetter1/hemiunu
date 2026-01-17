import gameState from "./state/gameState.js";
import { connect, send } from "./network/websocket.js";
import { draw, flashError } from "./rendering/canvas.js";

const blockCountEl = document.getElementById("block-count");
const stoneCountEl = document.getElementById("stone-count");
const playerCountEl = document.getElementById("player-count");
const statusBar = document.getElementById("status-bar");
const milestoneProgressEl = document.getElementById("milestone-progress");
const milestoneNoticeEl = document.getElementById("milestone-notification");
const errorNoticeEl = document.getElementById("error-notification");
const placeWarningEl = document.getElementById("place-warning");
const placeBtn = document.getElementById("btn-place");

const USER_ID_KEY = "hemiunu-user-id";
const MILESTONE_INTERVAL = 100;
const ERROR_NOTICE_DURATION = 3000;

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
let errorNoticeTimer = null;

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
      send({ type: "mine_stone", user_id: userId });
    });
  }

  if (placeBtn) {
    placeBtn.addEventListener("click", () => {
      if (placeBtn.disabled) {
        return;
      }
      send({ type: "place_block", user_id: userId, data: calculatePlacement() });
    });
  }
};

connect({
  onStatusChange: setStatus,
  onMilestone: showMilestoneNotification,
  onError: (message) => {
    flashError();
    showErrorNotice(message);
  },
});
lockButtons();

const frame = () => {
  draw();
  updateHud();
  requestAnimationFrame(frame);
};

requestAnimationFrame(frame);
