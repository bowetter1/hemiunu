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

const blockStyles = {
  granite: {
    fill: "#7f7f7f",
    stroke: "#1f1f1f",
    lineWidth: 1.6,
    pattern: "speckle",
  },
  limestone: {
    fill: "#d4c29d",
    stroke: "#8a7c5c",
    lineWidth: 1,
    pattern: "layers",
  },
  sandstone: {
    fill: "#c2803c",
    stroke: "#6f3f1b",
    lineWidth: 1.3,
    dash: [4, 2],
    pattern: "strata",
  },
};
const DEFAULT_BLOCK_STYLE = blockStyles.limestone;

const GRID_SIZE = 10;
const ANIM_DURATION = 400;
const OWN_HIGHLIGHT_DURATION = 1500;
const ERROR_FLASH_DURATION = 300;

let errorFlashStart = 0;

const easeOut = (t) => 1 - Math.pow(1 - t, 3);

const getBlockStyle = (type) => blockStyles[type] ?? DEFAULT_BLOCK_STYLE;

const hexToRgba = (hex, alpha) => {
  if (typeof hex !== "string") {
    return `rgba(159, 168, 176, ${alpha})`;
  }
  const normalized = hex.startsWith("#") ? hex.slice(1) : hex;
  const value =
    normalized.length === 3
      ? normalized
          .split("")
          .map((char) => char + char)
          .join("")
      : normalized;
  if (value.length !== 6) {
    return `rgba(159, 168, 176, ${alpha})`;
  }
  const r = Number.parseInt(value.slice(0, 2), 16);
  const g = Number.parseInt(value.slice(2, 4), 16);
  const b = Number.parseInt(value.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

const drawBlockDiamondPath = (ctx, isoX, isoY, half) => {
  ctx.beginPath();
  ctx.moveTo(isoX, isoY - half);
  ctx.lineTo(isoX + half, isoY);
  ctx.lineTo(isoX, isoY + half);
  ctx.lineTo(isoX - half, isoY);
  ctx.closePath();
};

const seededRandom = (seed) => {
  const value = Math.sin(seed) * 10000;
  return value - Math.floor(value);
};

const drawBlockPattern = (ctx, isoX, isoY, half, style, seed) => {
  if (!style.pattern) {
    return;
  }
  ctx.save();
  drawBlockDiamondPath(ctx, isoX, isoY, half);
  ctx.clip();

  switch (style.pattern) {
    case "speckle": {
      const dotRadius = Math.max(0.6, half * 0.05);
      ctx.fillStyle = "rgba(20, 20, 20, 0.35)";
      for (let i = 0; i < 7; i += 1) {
        const randX = seededRandom(seed + i * 11.17);
        const randY = seededRandom(seed + i * 23.71);
        const px = isoX - half + randX * half * 2;
        const py = isoY - half + randY * half * 2;
        ctx.beginPath();
        ctx.arc(px, py, dotRadius, 0, Math.PI * 2);
        ctx.fill();
      }
      break;
    }
    case "layers": {
      ctx.strokeStyle = "rgba(255, 255, 255, 0.18)";
      ctx.lineWidth = Math.max(0.6, half * 0.04);
      const gap = half * 0.35;
      for (let offset = -half; offset <= half; offset += gap) {
        ctx.beginPath();
        ctx.moveTo(isoX - half, isoY + offset);
        ctx.lineTo(isoX + half, isoY + offset);
        ctx.stroke();
      }
      break;
    }
    case "strata": {
      ctx.strokeStyle = "rgba(255, 225, 185, 0.25)";
      ctx.lineWidth = Math.max(0.6, half * 0.05);
      const gap = half * 0.4;
      for (let offset = -half; offset <= half; offset += gap) {
        ctx.beginPath();
        ctx.moveTo(isoX - half, isoY + half + offset);
        ctx.lineTo(isoX + half, isoY - half + offset);
        ctx.stroke();
      }
      break;
    }
    default:
      break;
  }

  ctx.restore();
};

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

    const style = getBlockStyle(type);
    const seed = x * 12.9898 + y * 78.233 + z * 37.719;

    ctx.save();
    ctx.fillStyle = style.fill;
    ctx.strokeStyle = style.stroke;
    ctx.lineWidth = style.lineWidth ?? 1;
    if (style.dash) {
      ctx.setLineDash(style.dash);
    }
    drawBlockDiamondPath(ctx, isoX, isoY, half);
    ctx.fill();
    ctx.stroke();
    ctx.setLineDash([]);
    drawBlockPattern(ctx, isoX, isoY, half, style, seed);
    ctx.restore();

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

export const renderGhostBlock = (x, y, z, isValid, type) => {
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
  const style = getBlockStyle(type);
  const fillColor = isValid
    ? hexToRgba(style.fill, 0.45)
    : "rgba(200, 70, 70, 0.35)";
  const strokeColor = isValid
    ? hexToRgba(style.stroke, 0.9)
    : "rgba(170, 60, 60, 0.9)";

  if (isValid && style.dash) {
    ctx.setLineDash(style.dash);
  }
  drawBlockDiamondPath(ctx, isoX, isoY, half);
  ctx.fillStyle = fillColor;
  ctx.strokeStyle = strokeColor;
  ctx.lineWidth = 1;
  ctx.fill();
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.restore();
};
