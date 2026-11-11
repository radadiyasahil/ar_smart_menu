# AR Smart Menu Platform — Master Prompt for AI Models

> Use this prompt to brief any AI model (ChatGPT, Gemini, Cursor, GitHub Copilot, etc.) on the full product. Paste the entire document as the first message or system prompt.

---

## PRODUCT OVERVIEW

You are helping build **AR Smart Menu** — a B2B SaaS platform that allows restaurant owners, clothing brands, cafés, bakeries, and furniture stores to showcase their products as **3D augmented reality models** to their customers.

The platform has **three parts**:
1. **Android app** — for business owners (upload content, manage products, track analytics, subscribe to plans)
2. **Admin web panel** — for the platform team (approve businesses, manage photo shoots, handle payments, monitor platform)
3. **WebAR browser experience** — for customers (scan QR code → 3D product appears on real surface via phone camera, no app download needed; works on both Android and iPhone browsers)

---

## PLATFORM SCOPE — PHASE 1 (BUILD NOW)

### Supported business categories at launch:
- Restaurant / Dhaba
- Café / Juice bar
- Bakery / Mithai shop
- Clothing brand / Fashion store
- Furniture store / Home décor

### NOT in Phase 1:
- Jewellery, electronics, pharmacy, real estate, hotels, automotive

---

## PART 1 — BUSINESSMAN ANDROID APP

### 1.1 Auth & Onboarding
- Language selection screen at launch: Hindi, English, Gujarati, Telugu, Marathi, Tamil (app fully supports selected language throughout)
- Mobile number entry + **WhatsApp OTP** verification (NOT email OTP)
- Business type selection with icons (tap to select — not a dropdown)
- Business name + city (only mandatory fields at signup)
- FSSAI number (optional, for restaurants/cafés/bakeries)
- GST number (optional — required only if monthly billing > ₹50,000)
- Logo upload (skippable — can be added later)
- Post-signup: success screen with 3 next steps (book shoot / add product / download QR)

### 1.2 KYC & Verification
Collected progressively, not all at signup:

**Required at signup:**
- Mobile number (WhatsApp OTP verified)
- Owner full name
- Aadhaar number (verified via UIDAI DigiLocker API — show only last 4 digits after entry)
- Aadhaar front photo upload
- Business name
- Business address (city + full address)
- Bank account number + IFSC code (penny drop verification via Razorpay — ₹1 sent and returned)

**Optional / collected later:**
- PAN number (required only when billing > ₹50,000/month)
- FSSAI license photo (for restaurants, cafés, bakeries)
- GST certificate
- UPI ID (for faster payments/refunds)
- Shop logo

**NOT collected:**
- Trade license, shop & establishment certificate (optional badge only)
- Social media links
- Menu PDF (done inside app after signup)

### 1.3 Home Dashboard
After login, owner sees:
- Greeting with their name + business name
- Active subscription plan + days remaining + auto-renew status
- Upgrade plan CTA button
- 4 metric cards:
  - QR scans today (with % change vs yesterday)
  - Live items count (with pending count)
  - AR views last 7 days (with % change)
  - Orders after AR (with conversion %)
- Bar chart: QR scans last 7 days (today highlighted)
- Photo shoot banner (persistent if items don't have 3D models yet) → taps to booking screen
- Quick actions grid (2×2): Add dish / Download QR / Analytics / Billing
- Product list preview: showing top 4 items with status badges (Live / Processing / Draft)
- Add product CTA at bottom of list
- Bottom navigation: Home / Products / Analytics / Shoots / Account

### 1.4 Product / Menu Management

**Add product flow (guided wizard for non-technical owners):**
- Step 1: Product name (text field)
- Step 2: Category (e.g. Main course / Starter / Dessert for restaurant)
- Step 3: Price
- Step 4: Description (optional — voice input supported)
- Step 5: Photo upload — guided angle-by-angle:
  - "Take front photo" → guide overlay shown
  - "Take top photo" → guide overlay shown
  - "Take side photo (left)" → guide overlay shown
  - "Take side photo (right)" → guide overlay shown
  - Minimum 4 photos, maximum 8 photos
  - Each photo has a sample reference image so owner knows exact angle needed
- Step 6: Tags (veg / non-veg / spicy / bestseller / new — for restaurants)
- Step 7: Submit for 3D processing
- Confirmation screen: "Aapka dish 3D ban raha hai — 24-48 ghante mein ready hoga"

**Product statuses:**
- Draft — photos not yet uploaded
- Submitted — photos uploaded, pending AI processing
- Processing — AI 3D model being generated
- Review — 3D model ready, pending admin quality check
- Live — active, QR generates, AR viewer works
- Paused — owner hid it temporarily
- Sold out today — daily toggle, resets at midnight

**Product list screen:**
- Filter by status, category
- Search by name
- Each item shows: thumbnail, name, status badge, today's AR views, edit/delete/pause actions
- "Mark sold out today" toggle

**Per-product detail screen:**
- 3D model preview (360° spin in app)
- Edit details
- Download QR code (PNG / PDF / print-ready)
- View AR scan analytics
- Share product AR link

### 1.5 QR Code Manager
- QR codes generated per product (links to that dish's WebAR page)
- Table QR (links to full menu AR browser for that restaurant)
- Each QR downloadable as PNG (for digital) and print-ready PDF (300 DPI, A4 or tent card format)
- QR code design: branded with business logo + product name + "Scan to see in 3D" text
- Analytics per QR: total scans, unique scans, daily chart

### 1.6 Photography Service Booking
- Owner taps "Book a shoot" from dashboard or product page
- Step 1: Select items to shoot (from existing product list OR add new items to shoot)
- Step 2: Choose date from available calendar slots
- Step 3: Choose time slot (morning / afternoon / evening)
- Step 4: Confirm address (auto-filled from profile, editable)
- Step 5: Special instructions text field ("Please bring a neutral background" etc.)
- Step 6: Confirm booking (shows assigned photographer name + contact after confirmation)
- Shoot status tracking: Scheduled → Photographer en route → In progress → Completed → Processing → 3D ready
- Reschedule / cancel option (up to 24 hrs before)
- **WhatsApp notifications** at each status change (not email)
- After shoot: photographer uploads directly to the platform — owner doesn't need to do anything

### 1.7 Subscription & Billing

**Plans:**

| Feature | Starter | Growth | Pro |
|---|---|---|---|
| Monthly price | ₹399 | ₹999 | ₹2,499 |
| Self-upload | ✓ | ✓ | ✓ |
| Photo shoot included | ✗ | 1 per quarter | Quarterly |
| Product limit | 20 items | 100 items | Unlimited |
| QR codes | ✓ | ✓ | ✓ |
| Analytics | Basic | Full | Full + export |
| API integration (Swiggy/Zomato) | ✗ | ✗ | ✓ |
| WhatsApp support | ✗ | ✓ | Priority |
| Yearly discount | 15% | 20% | 25% |

**Payment gateway: Razorpay**
- Accepts UPI, cards, net banking, wallets
- Auto-renewal subscriptions
- GST-compliant invoices (auto-generated)
- Penny drop bank verification during KYC

**Billing screen:**
- Current plan card (name, price, renewal date, status)
- Monthly / yearly toggle (shows savings)
- Upgrade / downgrade / cancel options
- Payment history table: date, amount, plan, status, download invoice
- Auto-renewal toggle with confirmation dialog

### 1.8 Analytics Screen
- Date range selector: Today / 7 days / 30 days / Custom
- Metrics: Total QR scans, Total AR views, Unique visitors, Orders after AR, Conversion rate
- Bar chart: daily scans over selected period
- Top products table: name, scans, AR views, conversion
- Integration stats (Pro plan): Swiggy AR opens, Zomato AR opens, orders after AR view
- Export as CSV (Pro plan)

### 1.9 Notifications
All via WhatsApp (not push notifications, not email):
- 3D model ready for review
- Photo shoot confirmed / rescheduled / completed
- New QR scan milestone (e.g. "Your Butter Chicken got 100 scans!")
- Payment successful / failed / upcoming renewal
- Plan expiring in 3 days
- New feature announcements

### 1.10 Account & Settings
- Edit business profile (name, address, hours, logo, category)
- Edit owner profile (name, phone, Aadhaar/PAN)
- Bank details (edit, re-verify)
- Language preference
- WhatsApp notification preferences
- Logout
- Delete account (with confirmation flow + data export)

---

## PART 2 — ADMIN WEB PANEL

### 2.1 Dashboard
- Total registered businesses (today / this week / this month)
- Total AR views across platform
- Total revenue (subscriptions + shoot bookings)
- Pending approvals count (businesses + KYC)
- Processing queue count (3D models in queue)
- Revenue chart (last 30 days)
- Recent activity feed

### 2.2 Business Management
- List all businesses with filters: status (pending/active/suspended), category, city, plan
- Per business detail page:
  - KYC documents view (Aadhaar, bank verification status)
  - Approve / reject with reason
  - Suspend / reactivate
  - View all their products
  - View their payment history
  - Impersonate (view as this business owner) for support
  - Add internal notes

### 2.3 KYC Review Queue
- List of pending KYC submissions
- Auto-check results shown: Aadhaar match ✓/✗, penny drop ✓/✗
- Manual review flag for edge cases
- Approve / reject with reason (WhatsApp message sent automatically)
- 95% of submissions pass automated checks in minutes

### 2.4 Plan & Pricing Management
- Create / edit / archive subscription plans
- Set monthly and yearly pricing
- Configure feature flags per plan (item limits, shoot quota, API access)
- Promo code generator with usage limits + expiry

### 2.5 Photography Team Management
- Add/remove photographers (name, phone, city coverage)
- View photographer schedule (calendar view)
- Assign shoot bookings to available photographers
- Mark shoot as completed
- Upload shoot photos on behalf of business (photographers upload directly here)
- Photographer performance: shoots completed, avg rating

### 2.6 3D Processing Queue
- List of products submitted for AI 3D generation
- Status: Queued / Processing / Done / Failed
- Retry failed items
- Quality check: admin views 3D model before it goes Live
- Approve → status changes to Live on business side
- Reject with feedback → business owner notified via WhatsApp to re-upload photos

### 2.7 Payment & Revenue
- All transactions with filters (date, plan, status)
- Refund processing
- Revenue breakdown: subscriptions vs shoot bookings
- Monthly revenue report export (CSV/PDF)
- Razorpay webhook logs

### 2.8 API Integration Management
- Swiggy / Zomato / Myntra integration status per business
- API key generation and revocation
- WebAR embed link generator
- SDK documentation links

---

## PART 3 — CUSTOMER WebAR EXPERIENCE (BROWSER)

### 3.1 How it works
- Customer scans QR code at restaurant table (or taps AR link on Swiggy/Zomato)
- **No app download required** — opens directly in mobile browser (Chrome on Android, Safari on iPhone)
- Camera permission requested
- Phone detects flat surface (table, floor, counter) using WebXR / ARCore Web / ARKit Web
- 3D model of dish/product appears anchored to detected surface
- Customer can: rotate, scale up/down, walk around the 3D model

### 3.2 Browser screen elements
**Top bar:**
- Browser URL bar showing: ar.[yourdomain].com/dish/[dish-slug]
- Back button, Share button

**AR camera view (full screen):**
- Live camera feed as background
- Surface detection grid shown briefly (then fades)
- 3D model anchored to surface (photorealistic, correctly scaled)
- AR anchor indicator (small rings at base of model)
- Dish info card (top): thumbnail, name, price, serves, rating, calories, veg/non-veg tag
- Size indicator badge (bottom right): "Actual size" — tap to toggle 50% / 125% scale
- Surface scan prompt if no surface detected: "Kaheen flat jagah par phone rakhein" (in selected language)

**Bottom controls:**
- Rotate button (spins model 45° each tap)
- Add to order button (primary CTA — deep links to restaurant's ordering system)
- Share button (screenshot + AR link)

**Menu strip (below camera):**
- Horizontal scroll of other dishes from same restaurant
- Tap to switch AR view to that dish instantly

### 3.3 Two AR modes

**In-restaurant mode (QR on table):**
- Dish appears on actual table in front of customer
- Customer sees real portion size, garnish, presentation
- Helps decide what to order
- Works fully offline (3D model pre-loaded)

**Online ordering mode (via Swiggy/Zomato/delivery apps):**
- Customer at home taps "View in AR" on dish listing
- Opens browser WebAR
- Dish appears on their kitchen table / floor
- Confirms order after seeing actual size
- Deep link back to ordering app to complete purchase

### 3.4 Technology stack for WebAR
- **model-viewer** (Google) — primary WebAR library for Android Chrome + iPhone Safari
- **8th Wall** — fallback for devices where model-viewer AR doesn't work
- **GLB format** — 3D model file for Android + Web
- **USDZ format** — 3D model file for iPhone (AR Quick Look)
- **CDN delivery** — 3D models served from CDN for fast load
- Target load time: under 3 seconds on 4G

### 3.5 Social sharing
- "Share" button generates a screenshot of the AR view + product link
- Share sheet: WhatsApp, Instagram Stories, copy link
- Shared link opens directly in WebAR for the recipient

---

## PART 4 — OUR PHOTOGRAPHY SERVICE

This is a key differentiator. We send trained photographers to the business location.

### 4.1 Why it exists
- Most restaurant owners cannot take photos at the correct angles for photogrammetry
- Bad photos = bad 3D model = bad AR experience = customer unhappy
- Our team ensures consistent, high-quality captures

### 4.2 What the photographer does on-site
**For food (restaurant, café, bakery):**
- Neutral background setup (white/grey mat)
- Capture each dish from: front, 45° front, top, 45° back, left, right (minimum 6 angles)
- Capture video: slow 360° orbit around dish
- Lighting: portable LED ring light
- Tools: ARCode / Polycam / Luma AI app for real-time photogrammetry scan

**For clothing:**
- Mannequin or flat lay
- Front, back, side, detail shots
- Fabric texture close-up

**For furniture:**
- All 6 sides + top-down
- Material/texture close-up
- Scale reference (e.g. tape measure in frame)

### 4.3 Upload workflow
- Photographer uploads directly to admin panel from their phone during/after shoot
- Raw photos/videos uploaded to cloud storage
- Admin queues for AI 3D processing
- No action needed from business owner

---

## PART 5 — 3D MODEL GENERATION PIPELINE

### 5.1 Process
1. Photographer uploads multi-angle photos + 360° video
2. AI photogrammetry engine builds raw 3D mesh (point cloud)
3. AI mesh cleanup: removes noise, fills holes, smooths surfaces
4. Texture mapping: applies real photo textures to 3D mesh
5. LOD (level of detail) optimization for mobile WebAR performance
6. Export to GLB (Android/Web) + USDZ (iPhone)
7. Admin quality check
8. Approved → product status set to Live

### 5.2 AI tools for 3D generation
- **Luma AI** — photogrammetry from video
- **Polycam** — object capture + export
- **NeRF / Gaussian Splatting** — for highest quality food models
- **Blender (automated)** — mesh cleanup + optimization

### 5.3 Quality standards
- Model must look photorealistic at arm's length on phone screen
- Textures at minimum 2048×2048 resolution
- GLB file size target: under 5MB for fast WebAR load
- Admin reviews each model before approving to Live status

---

## PART 6 — INTEGRATION WITH FOOD DELIVERY APPS

### 6.1 Target integrations (Phase 1)
- Swiggy
- Zomato
- Domino's app
- Burger King app

### 6.2 How it works
- Business owner gets an embed link for each product: `https://ar.[domain].com/dish/[id]`
- This link is placed as a "View in AR" button on the dish listing in the delivery app
- When customer taps → opens in browser → full WebAR experience
- After viewing → "Add to cart" button deep-links back to the delivery app

### 6.3 Integration method
- Restaurant provides their AR link to Swiggy/Zomato via their restaurant dashboard
- OR: Pro plan businesses get a JavaScript SDK embed code to inject into their own app
- For Swiggy/Zomato bulk integration: contact their developer partner program (API partnership)

---

## PART 7 — TECH STACK RECOMMENDATION

### Android App
- **Framework**: Flutter (single codebase, fast development, good AR support)
- **AR library**: ARCore (Google) for surface detection in Android
- **3D viewer in app**: model-viewer WebView or Sceneview Android

### WebAR (Customer browser experience)
- **Primary**: Google model-viewer library (`<model-viewer>` HTML tag)
- **iOS Safari**: USDZ + AR Quick Look (native iPhone AR, no library needed)
- **Android Chrome**: model-viewer with ARCore Web
- **Fallback**: 8th Wall for unsupported devices

### Backend
- **API**: Node.js / Express or Python FastAPI
- **Database**: PostgreSQL
- **File storage**: AWS S3 or Google Cloud Storage (for 3D model files)
- **CDN**: Cloudflare (for fast 3D model delivery)
- **Auth**: Firebase Auth (OTP) or custom OTP via MSG91/2Factor
- **Payments**: Razorpay (subscriptions + one-time)
- **WhatsApp notifications**: WhatsApp Business API (via Interakt or Wati)

### Admin Panel
- **Framework**: React + Tailwind CSS
- **Charts**: Recharts or Chart.js

---

## PART 8 — BUSINESS MODEL

### Revenue streams
1. Monthly/yearly subscriptions (Starter ₹399 / Growth ₹999 / Pro ₹2,499)
2. Photo shoot service (included in Growth/Pro, or pay-per-shoot for Starter: ~₹1,500–₹3,000 per visit)
3. Enterprise plan (for chains, hotel groups, D2B clients — custom pricing)
4. API integration fee (for Swiggy/Zomato-level integrations)

### Target customers
- **D2C**: Small restaurants, dhabas, cafés, clothing boutiques, bakeries, furniture stores in Tier 1 and Tier 2 cities in India
- **D2B**: Restaurant chains, hotel food & beverage departments, corporate catering, clothing wholesalers

### Go-to-market
- Start in Hyderabad (home city) — build 20–30 case studies
- Photography team covers the city, doing free/discounted first shoots to onboard
- WhatsApp-first sales (most restaurant owners don't respond to email)
- Referral: existing restaurant owners refer others for 1 month free

---

## KEY DESIGN PRINCIPLES

1. **Non-technical owner first** — every screen must work for someone who has never used business software. Hindi/regional language by default.
2. **WhatsApp over email** — all notifications, OTP, support via WhatsApp
3. **Progressive disclosure** — collect only what's needed now. Add more later.
4. **Photography service is the quality gate** — 3D quality depends on capture quality. Our team goes on-site.
5. **WebAR is zero-friction for customers** — no app download, opens in browser, works on any smartphone with a camera
6. **Android app for business, browser for customers** — business owners use Android app; customers scan QR and experience AR in browser (works on both iPhone and Android)

---

## WHAT HAS BEEN DESIGNED SO FAR

The following screens/flows have been fully designed as interactive mockups:

1. Full platform system diagram (4-stage pipeline: capture → AI → delivery → AR)
2. Businessman onboarding flow (7 steps with Hindi UI)
3. Businessman home dashboard (metrics, chart, product list, quick actions)
4. KYC verification flow (4 steps: mobile OTP → identity → business docs → bank details)
5. Business category selector (with phase roadmap)
6. Customer WebAR browser experience (interactive phone mockup with dish switching, rotate, size toggle)

---

## WHAT TO BUILD NEXT (SUGGESTED ORDER)

1. Product upload guided wizard (angle-by-angle photo guide)
2. QR code download + print screen
3. Analytics screen (detailed)
4. Admin KYC review panel
5. Admin 3D processing queue
6. Photographer booking flow (full)
7. Subscription plan selector + Razorpay payment flow
8. WebAR page (actual HTML/CSS implementation for customer browser)
9. Admin dashboard
10. Swiggy/Zomato AR embed integration design

---

*This document represents the full product specification as discussed and designed. Use it to continue building any part of the platform with full context.*
