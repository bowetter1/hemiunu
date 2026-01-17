import gameState from "../state/gameState.js";

const canvas = document.getElementById("game-canvas");
const ctx = canvas?.getContext("2d");

const DAY_CYCLE_DURATION = 60000; // 60 seconds
const SKY_DAY_TOP = [135, 206, 235];
const SKY_DAY_BOTTOM = [255, 255, 255];
const SKY_NIGHT_TOP = [10, 10, 40];
const SKY_NIGHT_BOTTOM = [20, 20, 60];

const lerpColor = (c1, c2, t) => c1.map((v, i) => Math.round(v + (c2[i] - v) * t));
const rgb = (arr) => `rgb(${arr.join(",")})`;

const getCycleFactor = () => {
  const now = Date.now();
  const progress = (now % DAY_CYCLE_DURATION) / DAY_CYCLE_DURATION;
  // 0 = Night, 1 = Day. Using cosine to oscillate.
  return (Math.cos(progress * Math.PI * 2) * -1 + 1) / 2;
};

const colorMap = {
  granite: "#7f7f7f",
  limestone: "#d4c29d",
  sandstone: "#c2803c",
};

const GRID_SIZE = 10;
const ANIM_DURATION = 400;
const OWN_HIGHLIGHT_DURATION = 1500;
const ERROR_FLASH_DURATION = 300;

let errorFlashStart = 0;

const easeOut = (t) => 1 - Math.pow(1 - t, 3);

export const animateNewBlock = (index, isOwn = false) => {
  gameState.blockAnimations.set(index, {
    startTime: Date.now(),
    duration: isOwn ? OWN_HIGHLIGHT_DURATION : ANIM_DURATION,
    isOwn,
  });
};

export const flashError = () => {
  errorFlashStart = Date.now();
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

const getSceneMetrics = () => {
  if (!canvas) {
    return null;
  }
  const displayWidth = canvas.clientWidth;
  const displayHeight = canvas.clientHeight;
  const blockSize = Math.max(20, Math.min(displayWidth, displayHeight) / 15);
  return {
    displayWidth,
    displayHeight,
    blockSize,
    centerX: displayWidth / 2,
    baseY: displayHeight - blockSize,
  };
};

const drawGrid = (ctx, centerX, baseY, blockSize) => {
  ctx.save();
  ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
  ctx.lineWidth = 1;

  ctx.beginPath();
  // Draw X lines
  for (let y = -GRID_SIZE; y <= GRID_SIZE; y++) {
    const x1 = -GRID_SIZE;
    const x2 = GRID_SIZE;

    const isoX1 = centerX + (x1 - y) * blockSize * 0.6;
    const isoY1 = baseY - (x1 + y) * blockSize * 0.2;
    const isoX2 = centerX + (x2 - y) * blockSize * 0.6;
    const isoY2 = baseY - (x2 + y) * blockSize * 0.2;

    ctx.moveTo(isoX1, isoY1);
    ctx.lineTo(isoX2, isoY2);
  }

  // Draw Y lines
  for (let x = -GRID_SIZE; x <= GRID_SIZE; x++) {
    const y1 = -GRID_SIZE;
    const y2 = GRID_SIZE;

    const isoX1 = centerX + (x - y1) * blockSize * 0.6;
    const isoY1 = baseY - (x + y1) * blockSize * 0.2;
    const isoX2 = centerX + (x - y2) * blockSize * 0.6;
    const isoY2 = baseY - (x + y2) * blockSize * 0.2;

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
  const metrics = getSceneMetrics();
  if (!metrics) {
    return;
  }
  const { displayWidth, displayHeight, blockSize, centerX, baseY } = metrics;
  
  // Day/Night Cycle Background
  const cycleFactor = getCycleFactor(); // 0 (Night) to 1 (Day)
  const bgTop = lerpColor(SKY_NIGHT_TOP, SKY_DAY_TOP, cycleFactor);
  const bgBottom = lerpColor(SKY_NIGHT_BOTTOM, SKY_DAY_BOTTOM, cycleFactor);
  
  const bgGrad = ctx.createLinearGradient(0, 0, 0, displayHeight);
  bgGrad.addColorStop(0, rgb(bgTop));
  bgGrad.addColorStop(1, rgb(bgBottom));
  
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, displayWidth, displayHeight);

  // Apply brightness filter for scene elements
  // Brightness: 0.5 (Night) to 1.0 (Day)
  const brightness = 0.5 + 0.5 * cycleFactor;
  ctx.filter = `brightness(${brightness})`;

  drawGrid(ctx, centerX, baseY, blockSize);
  drawPyramidShadow(ctx, centerX, baseY, blockSize);

  const now = Date.now();
  for (const [index, animation] of gameState.blockAnimations) {
    if (now - animation.startTime >= animation.duration) {
      gameState.blockAnimations.delete(index);
    }
  }

  gameState.pyramid.forEach((block, index) => {
    if (typeof block !== "object" || block === null) {
      return;
    }
    const { x = 0, y = 0, z = 0, type } = block;
    const isoX = centerX + (x - y) * blockSize * 0.6;
    const isoY = baseY - z * blockSize * 0.7 - (x + y) * blockSize * 0.2;

    const animation = gameState.blockAnimations.get(index);
    let scale = 1;
    let alpha = 1;
    let hasAnimation = false;

    if (animation) {
      const elapsed = now - animation.startTime;
      const progress = Math.min(elapsed / animation.duration, 1);
      const eased = easeOut(progress);
      const startScale = animation.isOwn ? 0.85 : 0.7;
      const startAlpha = animation.isOwn ? 0.6 : 0.35;
      scale = startScale + (1 - startScale) * eased;
      alpha = startAlpha + (1 - startAlpha) * eased;
      hasAnimation = true;
    }

    if (hasAnimation) {
      ctx.save();
      ctx.globalAlpha = Math.min(1, Math.max(0, alpha));
    }

    const half = (blockSize / 2) * scale;

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

    if (hasAnimation) {
      ctx.restore();
    }
  });

  // Reset filter before UI/Overlays
  ctx.filter = "none";

  const elapsed = errorFlashStart ? Date.now() - errorFlashStart : 0;
  if (elapsed > 0 && elapsed <= ERROR_FLASH_DURATION) {
    const alpha = 0.35 * (1 - elapsed / ERROR_FLASH_DURATION);
    ctx.save();
    ctx.fillStyle = `rgba(200, 30, 30, ${alpha})`;
    ctx.fillRect(0, 0, displayWidth, displayHeight);
    ctx.restore();
  } else if (elapsed > ERROR_FLASH_DURATION) {
    errorFlashStart = 0;
  }
};

export const getValidPlacements = (blocks) => {
  const valid = [];
  const occupied = new Set();
  let maxHeight = 0;

  if (Array.isArray(blocks)) {
    blocks.forEach((block) => {
      if (!block || typeof block !== "object") {
        return;
      }
      const { x, y, z } = block;
      if (
        typeof x !== "number" ||
        typeof y !== "number" ||
        typeof z !== "number"
      ) {
        return;
      }
      occupied.add(`${x},${y},${z}`);
      maxHeight = Math.max(maxHeight, z);
    });
  }

  const heightLimit = Math.max(0, maxHeight + 1);

  for (let x = -GRID_SIZE; x <= GRID_SIZE; x++) {
    for (let y = -GRID_SIZE; y <= GRID_SIZE; y++) {
      const baseKey = `${x},${y},0`;
      if (!occupied.has(baseKey)) {
        valid.push({ x, y, z: 0 });
      }
      for (let z = 1; z <= heightLimit; z++) {
        const key = `${x},${y},${z}`;
        if (occupied.has(key)) {
          continue;
        }
        const supports = [
          `${x - 1},${y - 1},${z - 1}`,
          `${x - 1},${y + 1},${z - 1}`,
          `${x + 1},${y - 1},${z - 1}`,
          `${x + 1},${y + 1},${z - 1}`,
        ];
        if (supports.every((support) => occupied.has(support))) {
          valid.push({ x, y, z });
        }
      }
    }
  }

  return valid;
};

export const renderGhostBlock = (x, y, z, isValid) => {
  if (!canvas || !ctx) {
    return;
  }
  const metrics = getSceneMetrics();
  if (!metrics) {
    return;
  }
  const { blockSize, centerX, baseY } = metrics;
  const isoX = centerX + (x - y) * blockSize * 0.6;
  const isoY = baseY - z * blockSize * 0.7 - (x + y) * blockSize * 0.2;
  const half = blockSize / 2;

  ctx.save();
  ctx.beginPath();
  ctx.moveTo(isoX, isoY - half);
  ctx.lineTo(isoX + half, isoY);
  ctx.lineTo(isoX, isoY + half);
  ctx.lineTo(isoX - half, isoY);
  ctx.closePath();

  ctx.fillStyle = isValid ? "rgba(90, 190, 120, 0.45)" : "rgba(200, 70, 70, 0.35)";
  ctx.strokeStyle = isValid ? "rgba(80, 150, 100, 0.9)" : "rgba(170, 60, 60, 0.9)";
  ctx.lineWidth = 1;
  ctx.fill();
  ctx.stroke();
  ctx.restore();
};
