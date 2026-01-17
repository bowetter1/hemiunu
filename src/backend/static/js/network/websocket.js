import gameState from "../state/gameState.js";

let socket = null;
let statusHandler = () => {};
let milestoneHandler = () => {};

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

const overrideState = (data) => {
  if (!data) {
    return;
  }

  const { pyramid, stats, user_resources } = data;

  gameState.pyramid.length = 0;
  if (Array.isArray(pyramid)) {
    gameState.pyramid.push(...pyramid);
  }

  gameState.stats = stats ? { ...stats } : {};
  gameState.resources = user_resources ? { ...user_resources } : {};
};

const addBlock = (block) => {
  if (!block || typeof block !== "object") {
    return;
  }
  gameState.pyramid.push(block);
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
    case "block_placed":
      addBlock(message.data);
      break;
    case "milestone-event":
      updateMilestone(message.data);
      break;
    default:
      break;
  }
};

export const connect = ({ onStatusChange, onMilestone } = {}) => {
  statusHandler = typeof onStatusChange === "function" ? onStatusChange : () => {};
  milestoneHandler = typeof onMilestone === "function" ? onMilestone : () => {};
  updateStatus("Connecting...");

  const scheme = window.location.protocol === "https:" ? "wss://" : "ws://";
  const host = window.location.host;
  const socketUrl = `${scheme}${host}/ws`;

  socket = new WebSocket(socketUrl);
  socket.addEventListener("open", () => updateStatus("Connected"));
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
