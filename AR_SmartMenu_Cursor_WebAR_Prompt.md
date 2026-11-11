# AR Smart Menu — WebAR Customer Browser Experience
# Cursor AI Prompt — Paste this entire file into Cursor Composer

---

## ROLE & GOAL

You are a senior frontend engineer specialising in WebAR and 3D web experiences.

Build the complete **WebAR customer browser experience** for AR Smart Menu — the page that opens when a customer scans a QR code at a restaurant table (or taps "View in AR" on Swiggy/Zomato).

**The customer experience must:**
- Open directly in the mobile browser — no app download
- Show a 3D model of the dish anchored on the real table surface via the phone camera
- Work on both Android (Chrome) and iPhone (Safari)
- Load fast (under 3 seconds on 4G)
- Allow the customer to rotate, scale, and move the 3D model
- Show dish info (name, price, description)
- Allow switching between other dishes from the same restaurant
- Have a "Add to order" button that links back to the restaurant's ordering system

---

## TECH STACK

- **Framework**: Vanilla HTML + CSS + JavaScript (no React — must be lightweight for mobile)
- **3D/AR library**: `@google/model-viewer` v3.4.0 (loaded via CDN)
- **HTTP calls**: `axios` (CDN) for fetching dish data from backend API
- **Styling**: Plain CSS (no Tailwind — keep bundle tiny)
- **Backend API**: REST API at `https://api.arsmartmenu.com` (already built separately)
- **3D model files**: `.glb` for Android/Web, `.usdz` for iPhone — served from AWS CloudFront CDN
- **Build tool**: None — pure static HTML files served from a CDN or simple Node.js static server

---

## PROJECT STRUCTURE

```
ar-webar/
├── public/
│   ├── dish.html               ← Main AR page (QR code links here)
│   ├── menu.html               ← Full restaurant menu in AR browser
│   ├── offline.html            ← Shown if network fails
│   └── assets/
│       ├── css/
│       │   ├── ar.css          ← Main styles
│       │   └── loading.css     ← Loading screen styles
│       ├── js/
│       │   ├── ar.js           ← Core AR logic
│       │   ├── api.js          ← Axios API calls
│       │   ├── ui.js           ← UI controls, dish switcher
│       │   └── analytics.js    ← Track scan/view events
│       └── icons/
│           ├── ar-icon.svg
│           └── logo.svg
├── server.js                   ← Simple Express static server
├── package.json
└── README.md
```

---

## PAGE 1 — `dish.html` (MAIN FILE — most important)

This is the page that opens when a customer scans the QR code.

### URL format:
```
https://ar.arsmartmenu.com/dish/{slug}
```
Example: `https://ar.arsmartmenu.com/dish/butter-chicken-x7k2`

### What this page does, step by step:

1. Page loads → show loading screen with spinner + business name
2. Extract `slug` from URL path
3. Call backend API `GET /api/public/ar/{slug}` to get:
   - Product: name, description, price, veg/non-veg status, calories
   - Business: business name, city
   - Model: `glbUrl`, `usdzUrl`
   - Other products: list of other live dishes from same restaurant (max 6)
4. Log scan event by calling `POST /api/public/ar/{slug}/view` with device info
5. Hide loading screen, show AR viewer
6. Detect if iPhone or Android → load correct model format
7. Show dish info card (name, price, veg badge)
8. Show bottom controls (Rotate / Add to order / Share)
9. Show horizontal scroll strip of other dishes below the AR viewer

### Full HTML structure:

```html
<!DOCTYPE html>
<html lang="hi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <meta name="theme-color" content="#000000">
  <title>AR Menu — Loading...</title>

  <!-- model-viewer — must load before page renders -->
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.4.0/model-viewer.min.js"></script>

  <!-- axios for API calls -->
  <script src="https://cdn.jsdelivr.net/npm/axios@1.6.5/dist/axios.min.js"></script>

  <link rel="stylesheet" href="/assets/css/ar.css">
  <link rel="stylesheet" href="/assets/css/loading.css">
</head>
<body>

  <!-- LOADING SCREEN: shown while fetching dish data -->
  <div id="loading-screen">
    <div class="loading-logo">
      <img src="/assets/icons/logo.svg" alt="AR Smart Menu" width="80">
    </div>
    <div class="loading-spinner"></div>
    <p class="loading-text" id="loading-text">Loading your dish...</p>
  </div>

  <!-- ERROR SCREEN: shown if API call fails -->
  <div id="error-screen" style="display:none">
    <div class="error-icon">⚠️</div>
    <h2 class="error-title">Kuch problem aayi</h2>
    <p class="error-sub" id="error-message">Dish load nahi ho saki. Please try again.</p>
    <button class="btn-retry" onclick="window.location.reload()">Dobara try karein</button>
  </div>

  <!-- MAIN AR CONTAINER: hidden until data loads -->
  <div id="ar-container" style="display:none">

    <!-- model-viewer: the core AR element -->
    <model-viewer
      id="model-viewer"
      ar
      ar-modes="webxr scene-viewer quick-look"
      ar-scale="fixed"
      camera-controls
      auto-rotate
      auto-rotate-delay="0"
      rotation-per-second="30deg"
      shadow-intensity="1"
      shadow-softness="0.8"
      exposure="1.2"
      environment-image="neutral"
      loading="eager"
      reveal="auto"
      style="width:100vw; height:100vh; background:#1a1a1a"
      alt="3D dish preview">

      <!-- AR button: shown only when AR is available on device -->
      <button slot="ar-button" id="ar-button" class="ar-button" aria-label="View on your table in AR">
        <img src="/assets/icons/ar-icon.svg" width="22" height="22" alt="" aria-hidden="true">
        <span>Table par dekho</span>
      </button>

      <!-- AR prompt overlay: shown inside the AR session -->
      <div slot="ar-prompt" class="ar-prompt">
        <p>Phone ko table ke upar ghoomao</p>
      </div>

    </model-viewer>

    <!-- DISH INFO CARD: top overlay showing name, price -->
    <div id="dish-info-card" class="dish-info-card">
      <div class="dish-info-left">
        <div class="veg-badge" id="veg-badge">
          <!-- Green square for veg, red for non-veg -->
        </div>
        <div class="dish-info-text">
          <h1 id="dish-name" class="dish-name">Loading...</h1>
          <p id="dish-meta" class="dish-meta">...</p>
        </div>
      </div>
      <div id="dish-price" class="dish-price">₹—</div>
    </div>

    <!-- SIZE BADGE: bottom-right, tap to cycle sizes -->
    <button id="size-btn" class="size-btn" onclick="cycleSize()" aria-label="Change model size">
      <span id="size-label">Actual size</span>
    </button>

    <!-- BOTTOM CONTROLS -->
    <div class="bottom-controls">
      <button class="ctrl-btn ctrl-btn-secondary" onclick="rotateModel()" aria-label="Rotate model">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
        </svg>
        <span>Rotate</span>
      </button>

      <button class="ctrl-btn ctrl-btn-primary" id="order-btn" onclick="handleOrder()" aria-label="Add to order">
        <span>Add to order</span>
      </button>

      <button class="ctrl-btn ctrl-btn-secondary" onclick="handleShare()" aria-label="Share this dish">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/>
          <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
        </svg>
        <span>Share</span>
      </button>
    </div>

    <!-- OTHER DISHES STRIP: horizontal scroll below controls -->
    <div class="other-dishes-section">
      <p class="other-dishes-label" id="restaurant-name">Restaurant name</p>
      <div class="other-dishes-strip" id="other-dishes-strip">
        <!-- Dish cards injected by JS -->
      </div>
    </div>

    <!-- LOADING PROGRESS: shown inside model-viewer while GLB downloads -->
    <div id="model-loading" class="model-loading" style="display:none">
      <div class="model-loading-bar">
        <div class="model-loading-fill" id="loading-fill"></div>
      </div>
      <p class="model-loading-text" id="model-loading-text">3D model load ho raha hai...</p>
    </div>

  </div><!-- end #ar-container -->

  <script src="/assets/js/api.js"></script>
  <script src="/assets/js/analytics.js"></script>
  <script src="/assets/js/ui.js"></script>
  <script src="/assets/js/ar.js"></script>
</body>
</html>
```

---

## CSS — `ar.css`

```css
/* Reset */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 100%; height: 100%; overflow: hidden; background: #111; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; -webkit-tap-highlight-color: transparent; }

/* ─── Dish info card (top overlay) ─── */
.dish-info-card {
  position: fixed;
  top: 16px; left: 12px; right: 12px;
  background: rgba(0,0,0,0.72);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-radius: 16px;
  padding: 12px 14px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  z-index: 100;
  border: 0.5px solid rgba(255,255,255,0.12);
}
.dish-info-left { display: flex; align-items: center; gap: 10px; min-width: 0; }
.dish-name { font-size: 16px; font-weight: 600; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 200px; }
.dish-meta { font-size: 12px; color: rgba(255,255,255,0.6); margin-top: 2px; }
.dish-price { font-size: 17px; font-weight: 600; color: #fff; white-space: nowrap; flex-shrink: 0; }

/* Veg/non-veg badge */
.veg-badge { width: 20px; height: 20px; border-radius: 4px; flex-shrink: 0; display: flex; align-items: center; justify-content: center; }
.veg-badge.veg { border: 1.5px solid #2ecc71; }
.veg-badge.veg::after { content: ''; width: 10px; height: 10px; background: #2ecc71; border-radius: 50%; display: block; }
.veg-badge.non-veg { border: 1.5px solid #e74c3c; }
.veg-badge.non-veg::after { content: ''; width: 0; height: 0; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 10px solid #e74c3c; display: block; }

/* ─── AR button ─── */
.ar-button {
  position: absolute;
  bottom: 140px; left: 50%; transform: translateX(-50%);
  background: #534AB7;
  color: #fff;
  border: none;
  border-radius: 30px;
  padding: 14px 28px;
  font-size: 16px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  box-shadow: 0 4px 24px rgba(83,74,183,0.5);
  white-space: nowrap;
  z-index: 200;
}
.ar-button:active { transform: translateX(-50%) scale(0.97); }

/* AR prompt inside camera session */
.ar-prompt {
  background: rgba(0,0,0,0.7);
  color: #fff;
  padding: 10px 18px;
  border-radius: 20px;
  font-size: 14px;
  text-align: center;
}

/* ─── Size badge ─── */
.size-btn {
  position: fixed;
  bottom: 128px; right: 16px;
  background: rgba(0,0,0,0.65);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 0.5px solid rgba(255,255,255,0.2);
  border-radius: 20px;
  padding: 6px 12px;
  color: rgba(255,255,255,0.85);
  font-size: 12px;
  cursor: pointer;
  z-index: 100;
  display: flex;
  align-items: center;
  gap: 6px;
}
.size-btn::before { content: ''; width: 8px; height: 8px; background: #1D9E75; border-radius: 50%; flex-shrink: 0; }

/* ─── Bottom controls ─── */
.bottom-controls {
  position: fixed;
  bottom: 80px; left: 12px; right: 12px;
  display: flex;
  gap: 8px;
  align-items: center;
  z-index: 100;
}
.ctrl-btn {
  flex: 1;
  padding: 12px 8px;
  border-radius: 14px;
  border: 1px solid rgba(255,255,255,0.15);
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  background: rgba(0,0,0,0.65);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  min-width: 0;
  transition: background 0.15s, transform 0.1s;
}
.ctrl-btn:active { transform: scale(0.96); }
.ctrl-btn-primary {
  flex: 2;
  background: #534AB7;
  border-color: #534AB7;
  font-size: 14px;
  flex-direction: row;
  justify-content: center;
  padding: 14px 12px;
}
.ctrl-btn-primary:active { background: #3C3489; }

/* ─── Other dishes strip ─── */
.other-dishes-section {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  background: rgba(0,0,0,0.85);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-top: 0.5px solid rgba(255,255,255,0.1);
  padding: 10px 12px 20px;
  z-index: 100;
}
.other-dishes-label {
  font-size: 11px;
  color: rgba(255,255,255,0.5);
  margin-bottom: 8px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.other-dishes-strip {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
  padding-bottom: 2px;
}
.other-dishes-strip::-webkit-scrollbar { display: none; }
.dish-thumb-card {
  flex-shrink: 0;
  background: rgba(255,255,255,0.08);
  border: 0.5px solid rgba(255,255,255,0.12);
  border-radius: 12px;
  padding: 8px 10px;
  cursor: pointer;
  min-width: 90px;
  text-align: center;
  transition: background 0.15s;
}
.dish-thumb-card.active {
  border-color: #534AB7;
  background: rgba(83,74,183,0.25);
}
.dish-thumb-card:active { background: rgba(255,255,255,0.15); }
.dish-thumb-name { font-size: 12px; font-weight: 500; color: #fff; margin-bottom: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 80px; }
.dish-thumb-price { font-size: 11px; color: rgba(255,255,255,0.5); }
.dish-thumb-card.active .dish-thumb-price { color: #AFA9EC; }

/* ─── Model loading progress ─── */
.model-loading {
  position: fixed;
  bottom: 175px; left: 24px; right: 24px;
  z-index: 200;
}
.model-loading-bar { height: 3px; background: rgba(255,255,255,0.15); border-radius: 3px; overflow: hidden; }
.model-loading-fill { height: 100%; background: #534AB7; border-radius: 3px; transition: width 0.3s; }
.model-loading-text { font-size: 11px; color: rgba(255,255,255,0.5); text-align: center; margin-top: 6px; }

/* ─── Share sheet ─── */
.share-sheet {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  background: #1e1e1e;
  border-radius: 20px 20px 0 0;
  border-top: 0.5px solid rgba(255,255,255,0.12);
  padding: 16px 20px 36px;
  z-index: 400;
  transform: translateY(100%);
  transition: transform 0.3s ease;
}
.share-sheet.open { transform: translateY(0); }
.share-sheet-title { font-size: 13px; color: rgba(255,255,255,0.5); text-align: center; margin-bottom: 16px; }
.share-options { display: flex; gap: 16px; justify-content: center; }
.share-option { display: flex; flex-direction: column; align-items: center; gap: 6px; cursor: pointer; }
.share-option-icon { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 24px; }
.share-option-label { font-size: 11px; color: rgba(255,255,255,0.6); }
.share-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 399; display: none; }
.share-backdrop.open { display: block; }

/* ─── No AR fallback (3D view only, no camera) ─── */
.no-ar-banner {
  position: fixed;
  top: 80px; left: 12px; right: 12px;
  background: rgba(255,180,0,0.15);
  border: 0.5px solid rgba(255,180,0,0.3);
  border-radius: 10px;
  padding: 8px 12px;
  font-size: 12px;
  color: rgba(255,255,255,0.8);
  text-align: center;
  z-index: 100;
  display: none;
}
.no-ar-banner.visible { display: block; }
```

---

## CSS — `loading.css`

```css
/* Full-screen loading overlay */
#loading-screen {
  position: fixed; inset: 0;
  background: #111;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
  z-index: 999;
}
.loading-spinner {
  width: 40px; height: 40px;
  border: 3px solid rgba(255,255,255,0.1);
  border-top-color: #534AB7;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.loading-text { font-size: 14px; color: rgba(255,255,255,0.5); }

/* Error screen */
#error-screen {
  position: fixed; inset: 0;
  background: #111;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14px;
  padding: 32px;
  z-index: 999;
}
.error-icon { font-size: 48px; }
.error-title { font-size: 20px; font-weight: 600; color: #fff; text-align: center; }
.error-sub { font-size: 14px; color: rgba(255,255,255,0.5); text-align: center; line-height: 1.5; }
.btn-retry {
  background: #534AB7;
  color: #fff;
  border: none;
  border-radius: 30px;
  padding: 13px 28px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  margin-top: 8px;
}
```

---

## JS — `api.js`

```javascript
// All backend API calls

const API_BASE = 'https://api.arsmartmenu.com';

// Fetch dish data by QR slug — called on page load
async function fetchDishBySlug(slug) {
  const response = await axios.get(`${API_BASE}/api/public/ar/${slug}`);
  return response.data.data;
  // Returns:
  // {
  //   product: { id, name, description, priceInPaise, vegStatus, isSpicy, isBestseller, category },
  //   business: { businessName, city, orderingUrl },
  //   model: { glbUrl, usdzUrl },
  //   otherProducts: [{ id, name, priceInPaise, model: { glbUrl } }]
  // }
}

// Log that someone scanned the QR code
async function logScanEvent(slug, deviceInfo) {
  try {
    const response = await axios.post(`${API_BASE}/api/public/ar/${slug}/view`, deviceInfo);
    return response.data.data.scanEventId;
  } catch (e) {
    // Non-critical — don't break the experience if analytics fails
    console.warn('Scan event log failed:', e.message);
    return null;
  }
}

// Log AR view interaction details (called when user interacts with 3D model)
async function logViewEvent(slug, viewData) {
  try {
    await axios.post(`${API_BASE}/api/public/ar/${slug}/view`, viewData);
  } catch (e) {
    console.warn('View event log failed:', e.message);
  }
}
```

---

## JS — `analytics.js`

```javascript
// Tracks user interactions — sent to backend non-blocking

let scanEventId = null;
let viewStartTime = null;
let interactionData = {
  rotated: false,
  resized: false,
  shared: false,
  clickedOrder: false
};

function getDeviceInfo() {
  const ua = navigator.userAgent;
  const isIOS = /iPad|iPhone|iPod/.test(ua);
  const isAndroid = /Android/.test(ua);
  return {
    deviceType: /Mobi|Android/i.test(ua) ? 'mobile' : 'desktop',
    platform: isIOS ? 'ios' : isAndroid ? 'android' : 'web',
    userAgent: ua
  };
}

// Generate a simple visitor fingerprint (non-PII)
function getVisitorFingerprint() {
  let fp = localStorage.getItem('ar_fp');
  if (!fp) {
    fp = Math.random().toString(36).slice(2) + Date.now().toString(36);
    localStorage.setItem('ar_fp', fp);
  }
  return fp;
}

function startViewTracking() {
  viewStartTime = Date.now();
}

function trackInteraction(type) {
  if (type === 'rotate') interactionData.rotated = true;
  if (type === 'resize') interactionData.resized = true;
  if (type === 'share') interactionData.shared = true;
  if (type === 'order') interactionData.clickedOrder = true;
}

async function flushViewEvent(slug) {
  if (!viewStartTime) return;
  const duration = Math.round((Date.now() - viewStartTime) / 1000);
  await logViewEvent(slug, {
    scanEventId,
    viewDurationSeconds: duration,
    ...interactionData
  });
}

// Flush on page hide (user switches apps or closes tab)
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    const slug = window.currentSlug;
    if (slug) flushViewEvent(slug);
  }
});
```

---

## JS — `ar.js` (CORE — most important file)

```javascript
// Core AR initialisation logic

let currentDishData = null;
let currentSlug = null;
let rotationDeg = 0;
let sizeIndex = 0;
const sizes = [
  { label: 'Actual size', scale: '1 1 1' },
  { label: '50% smaller', scale: '0.5 0.5 0.5' },
  { label: '25% larger',  scale: '1.25 1.25 1.25' }
];

async function initAR() {
  // 1. Extract slug from URL path
  // URL: https://ar.arsmartmenu.com/dish/butter-chicken-x7k2
  const pathParts = window.location.pathname.split('/');
  const slug = pathParts[pathParts.length - 1];

  if (!slug || slug === 'dish') {
    showError('Invalid QR code. Please scan again.');
    return;
  }

  currentSlug = slug;
  window.currentSlug = slug; // for analytics.js

  // 2. Show loading
  document.getElementById('loading-text').textContent = 'Dish load ho rahi hai...';

  try {
    // 3. Fetch dish data from API
    const data = await fetchDishBySlug(slug);
    currentDishData = data;

    // 4. Log scan event (non-blocking)
    const deviceInfo = getDeviceInfo();
    scanEventId = await logScanEvent(slug, {
      ...deviceInfo,
      visitorFingerprint: getVisitorFingerprint()
    });

    // 5. Load 3D model into model-viewer
    setupModelViewer(data);

    // 6. Populate dish info UI
    populateDishInfo(data.product, data.business);

    // 7. Populate other dishes strip
    populateOtherDishes(data.otherProducts);

    // 8. Hide loading, show AR container
    document.getElementById('loading-screen').style.display = 'none';
    document.getElementById('ar-container').style.display = 'block';

    // 9. Start tracking view time
    startViewTracking();

    // 10. Check if AR is actually available on this device
    checkARAvailability();

  } catch (error) {
    console.error('AR init failed:', error);
    if (error.response?.status === 404) {
      showError('Yeh dish abhi available nahi hai.');
    } else {
      showError('Connection problem. Please check internet and try again.');
    }
  }
}

function setupModelViewer(data) {
  const mv = document.getElementById('model-viewer');
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);

  // Set 3D model sources
  mv.setAttribute('src', data.model.glbUrl);
  if (data.model.usdzUrl) {
    mv.setAttribute('ios-src', data.model.usdzUrl);
  }

  // Set page title
  document.title = `${data.product.name} — AR Smart Menu`;

  // Show model loading progress
  const modelLoading = document.getElementById('model-loading');
  const loadingFill = document.getElementById('loading-fill');
  const loadingText = document.getElementById('model-loading-text');
  modelLoading.style.display = 'block';

  // Listen to model-viewer progress events
  mv.addEventListener('progress', (event) => {
    const progress = Math.round(event.detail.totalProgress * 100);
    loadingFill.style.width = `${progress}%`;
    loadingText.textContent = `3D model load ho raha hai... ${progress}%`;
  });

  mv.addEventListener('load', () => {
    modelLoading.style.display = 'none';
    // Model loaded — AR button becomes visible automatically via model-viewer
  });

  mv.addEventListener('error', () => {
    modelLoading.style.display = 'none';
    loadingText.textContent = '3D model load nahi hua. Refresh karein.';
  });

  // Track interactions
  mv.addEventListener('camera-change', () => {
    trackInteraction('rotate');
  });
}

function checkARAvailability() {
  const mv = document.getElementById('model-viewer');
  // model-viewer fires 'ar-status' events
  mv.addEventListener('ar-status', (event) => {
    if (event.detail.status === 'failed') {
      // AR not supported on this device/browser — show 3D fallback message
      document.querySelector('.no-ar-banner').classList.add('visible');
    }
  });

  // Also check if WebXR is available
  if (!navigator.xr && !/iPhone|iPad|iPod/.test(navigator.userAgent)) {
    document.querySelector('.no-ar-banner').classList.add('visible');
  }
}

function populateDishInfo(product, business) {
  document.getElementById('dish-name').textContent = product.name;
  document.getElementById('restaurant-name').textContent = business.businessName;

  // Price
  const price = product.priceInPaise
    ? `₹${Math.round(product.priceInPaise / 100)}`
    : '';
  document.getElementById('dish-price').textContent = price;

  // Meta line: calories, spicy badge
  const metaParts = [];
  if (product.calories) metaParts.push(`${product.calories} cal`);
  if (product.isSpicy) metaParts.push('🌶️ Spicy');
  if (product.isBestseller) metaParts.push('⭐ Bestseller');
  document.getElementById('dish-meta').textContent = metaParts.join(' · ');

  // Veg/non-veg badge
  const badge = document.getElementById('veg-badge');
  if (product.vegStatus === 'veg' || product.vegStatus === 'vegan') {
    badge.className = 'veg-badge veg';
    badge.setAttribute('aria-label', 'Vegetarian');
  } else if (product.vegStatus === 'non_veg') {
    badge.className = 'veg-badge non-veg';
    badge.setAttribute('aria-label', 'Non-vegetarian');
  } else {
    badge.style.display = 'none';
  }

  // Store ordering URL for the order button
  if (business.orderingUrl) {
    document.getElementById('order-btn').dataset.url = business.orderingUrl;
  }
}

// Switch to a different dish in the same restaurant
async function switchDish(productId, slug) {
  // Highlight selected card
  document.querySelectorAll('.dish-thumb-card').forEach(c => {
    c.classList.toggle('active', c.dataset.productId === productId);
  });

  // Show loading on model-viewer
  const mv = document.getElementById('model-viewer');
  document.getElementById('model-loading').style.display = 'block';
  document.getElementById('loading-fill').style.width = '0%';

  try {
    // Fetch the new dish data
    const data = await fetchDishBySlug(slug);
    currentDishData = data;
    currentSlug = slug;
    window.currentSlug = slug;

    // Update model
    mv.setAttribute('src', data.model.glbUrl);
    if (data.model.usdzUrl) mv.setAttribute('ios-src', data.model.usdzUrl);

    // Update info card
    populateDishInfo(data.product, data.business);

    // Reset size and rotation
    sizeIndex = 0;
    rotationDeg = 0;
    document.getElementById('size-label').textContent = 'Actual size';

  } catch (e) {
    document.getElementById('model-loading').style.display = 'none';
    console.error('Dish switch failed:', e);
  }
}

// Rotate the 3D model 45° on each tap
function rotateModel() {
  rotationDeg = (rotationDeg + 45) % 360;
  const mv = document.getElementById('model-viewer');
  mv.setAttribute('orientation', `0deg ${rotationDeg}deg 0deg`);
  trackInteraction('rotate');
}

// Cycle through three sizes
function cycleSize() {
  sizeIndex = (sizeIndex + 1) % sizes.length;
  const { label, scale } = sizes[sizeIndex];
  document.getElementById('size-label').textContent = label;
  document.getElementById('model-viewer').setAttribute('scale', scale);
  trackInteraction('resize');
}

// Handle order button tap
function handleOrder() {
  trackInteraction('order');
  flushViewEvent(currentSlug); // Send analytics immediately

  const url = document.getElementById('order-btn').dataset.url;
  if (url) {
    window.location.href = url; // Deep link to restaurant ordering system
  } else {
    // Fallback: if no ordering URL configured, show WhatsApp message
    const dishName = currentDishData?.product?.name || 'dish';
    const wa = `https://wa.me/?text=I want to order ${encodeURIComponent(dishName)}`;
    window.open(wa, '_blank');
  }
}

// Share the AR experience
async function handleShare() {
  trackInteraction('share');

  const dishName = currentDishData?.product?.name || 'Dish';
  const shareUrl = window.location.href;
  const shareText = `${dishName} dekho 3D mein! 🍽️ AR Smart Menu`;

  if (navigator.share) {
    // Native share sheet (works on mobile)
    try {
      await navigator.share({ title: dishName, text: shareText, url: shareUrl });
    } catch (e) {
      // User cancelled — that's fine
    }
  } else {
    // Fallback: copy link
    navigator.clipboard.writeText(shareUrl).then(() => {
      showToast('Link copied!');
    });
  }
}

// Simple toast notification
function showToast(message) {
  const toast = document.createElement('div');
  toast.style.cssText = `
    position:fixed; bottom:200px; left:50%; transform:translateX(-50%);
    background:rgba(0,0,0,0.8); color:#fff; padding:8px 18px;
    border-radius:20px; font-size:13px; z-index:500; white-space:nowrap;
  `;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 2000);
}

function showError(message) {
  document.getElementById('loading-screen').style.display = 'none';
  document.getElementById('error-screen').style.display = 'flex';
  document.getElementById('error-message').textContent = message;
}

// Start everything when DOM is ready
document.addEventListener('DOMContentLoaded', initAR);
```

---

## JS — `ui.js`

```javascript
// Populates the other-dishes strip from API data

function populateOtherDishes(otherProducts) {
  const strip = document.getElementById('other-dishes-strip');

  if (!otherProducts || otherProducts.length === 0) {
    strip.parentElement.style.display = 'none';
    return;
  }

  strip.innerHTML = otherProducts.map(product => {
    const price = product.priceInPaise
      ? `₹${Math.round(product.priceInPaise / 100)}`
      : '';
    // Build slug for this product's AR page
    // The otherProducts array should include the slug from the API
    const slug = product.slug || product.id;

    return `
      <div class="dish-thumb-card"
           data-product-id="${product.id}"
           onclick="switchDish('${product.id}', '${slug}')"
           role="button"
           aria-label="View ${product.name} in AR">
        <div class="dish-thumb-name">${product.name}</div>
        <div class="dish-thumb-price">${price}</div>
      </div>
    `;
  }).join('');
}
```

---

## PAGE 2 — `menu.html` (Full restaurant menu view)

This page is linked from table QR codes that show the full restaurant menu rather than a single dish.

**URL format:**
```
https://ar.arsmartmenu.com/menu/{business-slug}
```

**What this page does:**
- Calls `GET /api/public/businesses/{slug}/menu` to get all live products
- Shows a grid of all dishes with name, price, veg badge
- Customer taps any dish → opens `dish.html` for that dish's AR experience
- No camera view on this page — it's a menu browser only

**Build this page with:**
- Dark background, same visual style as dish.html
- Business name + logo at top
- Category filter tabs (Starter / Main / Dessert / Beverages)
- 2-column grid of dish cards
- Each card: dish name, price, veg/non-veg badge, "View in AR" button
- Pull-to-refresh support

---

## `server.js` (Simple static file server)

```javascript
const express = require('express');
const path = require('path');
const app = express();

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// All routes serve dish.html (client-side routing handles the slug)
app.get('/dish/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'dish.html'));
});

app.get('/menu/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'menu.html'));
});

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`WebAR server running on port ${PORT}`));
```

---

## `package.json`

```json
{
  "name": "ar-smart-menu-webar",
  "version": "1.0.0",
  "description": "WebAR customer browser experience for AR Smart Menu",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
```

---

## ENVIRONMENT CONFIG

The only configurable value in the frontend is the API base URL.

Create `public/js/config.js`:
```javascript
window.AR_CONFIG = {
  API_BASE: 'https://api.arsmartmenu.com',      // your backend URL
  CDN_BASE: 'https://cdn.arsmartmenu.com',       // CloudFront URL for 3D models
  DEFAULT_LANG: 'hi'                             // hi = Hindi, en = English
};
```

Load this first in dish.html, before api.js.

---

## BACKEND API THAT THIS FRONTEND CALLS

These are the two public endpoints your backend must have ready (from the backend prompt):

### `GET /api/public/ar/:slug`
Called on page load. Returns everything needed to render the AR experience.

**Expected response:**
```json
{
  "success": true,
  "data": {
    "product": {
      "id": "uuid",
      "name": "Butter Chicken",
      "description": "Rich creamy tomato gravy...",
      "priceInPaise": 28900,
      "vegStatus": "non_veg",
      "isSpicy": false,
      "isBestseller": true,
      "calories": 420
    },
    "business": {
      "businessName": "Sharma Ji Ka Dhaba",
      "city": "Hyderabad",
      "orderingUrl": "https://swiggy.com/restaurant/sharma-ji"
    },
    "model": {
      "glbUrl": "https://cdn.arsmartmenu.com/models/butter-chicken-x7k2.glb",
      "usdzUrl": "https://cdn.arsmartmenu.com/models/butter-chicken-x7k2.usdz"
    },
    "otherProducts": [
      {
        "id": "uuid2",
        "name": "Dal Makhani",
        "priceInPaise": 22900,
        "slug": "dal-makhani-a3b1",
        "model": { "glbUrl": "..." }
      }
    ]
  }
}
```

**IMPORTANT for backend:**
- Add `slug` field to `otherProducts` items
- Add CORS headers for `https://ar.arsmartmenu.com`
- GLB files must be served with `Content-Type: model/gltf-binary`
- USDZ files must be served with `Content-Type: model/vnd.usdz+zip`
- Both model files need `Access-Control-Allow-Origin: *` header on S3/CloudFront

### `POST /api/public/ar/:slug/view`
Called to log the scan + view events. Body:
```json
{
  "deviceType": "mobile",
  "platform": "android",
  "userAgent": "Mozilla/...",
  "visitorFingerprint": "abc123",
  "scanEventId": "uuid-or-null",
  "viewDurationSeconds": 45,
  "rotated": true,
  "resized": false,
  "shared": false,
  "clickedOrder": true
}
```

---

## HOW TO TEST LOCALLY

1. Clone/create the project
2. Run `npm install`
3. Run `npm run dev`
4. Open `http://localhost:3001/dish/test-slug` in Chrome DevTools mobile view
5. For real AR testing: use `ngrok http 3001` to get a public HTTPS URL (AR requires HTTPS)
6. Open the ngrok URL on your Android phone in Chrome
7. Scan a QR code or go to `/dish/{your-real-slug}`

**Testing with a real GLB file before API is ready:**
Temporarily hardcode a test GLB URL in `ar.js` `setupModelViewer()` function:
```javascript
// TEMP: use a test model while API is being built
mv.setAttribute('src', 'https://modelviewer.dev/shared-assets/models/Astronaut.glb');
```

**Test GLB files:** https://github.com/KhronosGroup/glTF-Sample-Models

---

## IMPORTANT: 3D MODEL FILE REQUIREMENTS

Your GLB files must meet these specs for the AR experience to look good:

| Requirement | Target | Why |
|---|---|---|
| File size | Under 5MB | Loads in 3s on 4G |
| Texture resolution | 2048×2048 max | Balance quality/size |
| Polygon count | Under 100,000 | Smooth on mid-range phones |
| File format | GLB (binary GLTF) | Single file, includes textures |
| Scale | Real-world meters | 1 unit = 1 meter in GLTF |
| Origin | Centred at base | Model sits on table correctly |
| Y-up axis | Yes | Standard for GLTF |

**Scale rule is critical:** A biryani bowl is roughly 0.25m wide. In your GLB, the bowl model must be 0.25 units wide. If it's 25 units wide, it will appear as a giant bowl covering the entire table. Use Blender (free) to check and fix scale before uploading.

To check/fix GLB files for free: **gltf.report** — upload your GLB, it shows file size, polygon count, and lets you inspect the model.

---

## WHAT TO BUILD — ORDER

Build in this exact order, testing after each step:

1. `server.js` + `package.json` → run and confirm server starts
2. `dish.html` skeleton → open in browser, see blank dark page
3. `loading.css` + loading screen → see spinner on load
4. `ar.css` → add all styles
5. `api.js` → test with hardcoded slug, confirm API response shape
6. `ar.js` → connect API + model-viewer with a test GLB first
7. Confirm 3D model rotates and auto-rotates in browser
8. Add dish info card population
9. Add other dishes strip with `ui.js`
10. Test AR button on a real Android phone (needs HTTPS via ngrok)
11. Test on iPhone Safari (USDZ Quick Look)
12. Add analytics.js tracking
13. Add share functionality
14. Build `menu.html`

---

## NOTES FOR CURSOR

- No build step — all JS is vanilla, loaded via `<script>` tags in order
- Test on real devices as early as possible — AR cannot be simulated in DevTools
- The `model-viewer` web component handles all AR complexity (surface detection, placement, camera) — you do not need to write any WebXR or ARCore code
- iPhone AR (USDZ) opens natively in Safari without any JavaScript — it's triggered automatically by model-viewer's `ios-src` attribute when on iOS
- On Android, `ar-modes="webxr scene-viewer quick-look"` tries WebXR first, then Google Scene Viewer (opens Google's native AR app), then falls back to quick-look
- For best Android AR results, the user needs ARCore installed (pre-installed on most Android phones in India)
- Always test GLB files on gltf.report before using them — corrupted or oversized files will silently fail

---

*This is the complete WebAR frontend specification for AR Smart Menu. The model-viewer library handles all AR camera work. Your job is the wrapper: loading data, updating the model, handling UI interactions, and logging analytics.*
