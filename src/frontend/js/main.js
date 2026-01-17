import gameState from "./state/gameState.js";
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

const USER_ID_KEY = "hemiunu-user-id";
const MILESTONE_INTERVAL = 100;
const ERROR_NOTICE_DURATION = 3000;
const GRID_SIZE = 10;

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
let hoverPlacement = null;

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
    return { placement: { ...bestPlacement, type: "granite" }, isValid: true };
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
    placement: { x: gridX, y: gridY, z: candidateZ, type: "granite" },
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

  if (placeBtn) {
    placeBtn.addEventListener("click", () => {
      if (placeBtn.disabled) {
        return;
      }
      flashButton(placeBtn);
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
  userId: userId,
});
lockButtons();

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
    );
  }
  updateHud();
  requestAnimationFrame(frame);
};

requestAnimationFrame(frame);
