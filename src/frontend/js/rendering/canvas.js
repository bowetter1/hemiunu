import gameState from "../state/gameState.js";

const canvas = document.getElementById("game-canvas");
const ctx = canvas?.getContext("2d");

const colorMap = {
  granite: "#7f7f7f",
  limestone: "#d4c29d",
  sandstone: "#c2803c",
};

const ANIM_DURATION = 400;
const OWN_HIGHLIGHT_DURATION = 1500;

const easeOut = (t) => 1 - Math.pow(1 - t, 3);

export const animateNewBlock = (index, isOwn = false) => {
  gameState.blockAnimations.set(index, {
    startTime: Date.now(),
    duration: isOwn ? OWN_HIGHLIGHT_DURATION : ANIM_DURATION,
    isOwn,
  });
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

const drawGrid = (ctx, centerX, baseY, blockSize) => {
  ctx.save();
  ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
  ctx.lineWidth = 1;

  const gridSize = 10;

  ctx.beginPath();
  // Draw X lines
  for (let z = -gridSize; z <= gridSize; z++) {
    const x1 = -gridSize;
    const x2 = gridSize;

    const isoX1 = centerX + (x1 - z) * blockSize * 0.6;
    const isoY1 = baseY - (x1 + z) * blockSize * 0.2;
    const isoX2 = centerX + (x2 - z) * blockSize * 0.6;
    const isoY2 = baseY - (x2 + z) * blockSize * 0.2;

    ctx.moveTo(isoX1, isoY1);
    ctx.lineTo(isoX2, isoY2);
  }

  // Draw Z lines
  for (let x = -gridSize; x <= gridSize; x++) {
    const z1 = -gridSize;
    const z2 = gridSize;

    const isoX1 = centerX + (x - z1) * blockSize * 0.6;
    const isoY1 = baseY - (x + z1) * blockSize * 0.2;
    const isoX2 = centerX + (x - z2) * blockSize * 0.6;
    const isoY2 = baseY - (x + z2) * blockSize * 0.2;

    ctx.moveTo(isoX1, isoY1);
    ctx.lineTo(isoX2, isoY2);
  }
  ctx.stroke();
  ctx.restore();
};

const drawPyramidShadow = (ctx, centerX, baseY, blockSize) => {
  if (gameState.pyramid.length === 0) return;

  ctx.save();
  ctx.fillStyle = "rgba(0, 0, 0, 0.2)";
  ctx.translate(centerX, baseY);
  ctx.scale(1, 0.3);
  ctx.beginPath();
  ctx.arc(0, 0, blockSize * 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
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

  drawGrid(ctx, centerX, baseY, blockSize);
  drawPyramidShadow(ctx, centerX, baseY, blockSize);

  gameState.pyramid.forEach((block, index) => {
    if (typeof block !== "object" || block === null) {
      return;
    }
    const { x = 0, y = 0, z = 0, type } = block;
    const isoX = centerX + (x - z) * blockSize * 0.6;
    const isoY = baseY - y * blockSize * 0.7 - (x + z) * blockSize * 0.2;

    const half = blockSize / 2;

    // Glow effect for last placed block
    const isLast = index === gameState.pyramid.length - 1;
    if (isLast) {
      ctx.save();
      const pulse = (Math.sin(Date.now() / 200) + 1) / 2;
      ctx.shadowBlur = 15 + 15 * pulse;
      ctx.shadowColor = "rgba(255, 215, 0, 0.8)";
    }

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

    if (isLast) {
      ctx.restore();
    }
  });
};
