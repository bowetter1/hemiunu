import gameState from "../state/gameState.js";

const canvas = document.getElementById("game-canvas");
const ctx = canvas?.getContext("2d");

const colorMap = {
  granite: "#7f7f7f",
  limestone: "#d4c29d",
  sandstone: "#c2803c",
};

const ensureSize = () => {
  if (!canvas) {
    return;
  }
  const rect = canvas.getBoundingClientRect();
  const devicePixelRatio = window.devicePixelRatio || 1;
  canvas.width = rect.width * devicePixelRatio;
  canvas.height = rect.height * devicePixelRatio;
  ctx?.scale(devicePixelRatio, devicePixelRatio);
};

export const draw = () => {
  if (!canvas || !ctx) {
    return;
  }

  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ensureSize();
  const displayWidth = canvas.clientWidth;
  const displayHeight = canvas.clientHeight;
  ctx.clearRect(0, 0, displayWidth, displayHeight);

  const blockSize = Math.max(20, Math.min(displayWidth, displayHeight) / 15);
  const centerX = displayWidth / 2;
  const baseY = displayHeight - blockSize;

  gameState.pyramid.forEach((block) => {
    if (typeof block !== "object" || block === null) {
      return;
    }
    const { x = 0, y = 0, z = 0, type } = block;
    const isoX = centerX + (x - z) * blockSize * 0.6;
    const isoY = baseY - y * blockSize * 0.7 - (x + z) * blockSize * 0.2;

    const half = blockSize / 2;
    ctx.beginPath();
    ctx.moveTo(isoX, isoY - half);
    ctx.lineTo(isoX + half, isoY);
    ctx.lineTo(isoX, isoY + half);
    ctx.lineTo(isoX - half, isoY);
    ctx.closePath();

    ctx.fillStyle = colorMap[type] ?? "#9fa8b0";
    ctx.fill();
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 1;
    ctx.stroke();
  });
};
