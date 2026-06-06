/* ========================================
   InstaGrid Splitter - Interactive Crop Edition
   ======================================== */

const dropZone = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
const cropEditorSection = document.getElementById('cropEditorSection');
const controlsSection = document.getElementById('controlsSection');
const resultSection = document.getElementById('resultSection');

const cropCanvas = document.getElementById('cropCanvas');
const cropCtx = cropCanvas.getContext('2d');
const gridOverlay = document.getElementById('gridOverlay');
const tilesGrid = document.getElementById('tilesGrid');

const presetBtns = document.querySelectorAll('.preset-btn');
const customCols = document.getElementById('customCols');
const customRows = document.getElementById('customRows');
const applyCustomBtn = document.getElementById('applyCustom');

const targetRatioEl = document.getElementById('targetRatio');
const cellSizeEl = document.getElementById('cellSize');
const paddingInfoEl = document.getElementById('paddingInfo');

const dlAllBtn = document.getElementById('dlAll');
const dlZipBtn = document.getElementById('dlZip');

const editorCanvas = document.getElementById('editorCanvas');
const editorCtx = editorCanvas.getContext('2d');
const cropFrame = document.getElementById('cropFrame');
const editorGridOverlay = document.getElementById('editorGridOverlay');
const zoomSlider = document.getElementById('zoomSlider');
const zoomValue = document.getElementById('zoomValue');
const fitBtn = document.getElementById('fitBtn');
const fillBtn = document.getElementById('fillBtn');
const confirmCrop = document.getElementById('confirmCrop');
const startCropBtn = document.getElementById('startCropBtn');
const previewWrapper = document.getElementById('previewWrapper');
const cropStartRow = document.getElementById('cropStartRow');

let originalImage = null;
let cols = 3;
let rows = 2;
let tileCanvases = [];
let tileOrderMap = [];

let editorScale = 1;
let editorOffsetX = 0;
let editorOffsetY = 0;
let cropParams = null;
let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let editorWrapW = 0;
let editorWrapH = 0;
let frameW = 0;
let frameH = 0;

/* ---------- Upload ---------- */
dropZone.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', (e) => handleFiles(e.target.files));

dropZone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropZone.classList.add('drag-over');
});
dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag-over'));
dropZone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropZone.classList.remove('drag-over');
  handleFiles(e.dataTransfer.files);
});

function handleFiles(files) {
  if (!files.length) return;
  const file = files[0];
  if (!file.type.startsWith('image/')) return alert('画像ファイルを選択してください');

  const reader = new FileReader();
  reader.onload = (e) => {
    const img = new Image();
    img.onload = () => {
      originalImage = img;
      controlsSection.classList.remove('hidden');
      cropParams = null;
      updateInfoPanel();
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

/* ---------- Interactive Crop Editor ---------- */
function getTargetRatio() {
  return (cols * 3) / (rows * 4);
}

function initCropEditor() {
  const wrap = document.getElementById('cropEditorWrap');
  const rect = wrap.getBoundingClientRect();
  editorWrapW = rect.width;
  editorWrapH = Math.min(500, window.innerHeight * 0.5);
  wrap.style.height = editorWrapH + 'px';

  const targetRatio = getTargetRatio();

  let fw, fh;
  if (editorWrapW / editorWrapH > targetRatio) {
    fh = editorWrapH * 0.85;
    fw = fh * targetRatio;
  } else {
    fw = editorWrapW * 0.85;
    fh = fw / targetRatio;
  }
  frameW = Math.round(fw);
  frameH = Math.round(fh);

  cropFrame.style.width = frameW + 'px';
  cropFrame.style.height = frameH + 'px';

  editorCanvas.width = editorWrapW;
  editorCanvas.height = editorWrapH;

  const imgRatio = originalImage.naturalWidth / originalImage.naturalHeight;
  let initialScale;
  if (imgRatio > targetRatio) {
    initialScale = frameH / originalImage.naturalHeight;
  } else {
    initialScale = frameW / originalImage.naturalWidth;
  }

  editorScale = initialScale;
  editorOffsetX = (editorWrapW - originalImage.naturalWidth * editorScale) / 2;
  editorOffsetY = (editorWrapH - originalImage.naturalHeight * editorScale) / 2;

  zoomSlider.value = Math.round(editorScale * 100);
  updateZoomLabel();
  drawEditorGrid();
  renderEditor();
}

function renderEditor() {
  if (!originalImage) return;
  editorCtx.clearRect(0, 0, editorWrapW, editorWrapH);

  const fx = (editorWrapW - frameW) / 2;
  const fy = (editorWrapH - frameH) / 2;

  // Fill the crop frame interior with black first (so gaps show as black)
  editorCtx.fillStyle = '#000000';
  editorCtx.fillRect(fx, fy, frameW, frameH);

  // Draw image on top
  const imgW = originalImage.naturalWidth * editorScale;
  const imgH = originalImage.naturalHeight * editorScale;
  editorCtx.drawImage(originalImage, 0, 0, originalImage.naturalWidth, originalImage.naturalHeight, editorOffsetX, editorOffsetY, imgW, imgH);

  // Darken outside the crop frame
  editorCtx.fillStyle = 'rgba(0,0,0,0.55)';
  editorCtx.fillRect(0, 0, editorWrapW, fy);
  editorCtx.fillRect(0, fy + frameH, editorWrapW, editorWrapH - fy - frameH);
  editorCtx.fillRect(0, fy, fx, frameH);
  editorCtx.fillRect(fx + frameW, fy, editorWrapW - fx - frameW, frameH);
}

function drawEditorGrid() {
  editorGridOverlay.innerHTML = '';
  for (let i = 1; i < cols; i++) {
    const line = document.createElement('div');
    line.className = 'editor-grid-line v';
    line.style.left = (100 / cols * i) + '%';
    editorGridOverlay.appendChild(line);
  }
  for (let i = 1; i < rows; i++) {
    const line = document.createElement('div');
    line.className = 'editor-grid-line h';
    line.style.top = (100 / rows * i) + '%';
    editorGridOverlay.appendChild(line);
  }
}

/* Editor interactions */
const editorWrap = document.getElementById('cropEditorWrap');

editorWrap.addEventListener('mousedown', (e) => {
  isDragging = true;
  dragStartX = e.clientX - editorOffsetX;
  dragStartY = e.clientY - editorOffsetY;
  editorWrap.style.cursor = 'grabbing';
});
window.addEventListener('mousemove', (e) => {
  if (!isDragging) return;
  editorOffsetX = e.clientX - dragStartX;
  editorOffsetY = e.clientY - dragStartY;
  renderEditor();
});
window.addEventListener('mouseup', () => {
  isDragging = false;
  editorWrap.style.cursor = 'grab';
});

editorWrap.addEventListener('touchstart', (e) => {
  if (e.touches.length !== 1) return;
  isDragging = true;
  dragStartX = e.touches[0].clientX - editorOffsetX;
  dragStartY = e.touches[0].clientY - editorOffsetY;
}, { passive: false });
window.addEventListener('touchmove', (e) => {
  if (!isDragging || e.touches.length !== 1) return;
  e.preventDefault();
  editorOffsetX = e.touches[0].clientX - dragStartX;
  editorOffsetY = e.touches[0].clientY - dragStartY;
  renderEditor();
}, { passive: false });
window.addEventListener('touchend', () => { isDragging = false; });

editorWrap.addEventListener('wheel', (e) => {
  e.preventDefault();
  const zoomFactor = e.deltaY < 0 ? 1.05 : 0.95;
  const newScale = Math.max(0.1, Math.min(5, editorScale * zoomFactor));

  const rect = editorWrap.getBoundingClientRect();
  const mouseX = e.clientX - rect.left;
  const mouseY = e.clientY - rect.top;

  editorOffsetX = mouseX - (mouseX - editorOffsetX) * (newScale / editorScale);
  editorOffsetY = mouseY - (mouseY - editorOffsetY) * (newScale / editorScale);
  editorScale = newScale;

  zoomSlider.value = Math.round(editorScale * 100);
  updateZoomLabel();
  renderEditor();
}, { passive: false });

zoomSlider.addEventListener('input', () => {
  const newScale = parseInt(zoomSlider.value) / 100;
  const cx = editorWrapW / 2;
  const cy = editorWrapH / 2;
  editorOffsetX = cx - (cx - editorOffsetX) * (newScale / editorScale);
  editorOffsetY = cy - (cy - editorOffsetY) * (newScale / editorScale);
  editorScale = newScale;
  updateZoomLabel();
  renderEditor();
});

function updateZoomLabel() {
  zoomValue.textContent = Math.round(editorScale * 100) + '%';
}

fitBtn.addEventListener('click', () => {
  const targetRatio = getTargetRatio();
  const imgRatio = originalImage.naturalWidth / originalImage.naturalHeight;
  editorScale = imgRatio > targetRatio ? frameH / originalImage.naturalHeight : frameW / originalImage.naturalWidth;
  editorOffsetX = (editorWrapW - originalImage.naturalWidth * editorScale) / 2;
  editorOffsetY = (editorWrapH - originalImage.naturalHeight * editorScale) / 2;
  zoomSlider.value = Math.round(editorScale * 100);
  updateZoomLabel();
  renderEditor();
});

fillBtn.addEventListener('click', () => {
  const targetRatio = getTargetRatio();
  const imgRatio = originalImage.naturalWidth / originalImage.naturalHeight;
  editorScale = imgRatio > targetRatio ? frameW / originalImage.naturalWidth : frameH / originalImage.naturalHeight;
  editorOffsetX = (editorWrapW - originalImage.naturalWidth * editorScale) / 2;
  editorOffsetY = (editorWrapH - originalImage.naturalHeight * editorScale) / 2;
  zoomSlider.value = Math.round(editorScale * 100);
  updateZoomLabel();
  renderEditor();
});

startCropBtn.addEventListener('click', () => {
  cropEditorSection.classList.remove('hidden');
  initCropEditor();
  cropEditorSection.scrollIntoView({ behavior: 'smooth' });
});

confirmCrop.addEventListener('click', () => {
  const fx = (editorWrapW - frameW) / 2;
  const fy = (editorWrapH - frameH) / 2;

  const srcX = (fx - editorOffsetX) / editorScale;
  const srcY = (fy - editorOffsetY) / editorScale;
  const srcW = frameW / editorScale;
  const srcH = frameH / editorScale;

  // Keep exact frame ratio — do NOT clamp to image bounds here.
  // generateTiles will fill out-of-bounds areas with black.
  cropParams = { srcX, srcY, srcW, srcH };

  cropStartRow.classList.add('hidden');
  previewWrapper.classList.remove('hidden');
  resultSection.classList.remove('hidden');
  updatePreview();
  generateTiles();
  resultSection.scrollIntoView({ behavior: 'smooth' });
});

/* ---------- Grid Controls ---------- */
presetBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    presetBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    cols = parseInt(btn.dataset.cols);
    rows = parseInt(btn.dataset.rows);
    customCols.value = cols;
    customRows.value = rows;
    if (originalImage) {
      cropParams = null;
      cropEditorSection.classList.add('hidden');
      previewWrapper.classList.add('hidden');
      cropStartRow.classList.remove('hidden');
      resultSection.classList.add('hidden');
      updateInfoPanel();
    }
  });
});

applyCustomBtn.addEventListener('click', () => {
  cols = Math.max(1, Math.min(10, parseInt(customCols.value) || 1));
  rows = Math.max(1, Math.min(10, parseInt(customRows.value) || 1));
  customCols.value = cols;
  customRows.value = rows;
  presetBtns.forEach(b => b.classList.remove('active'));
  if (originalImage) {
    cropParams = null;
    cropEditorSection.classList.add('hidden');
    previewWrapper.classList.add('hidden');
    cropStartRow.classList.remove('hidden');
    resultSection.classList.add('hidden');
    updateInfoPanel();
  }
});

/* ---------- Info Panel ---------- */
function updateInfoPanel() {
  const targetW = cols * 3;
  const targetH = rows * 4;
  targetRatioEl.textContent = `${targetW} : ${targetH}`;
  cellSizeEl.textContent = '4 : 5';
  paddingInfoEl.textContent = '左右 3.125%ずつ（グリッドではカット）';
}

/* ---------- Preview & Info ---------- */
function updatePreview() {
  if (!originalImage) return;

  const targetW = cols * 3;
  const targetH = rows * 4;
  cellSizeEl.textContent = '4 : 5';
  paddingInfoEl.textContent = '左右 3.125%ずつ（グリッドではカット）';

  let cropW, cropH, offsetX, offsetY;
  if (cropParams) {
    cropW = cropParams.srcW;
    cropH = cropParams.srcH;
    offsetX = cropParams.srcX;
    offsetY = cropParams.srcY;
  } else {
    const r = calcCrop(originalImage.naturalWidth, originalImage.naturalHeight, targetW, targetH);
    cropW = r.cropW; cropH = r.cropH; offsetX = r.offsetX; offsetY = r.offsetY;
  }

  // For preview, clamp to visible image bounds so we don't try to draw outside
  const drawOffsetX = Math.max(0, offsetX);
  const drawOffsetY = Math.max(0, offsetY);
  const drawW = Math.min(cropW, originalImage.naturalWidth - drawOffsetX);
  const drawH = Math.min(cropH, originalImage.naturalHeight - drawOffsetY);

  const maxW = Math.min(500, drawW);
  const scale = maxW / cropW;
  const previewW = maxW;
  const previewH = cropH * scale;

  cropCanvas.width = previewW;
  cropCanvas.height = previewH;
  cropCtx.clearRect(0, 0, previewW, previewH);
  cropCtx.drawImage(originalImage, drawOffsetX, drawOffsetY, drawW, drawH, 0, 0, previewW, previewH);

  gridOverlay.innerHTML = '';
  gridOverlay.style.width = previewW + 'px';
  gridOverlay.style.height = previewH + 'px';

  for (let i = 1; i < cols; i++) {
    const line = document.createElement('div');
    line.className = 'grid-line vertical';
    line.style.left = (previewW / cols * i) + 'px';
    gridOverlay.appendChild(line);
  }
  for (let i = 1; i < rows; i++) {
    const line = document.createElement('div');
    line.className = 'grid-line horizontal';
    line.style.top = (previewH / rows * i) + 'px';
    gridOverlay.appendChild(line);
  }
}

/* ---------- Core Math ---------- */
function calcCrop(origW, origH, targetW, targetH) {
  const origRatio = origW / origH;
  const targetRatio = targetW / targetH;

  let cropW, cropH, offsetX, offsetY;
  if (origRatio > targetRatio) {
    cropH = origH;
    cropW = origH * targetRatio;
    offsetX = (origW - cropW) / 2;
    offsetY = 0;
  } else {
    cropW = origW;
    cropH = origW / targetRatio;
    offsetX = 0;
    offsetY = (origH - cropH) / 2;
  }
  return { cropW, cropH, offsetX, offsetY };
}

/* ---------- Tile Generation ---------- */
function generateTiles() {
  if (!originalImage) return;
  tilesGrid.innerHTML = '';
  tileCanvases = [];
  tileOrderMap = [];

  let cropW, cropH, offsetX, offsetY;
  if (cropParams) {
    cropW = cropParams.srcW;
    cropH = cropParams.srcH;
    offsetX = cropParams.srcX;
    offsetY = cropParams.srcY;
  } else {
    const targetW = cols * 3;
    const targetH = rows * 4;
    const r = calcCrop(originalImage.naturalWidth, originalImage.naturalHeight, targetW, targetH);
    cropW = r.cropW; cropH = r.cropH; offsetX = r.offsetX; offsetY = r.offsetY;
  }

  const cellW = cropW / cols;
  const cellH = cropH / rows;

  const timelineW = cellH * 4 / 5;
  const outW = Math.round(timelineW);
  const outH = Math.round(cellH);
  const padding = Math.max(0, (timelineW - cellW) / 2);

  const imgLeft = 0;
  const imgTop = 0;
  const imgRight = originalImage.naturalWidth;
  const imgBottom = originalImage.naturalHeight;

  let order = 1;
  for (let r = rows - 1; r >= 0; r--) {
    for (let c = cols - 1; c >= 0; c--) {
      const cellSrcX = offsetX + c * cellW;
      const cellSrcY = offsetY + r * cellH;
      const cellSrcRight = cellSrcX + cellW;
      const cellSrcBottom = cellSrcY + cellH;

      const canvas = document.createElement('canvas');
      canvas.width = outW;
      canvas.height = outH;
      const ctx = canvas.getContext('2d');

      // Fill entire output with black first
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, outW, outH);

      // Calculate overlap between this cell and the actual image
      const overlapLeft = Math.max(cellSrcX, imgLeft);
      const overlapTop = Math.max(cellSrcY, imgTop);
      const overlapRight = Math.min(cellSrcRight, imgRight);
      const overlapBottom = Math.min(cellSrcBottom, imgBottom);

      const overlapW = overlapRight - overlapLeft;
      const overlapH = overlapBottom - overlapTop;

      if (overlapW > 0 && overlapH > 0) {
        // Where to place the overlapping portion inside the cell on the canvas
        const destX = padding + (overlapLeft - cellSrcX);
        const destY = overlapTop - cellSrcY;
        ctx.drawImage(
          originalImage,
          overlapLeft, overlapTop, overlapW, overlapH,
          destX, destY, overlapW, overlapH
        );
      }

      tileCanvases.push(canvas);
      tileOrderMap.push({ canvas, order, outW, outH, row: r, col: c });
      order++;
    }
  }

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const item = tileOrderMap.find(t => t.row === r && t.col === c);
      if (!item) continue;
      tilesGrid.appendChild(createTileCard(item));
    }
  }
}

function createTileCard(item) {
  const card = document.createElement('div');
  card.className = 'tile-card';

  const wrap = document.createElement('div');
  wrap.className = 'tile-canvas-wrap';

  const orderBadge = document.createElement('div');
  orderBadge.className = 'tile-order';
  orderBadge.textContent = `#${String(item.order).padStart(2, '0')}`;

  const safeLeft = document.createElement('div');
  safeLeft.className = 'safe-zone safe-left';
  const safeRight = document.createElement('div');
  safeRight.className = 'safe-zone safe-right';

  const meta = document.createElement('div');
  meta.className = 'tile-meta';

  const sizeText = document.createElement('span');
  sizeText.className = 'tile-size';
  sizeText.textContent = `${item.outW}x${item.outH}`;

  const dlBtn = document.createElement('button');
  dlBtn.className = 'tile-dl';
  dlBtn.textContent = '保存';
  dlBtn.addEventListener('click', () => downloadCanvas(item.canvas, `tile_${String(item.order).padStart(2, '0')}.png`));

  wrap.appendChild(item.canvas);
  wrap.appendChild(orderBadge);
  wrap.appendChild(safeLeft);
  wrap.appendChild(safeRight);
  meta.appendChild(sizeText);
  meta.appendChild(dlBtn);
  card.appendChild(wrap);
  card.appendChild(meta);
  return card;
}

/* ---------- Download ---------- */
function downloadCanvas(canvas, filename) {
  const link = document.createElement('a');
  link.download = filename;
  link.href = canvas.toDataURL('image/png');
  link.click();
}

dlAllBtn.addEventListener('click', () => {
  tileOrderMap.forEach(item => {
    downloadCanvas(item.canvas, `tile_${String(item.order).padStart(2, '0')}.png`);
  });
});

dlZipBtn.addEventListener('click', async () => {
  const zip = new JSZip();
  tileOrderMap.forEach(item => {
    const dataUrl = item.canvas.toDataURL('image/png');
    const base64 = dataUrl.split(',')[1];
    zip.file(`tile_${String(item.order).padStart(2, '0')}.png`, base64, { base64: true });
  });
  const blob = await zip.generateAsync({ type: 'blob' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'instagrid_tiles.zip';
  link.click();
  URL.revokeObjectURL(link.href);
});
