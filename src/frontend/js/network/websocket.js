import gameState from "../state/gameState.js";
import { animateNewBlock } from "../rendering/canvas.js";
import audioManager from "../audio/audioManager.js";

let socket = null;
let statusHandler = () => {};
let milestoneHandler = () => {};
let errorHandler = () => {};
let currentUserId = null;

const updateStatus = (value) => {
  if (typeof statusHandler === "function") {
    statusHandler(value);
  }
};

const updateMilestone = (data) => {
  if (typeof milestoneHandler === "function") {
    milestoneHandler(data);
  }
};

const showError = (message) => {
  const normalized =
    typeof message === "string" && message.trim() ? message.trim() : null;
  const statusText = normalized ? `Fel: ${normalized}` : "Fel";
  updateStatus(statusText);
  audioManager.playSound("error");
  if (typeof errorHandler === "function") {
    errorHandler(normalized);
  }
  if (socket && socket.readyState === WebSocket.OPEN) {
    window.setTimeout(() => {
      if (socket && socket.readyState === WebSocket.OPEN) {
        updateStatus("Connected");
      }
    }, 2500);
  }
};

const overrideState = (data) => {
  if (!data) {
    return;
  }

  const { pyramid, stats, user_resources, achievements, achievements_meta } = data;

  gameState.pyramid.length = 0;
  if (Array.isArray(pyramid)) {
    gameState.pyramid.push(...pyramid);
  }

  gameState.stats = stats ? { ...stats } : {};
  gameState.resources = user_resources ? { ...user_resources } : {};
  if (Array.isArray(achievements)) {
    gameState.achievements = achievements;
  }
  if (Array.isArray(achievements_meta)) {
    gameState.achievementsMeta = achievements_meta;
  }
};

const addBlock = (block) => {
  if (!block || typeof block !== "object") {
    return;
  }
  gameState.pyramid.push(block);
  return gameState.pyramid.length - 1;
};

const handleMessage = (event) => {
  let message;
  try {
    message = JSON.parse(event.data);
  } catch {
    return;
  }

  switch (message.type) {
    case "state_sync":
      overrideState(message.data);
      break;
    case "resource_update":
      // Update only the resources (specifically stone count) without full state sync
      if (message.data && typeof message.data === "object") {
        if (!gameState.resources) gameState.resources = {};
        if (typeof message.data.stone !== "undefined") {
          gameState.resources.stone = message.data.stone;
        }
      }
      break;
    case "block_placed":
      {
        const { block, total_blocks } = message.data || {};
        const index = addBlock(block);

        if (typeof total_blocks === "number") {
             if (!gameState.stats) gameState.stats = {};
             gameState.stats.total_blocks = total_blocks;
        }

        if (typeof index === "number") {
          const isOwn =
            currentUserId &&
            block?.user_id &&
            block.user_id === currentUserId;

          if (isOwn) {
            if (!gameState.resources) gameState.resources = {};
            if (typeof gameState.resources.stone === "number") {
              gameState.resources.stone -= 1;
            }
          }

          animateNewBlock(index, isOwn);
          audioManager.playSound("place");
        }
      }
      break;
    case "milestone-event":
      audioManager.playSound("milestone");
      updateMilestone(message.data);
      break;
    case "error":
      showError(message?.data?.message);
      break;
    default:
      break;
  }
};

export const connect = ({ onStatusChange, onMilestone, onError, userId } = {}) => {
  statusHandler = typeof onStatusChange === "function" ? onStatusChange : () => {};
  milestoneHandler = typeof onMilestone === "function" ? onMilestone : () => {};
  errorHandler = typeof onError === "function" ? onError : () => {};
  updateStatus("Connecting...");
  currentUserId = userId ?? null;

  const scheme = window.location.protocol === "https:" ? "wss://" : "ws://";
  const host = window.location.host;
  const socketUrl = `${scheme}${host}/ws`;

  socket = new WebSocket(socketUrl);
  socket.addEventListener("open", () => {
    updateStatus("Connected");
    if (userId) {
      socket.send(JSON.stringify({ type: "init", user_id: userId }));
    }
  });
  socket.addEventListener("message", handleMessage);
  socket.addEventListener("close", () => updateStatus("Disconnected"));
  socket.addEventListener("error", () => updateStatus("Connection error"));

  return socket;
};

export const send = (payload) => {
  if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(payload));
  }
};
