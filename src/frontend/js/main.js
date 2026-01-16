import gameState from "./state/gameState.js";
import { connect, send } from "./network/websocket.js";
import { draw } from "./rendering/canvas.js";

const blockCountEl = document.getElementById("block-count");
const stoneCountEl = document.getElementById("stone-count");
const playerCountEl = document.getElementById("player-count");
const statusBar = document.getElementById("status-bar");

const USER_ID_KEY = "hemiunu-user-id";

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

const updateHud = () => {
  if (blockCountEl) {
    blockCountEl.textContent = gameState.stats?.total_blocks ?? 0;
  }
  if (stoneCountEl) {
    stoneCountEl.textContent = gameState.resources?.stone ?? 0;
  }
  if (playerCountEl) {
    playerCountEl.textContent = gameState.stats?.online_players ?? 0;
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

  const placeBtn = document.getElementById("btn-place");
  if (placeBtn) {
    placeBtn.addEventListener("click", () => {
      send({ type: "place_block", user_id: userId, data: calculatePlacement() });
    });
  }
};

connect({ onStatusChange: setStatus });
lockButtons();

const frame = () => {
  draw();
  updateHud();
  requestAnimationFrame(frame);
};

requestAnimationFrame(frame);
