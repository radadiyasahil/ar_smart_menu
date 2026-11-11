# AR Smart Menu — Cursor AI Backend Prompt
# Paste this entire file as your first message in Cursor AI Composer

---

## ROLE & GOAL

You are a senior backend engineer. Build the complete REST API backend for **AR Smart Menu** — a B2B SaaS platform where restaurant owners, clothing brands, cafés, bakeries, and furniture stores upload products, which are converted into 3D AR models that customers view in a browser by scanning a QR code.

Build this backend from scratch with full production quality: proper error handling, input validation, authentication middleware, database migrations, and clear folder structure.

---

## TECH STACK

- **Runtime**: Node.js (v20+)
- **Framework**: Express.js
- **Language**: TypeScript
- **Database**: PostgreSQL (via `pg` + `node-postgres`)
- **Query builder**: Knex.js (for migrations + query building — no ORM)
- **Auth**: JWT (access token) + OTP via MSG91 or 2Factor API
- **File uploads**: Multer + AWS S3 (via `@aws-sdk/client-s3`)
- **Payments**: Razorpay Node SDK
- **WhatsApp notifications**: Interakt API (WhatsApp Business API)
- **QR code generation**: `qrcode` npm package
- **Validation**: Zod
- **Environment config**: dotenv
- **Logging**: Winston
- **Testing**: Jest + Supertest

---

## PROJECT STRUCTURE

Create this exact folder structure:

```
ar-smart-menu-backend/
├── src/
│   ├── config/
│   │   ├── database.ts          # Knex connection config
│   │   ├── s3.ts                # AWS S3 client config
│   │   ├── razorpay.ts          # Razorpay client config
│   │   └── env.ts               # All env vars typed + validated
│   ├── db/
│   │   ├── migrations/          # All Knex migration files (numbered)
│   │   └── seeds/               # Seed data for dev
│   ├── middleware/
│   │   ├── auth.ts              # JWT verify middleware
│   │   ├── adminAuth.ts         # Admin-only middleware
│   │   ├── validate.ts          # Zod request validation middleware
│   │   ├── upload.ts            # Multer config for file uploads
│   │   └── errorHandler.ts      # Global error handler
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.routes.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   └── auth.schema.ts   # Zod schemas
│   │   ├── businesses/
│   │   │   ├── businesses.routes.ts
│   │   │   ├── businesses.controller.ts
│   │   │   ├── businesses.service.ts
│   │   │   └── businesses.schema.ts
│   │   ├── products/
│   │   │   ├── products.routes.ts
│   │   │   ├── products.controller.ts
│   │   │   ├── products.service.ts
│   │   │   └── products.schema.ts
│   │   ├── models3d/
│   │   │   ├── models3d.routes.ts
│   │   │   ├── models3d.controller.ts
│   │   │   └── models3d.service.ts
│   │   ├── qrcodes/
│   │   │   ├── qrcodes.routes.ts
│   │   │   ├── qrcodes.controller.ts
│   │   │   └── qrcodes.service.ts
│   │   ├── shoots/
│   │   │   ├── shoots.routes.ts
│   │   │   ├── shoots.controller.ts
│   │   │   ├── shoots.service.ts
│   │   │   └── shoots.schema.ts
│   │   ├── subscriptions/
│   │   │   ├── subscriptions.routes.ts
│   │   │   ├── subscriptions.controller.ts
│   │   │   └── subscriptions.service.ts
│   │   ├── payments/
│   │   │   ├── payments.routes.ts
│   │   │   ├── payments.controller.ts
│   │   │   └── payments.service.ts
│   │   ├── analytics/
│   │   │   ├── analytics.routes.ts
│   │   │   ├── analytics.controller.ts
│   │   │   └── analytics.service.ts
│   │   ├── notifications/
│   │   │   ├── notifications.service.ts  # WhatsApp sender
│   │   │   └── notifications.templates.ts
│   │   └── admin/
│   │       ├── admin.routes.ts
│   │       ├── admin.controller.ts
│   │       └── admin.service.ts
│   ├── shared/
│   │   ├── types.ts             # Shared TypeScript interfaces
│   │   ├── utils.ts             # Helpers (slugify, paginate, etc.)
│   │   ├── errors.ts            # Custom error classes
│   │   └── constants.ts        # Enums, constants
│   ├── jobs/
│   │   ├── resetSoldOut.ts      # Midnight cron: reset sold_out_today
│   │   └── aggregateAnalytics.ts # Nightly cron: fill daily_aggregates
│   └── app.ts                   # Express app setup
├── knexfile.ts                  # Knex config (dev/prod)
├── .env.example
├── tsconfig.json
├── package.json
└── README.md
```

---

## DATABASE SCHEMA

Create Knex migrations for every table below. Use `uuid_generate_v4()` for all IDs (enable `uuid-ossp` extension in first migration). All timestamps use `timestamptz`. All monetary values in **paise** (integer, never decimal).

### Migration order:

**001_create_extensions.ts**
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

**002_create_users.ts**
```sql
CREATE TYPE kyc_status_enum AS ENUM ('pending', 'submitted', 'verified', 'rejected');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  mobile_number VARCHAR(15) UNIQUE NOT NULL,
  whatsapp_number VARCHAR(15),
  full_name VARCHAR(255),
  aadhaar_last4 VARCHAR(4),
  aadhaar_doc_url TEXT,
  pan_number VARCHAR(10),
  language_preference VARCHAR(10) DEFAULT 'hi',
  kyc_status kyc_status_enum DEFAULT 'pending',
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**003_create_businesses.ts**
```sql
CREATE TYPE business_type_enum AS ENUM (
  'restaurant', 'cafe', 'bakery', 'clothing', 'furniture'
);

CREATE TYPE business_status_enum AS ENUM (
  'pending_approval', 'active', 'suspended', 'rejected'
);

CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_name VARCHAR(255) NOT NULL,
  business_type business_type_enum NOT NULL,
  city VARCHAR(100) NOT NULL,
  full_address TEXT NOT NULL,
  logo_url TEXT,
  fssai_number VARCHAR(50),
  gst_number VARCHAR(20),
  bank_account_number VARCHAR(30),
  bank_ifsc VARCHAR(15),
  upi_id VARCHAR(100),
  bank_penny_verified BOOLEAN DEFAULT FALSE,
  razorpay_contact_id VARCHAR(100),
  razorpay_fund_account_id VARCHAR(100),
  status business_status_enum DEFAULT 'pending_approval',
  rejection_reason TEXT,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES users(id),
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_businesses_owner ON businesses(owner_id);
CREATE INDEX idx_businesses_status ON businesses(status);
```

**004_create_subscription_plans.ts**
```sql
CREATE TABLE subscription_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(50) UNIQUE NOT NULL,
  monthly_price_paise INTEGER NOT NULL,
  yearly_price_paise INTEGER NOT NULL,
  max_products INTEGER NOT NULL,
  includes_shoot BOOLEAN DEFAULT FALSE,
  shoots_per_year INTEGER DEFAULT 0,
  api_integration BOOLEAN DEFAULT FALSE,
  analytics_export BOOLEAN DEFAULT FALSE,
  whatsapp_support BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default plans
INSERT INTO subscription_plans
  (name, slug, monthly_price_paise, yearly_price_paise, max_products, includes_shoot, shoots_per_year, api_integration, analytics_export, whatsapp_support)
VALUES
  ('Starter', 'starter', 39900, 406920, 20, false, 0, false, false, false),
  ('Growth',  'growth',  99900, 959040, 100, true, 1, false, true,  true),
  ('Pro',     'pro',     249900, 2249100, 999999, true, 4, true, true, true);
```

**005_create_subscriptions.ts**
```sql
CREATE TYPE billing_cycle_enum AS ENUM ('monthly', 'yearly');
CREATE TYPE subscription_status_enum AS ENUM ('active', 'past_due', 'cancelled', 'expired', 'trialing');

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES subscription_plans(id),
  billing_cycle billing_cycle_enum NOT NULL DEFAULT 'monthly',
  status subscription_status_enum NOT NULL DEFAULT 'active',
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  razorpay_subscription_id VARCHAR(100) UNIQUE,
  shoots_used INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_business ON subscriptions(business_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
```

**006_create_payments.ts**
```sql
CREATE TYPE payment_status_enum AS ENUM ('created', 'authorized', 'captured', 'failed', 'refunded');
CREATE TYPE payment_type_enum AS ENUM ('subscription', 'shoot_booking', 'addon');

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  subscription_id UUID REFERENCES subscriptions(id),
  payment_type payment_type_enum NOT NULL DEFAULT 'subscription',
  amount_paise INTEGER NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  status payment_status_enum DEFAULT 'created',
  razorpay_order_id VARCHAR(100) UNIQUE,
  razorpay_payment_id VARCHAR(100) UNIQUE,
  razorpay_signature VARCHAR(255),
  invoice_number VARCHAR(50) UNIQUE,
  invoice_url TEXT,
  gst_amount_paise INTEGER DEFAULT 0,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payments_business ON payments(business_id);
CREATE INDEX idx_payments_status ON payments(status);
```

**007_create_products.ts**
```sql
CREATE TYPE product_status_enum AS ENUM (
  'draft', 'submitted', 'processing', 'review', 'live', 'paused', 'rejected'
);

CREATE TYPE veg_status_enum AS ENUM ('veg', 'non_veg', 'vegan', 'not_applicable');

CREATE TYPE product_category_enum AS ENUM (
  'starter', 'main_course', 'dessert', 'beverage', 'bread',
  'combo', 'tops', 'bottoms', 'ethnic', 'western', 'accessories',
  'sofa', 'bed', 'table', 'chair', 'storage', 'decor',
  'cake', 'pastry', 'mithai', 'snack', 'other'
);

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price_paise INTEGER,
  category product_category_enum,
  veg_status veg_status_enum DEFAULT 'not_applicable',
  is_spicy BOOLEAN DEFAULT FALSE,
  is_bestseller BOOLEAN DEFAULT FALSE,
  is_new BOOLEAN DEFAULT FALSE,
  status product_status_enum DEFAULT 'draft',
  rejection_reason TEXT,
  sold_out_today BOOLEAN DEFAULT FALSE,
  sold_out_date DATE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_products_business ON products(business_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_sold_out ON products(sold_out_today, sold_out_date);
```

**008_create_product_photos.ts**
```sql
CREATE TYPE angle_type_enum AS ENUM (
  'front', 'top', 'left', 'right', 'back', 'angle_45_front',
  'angle_45_back', 'detail', 'other'
);

CREATE TABLE product_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  s3_key TEXT NOT NULL,
  angle_type angle_type_enum DEFAULT 'other',
  sort_order INTEGER DEFAULT 0,
  file_size_bytes INTEGER,
  mime_type VARCHAR(50),
  uploaded_by VARCHAR(20) DEFAULT 'owner',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_photos_product ON product_photos(product_id);
```

**009_create_models_3d.ts**
```sql
CREATE TYPE model_processing_status_enum AS ENUM (
  'queued', 'processing', 'done', 'failed', 'approved', 'rejected'
);

CREATE TABLE models_3d (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  glb_url TEXT,
  usdz_url TEXT,
  glb_s3_key TEXT,
  usdz_s3_key TEXT,
  glb_size_bytes INTEGER,
  usdz_size_bytes INTEGER,
  processing_status model_processing_status_enum DEFAULT 'queued',
  processing_error TEXT,
  processing_job_id VARCHAR(255),
  reviewed_by UUID REFERENCES users(id),
  review_notes TEXT,
  processing_started_at TIMESTAMPTZ,
  processing_completed_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_models_product ON models_3d(product_id);
CREATE INDEX idx_models_status ON models_3d(processing_status);
```

**010_create_qr_codes.ts**
```sql
CREATE TYPE qr_type_enum AS ENUM ('product', 'table', 'menu');

CREATE TABLE qr_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  qr_type qr_type_enum NOT NULL DEFAULT 'product',
  slug VARCHAR(100) UNIQUE NOT NULL,
  web_url TEXT NOT NULL,
  qr_image_url TEXT,
  qr_image_s3_key TEXT,
  qr_pdf_url TEXT,
  qr_pdf_s3_key TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_qr_business ON qr_codes(business_id);
CREATE INDEX idx_qr_slug ON qr_codes(slug);
```

**011_create_photographers.ts**
```sql
CREATE TABLE photographers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name VARCHAR(255) NOT NULL,
  mobile_number VARCHAR(15) UNIQUE NOT NULL,
  city VARCHAR(100) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  total_shoots_completed INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**012_create_shoot_bookings.ts**
```sql
CREATE TYPE time_slot_enum AS ENUM ('morning', 'afternoon', 'evening');
CREATE TYPE shoot_status_enum AS ENUM (
  'pending', 'confirmed', 'photographer_assigned',
  'en_route', 'in_progress', 'completed', 'cancelled', 'rescheduled'
);

CREATE TABLE shoot_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  photographer_id UUID REFERENCES photographers(id),
  shoot_date DATE NOT NULL,
  time_slot time_slot_enum NOT NULL,
  address TEXT NOT NULL,
  special_instructions TEXT,
  status shoot_status_enum DEFAULT 'pending',
  confirmed_at TIMESTAMPTZ,
  assigned_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  rescheduled_from UUID REFERENCES shoot_bookings(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE shoot_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shoot_id UUID NOT NULL REFERENCES shoot_bookings(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  item_status VARCHAR(50) DEFAULT 'pending',
  notes TEXT
);

CREATE TABLE shoot_uploads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shoot_id UUID NOT NULL REFERENCES shoot_bookings(id),
  product_id UUID REFERENCES products(id),
  file_url TEXT NOT NULL,
  s3_key TEXT NOT NULL,
  file_type VARCHAR(20) DEFAULT 'photo',
  angle_type angle_type_enum DEFAULT 'other',
  file_size_bytes INTEGER,
  uploaded_by UUID REFERENCES users(id),
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);
```

**013_create_analytics.ts**
```sql
CREATE TYPE device_type_enum AS ENUM ('mobile', 'tablet', 'desktop', 'unknown');
CREATE TYPE platform_enum AS ENUM ('android', 'ios', 'web', 'unknown');

CREATE TABLE ar_scan_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  qr_code_id UUID REFERENCES qr_codes(id),
  product_id UUID REFERENCES products(id),
  business_id UUID NOT NULL REFERENCES businesses(id),
  visitor_fingerprint VARCHAR(64),
  device_type device_type_enum DEFAULT 'unknown',
  platform platform_enum DEFAULT 'unknown',
  user_agent TEXT,
  city VARCHAR(100),
  scanned_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ar_view_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_event_id UUID REFERENCES ar_scan_events(id),
  product_id UUID REFERENCES products(id),
  business_id UUID REFERENCES businesses(id),
  view_duration_seconds INTEGER DEFAULT 0,
  rotated BOOLEAN DEFAULT FALSE,
  resized BOOLEAN DEFAULT FALSE,
  shared BOOLEAN DEFAULT FALSE,
  clicked_order BOOLEAN DEFAULT FALSE,
  viewed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE daily_aggregates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  product_id UUID REFERENCES products(id),
  date DATE NOT NULL,
  total_scans INTEGER DEFAULT 0,
  unique_scans INTEGER DEFAULT 0,
  ar_views INTEGER DEFAULT 0,
  order_clicks INTEGER DEFAULT 0,
  shares INTEGER DEFAULT 0,
  computed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(business_id, product_id, date)
);

CREATE INDEX idx_scan_events_business ON ar_scan_events(business_id, scanned_at);
CREATE INDEX idx_view_events_product ON ar_view_events(product_id, viewed_at);
CREATE INDEX idx_daily_agg_business ON daily_aggregates(business_id, date);
```

**014_create_notifications.ts**
```sql
CREATE TYPE notification_type_enum AS ENUM (
  'model_ready', 'model_rejected', 'shoot_confirmed', 'shoot_assigned',
  'shoot_completed', 'payment_success', 'payment_failed', 'plan_expiring',
  'kyc_approved', 'kyc_rejected', 'qr_milestone', 'welcome'
);

CREATE TYPE delivery_status_enum AS ENUM (
  'pending', 'sent', 'delivered', 'read', 'failed'
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  type notification_type_enum NOT NULL,
  whatsapp_number VARCHAR(15) NOT NULL,
  message_body TEXT NOT NULL,
  template_name VARCHAR(100),
  whatsapp_message_id VARCHAR(255),
  delivery_status delivery_status_enum DEFAULT 'pending',
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_business ON notifications(business_id, created_at);
```

---

## ENVIRONMENT VARIABLES

Create `.env.example` with all of these:

```env
# Server
NODE_ENV=development
PORT=3000
API_BASE_URL=http://localhost:3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ar_smart_menu
DB_USER=postgres
DB_PASSWORD=your_password
DB_SSL=false

# JWT
JWT_SECRET=your_jwt_secret_min_32_chars
JWT_EXPIRES_IN=7d
ADMIN_JWT_SECRET=your_admin_jwt_secret

# OTP (MSG91)
MSG91_AUTH_KEY=your_msg91_key
MSG91_TEMPLATE_ID=your_otp_template_id
MSG91_SENDER_ID=ARSMNU

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=ap-south-1
AWS_S3_BUCKET=ar-smart-menu-uploads
AWS_CLOUDFRONT_URL=https://your-cf-domain.cloudfront.net

# Razorpay
RAZORPAY_KEY_ID=rzp_live_xxx
RAZORPAY_KEY_SECRET=your_razorpay_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret

# WhatsApp (Interakt)
INTERAKT_API_KEY=your_interakt_key
INTERAKT_BASE_URL=https://api.interakt.ai

# WebAR base URL (for QR code links)
WEBAR_BASE_URL=https://ar.yourdomain.com

# Frontend app URL
FRONTEND_URL=https://app.yourdomain.com
```

---

## ALL API ENDPOINTS

Implement every endpoint listed. All responses follow this envelope:
```json
{ "success": true, "data": {}, "message": "string" }
{ "success": false, "error": "string", "code": "ERROR_CODE" }
```

All list endpoints support: `?page=1&limit=20&sort=created_at&order=desc`

---

### AUTH MODULE `/api/auth`

```
POST   /api/auth/send-otp
  Body: { mobile: string }
  Action: Generate 6-digit OTP, store in Redis/DB with 5min TTL, send via MSG91 WhatsApp
  Response: { message: "OTP sent", otpId: string }

POST   /api/auth/verify-otp
  Body: { mobile: string, otp: string, otpId: string }
  Action: Verify OTP. If user doesn't exist, create new user. Return JWT.
  Response: { token: string, user: UserObject, isNewUser: boolean }

POST   /api/auth/refresh-token
  Header: Authorization: Bearer <token>
  Response: { token: string }

POST   /api/auth/logout
  Header: Authorization: Bearer <token>
  Action: Blacklist token (store in DB/Redis)

GET    /api/auth/me
  Header: Authorization: Bearer <token>
  Response: { user: UserObject, business: BusinessObject | null }
```

---

### BUSINESSES MODULE `/api/businesses`

```
POST   /api/businesses
  Auth: Required (JWT)
  Body: { businessName, businessType, city, fullAddress, language }
  Action: Create business linked to authenticated user. Status = pending_approval.
  Response: { business: BusinessObject }

GET    /api/businesses/me
  Auth: Required
  Response: { business: BusinessObject, subscription: SubscriptionObject }

PUT    /api/businesses/me
  Auth: Required
  Body: { businessName?, city?, fullAddress?, logoUrl?, fssaiNumber?, gstNumber? }
  Response: { business: BusinessObject }

POST   /api/businesses/me/logo
  Auth: Required
  Body: multipart/form-data { logo: File (max 5MB, jpg/png/webp) }
  Action: Upload to S3 at path: logos/{businessId}/{timestamp}.ext
  Response: { logoUrl: string }

POST   /api/businesses/me/kyc/aadhaar
  Auth: Required
  Body: { aadhaarNumber: string (12 digits), fullName: string }
  Action: Store aadhaar_last4, update full_name. Store full number encrypted (never return it).
  Response: { message: "Aadhaar submitted" }

POST   /api/businesses/me/kyc/aadhaar-photo
  Auth: Required
  Body: multipart/form-data { photo: File }
  Action: Upload to S3 at: kyc/{userId}/aadhaar_{timestamp}.jpg
  Response: { docUrl: string }

POST   /api/businesses/me/kyc/bank
  Auth: Required
  Body: { accountNumber: string, ifsc: string, upiId?: string }
  Action: Trigger Razorpay penny drop verification. Store result.
  Response: { verified: boolean, bankName: string }

GET    /api/businesses/me/kyc/status
  Auth: Required
  Response: {
    mobileVerified: boolean,
    aadhaarSubmitted: boolean,
    aadhaarPhotoUploaded: boolean,
    bankVerified: boolean,
    overallStatus: 'pending' | 'submitted' | 'verified' | 'rejected'
  }
```

---

### PRODUCTS MODULE `/api/products`

```
POST   /api/products
  Auth: Required
  Body: { name, description?, priceInPaise?, category?, vegStatus?, isSpicy?, isBestseller?, isNew? }
  Validation: Check subscription product limit before creating
  Response: { product: ProductObject }

GET    /api/products
  Auth: Required
  Query: ?status=live&category=main_course&page=1&limit=20
  Response: { products: ProductObject[], total: number, page: number }

GET    /api/products/:productId
  Auth: Required (must own product)
  Response: { product: ProductObject, photos: PhotoObject[], model3d: Model3dObject | null, qrCode: QrObject | null }

PUT    /api/products/:productId
  Auth: Required
  Body: { name?, description?, priceInPaise?, category?, vegStatus?, isSpicy?, isBestseller?, isNew?, displayOrder? }
  Response: { product: ProductObject }

DELETE /api/products/:productId
  Auth: Required
  Action: Soft delete (set status = 'paused'), deactivate QR codes
  Response: { message: "Product removed" }

POST   /api/products/:productId/sold-out
  Auth: Required
  Body: { soldOut: boolean }
  Action: Set sold_out_today + sold_out_date = today
  Response: { product: ProductObject }

POST   /api/products/:productId/photos
  Auth: Required
  Body: multipart/form-data { photos: File[] (max 8, jpg/png/webp, each max 10MB), angleTypes: string[] }
  Action: Upload each to S3 at: products/{businessId}/{productId}/photos/{timestamp}_{angle}.jpg
          If product has >= 4 photos and status is 'draft', auto-update to 'submitted' and queue for 3D processing
  Response: { photos: PhotoObject[], productStatus: string }

DELETE /api/products/:productId/photos/:photoId
  Auth: Required
  Action: Delete from S3, remove DB record
  Response: { message: "Photo deleted" }

GET    /api/products/:productId/analytics
  Auth: Required
  Query: ?range=7d (options: today, 7d, 30d)
  Response: { totalScans, uniqueScans, arViews, orderClicks, conversionRate, dailyChart: [] }
```

---

### 3D MODELS MODULE `/api/models`

```
GET    /api/models/:productId
  Auth: Required
  Response: { model: Model3dObject }

POST   /api/models/:productId/resubmit
  Auth: Required
  Action: If model status is 'rejected', reset to 'queued' for reprocessing
  Response: { model: Model3dObject }

-- WEBHOOK from 3D processing service
POST   /api/models/webhook/processing-complete
  Auth: Webhook secret header
  Body: { productId, glbUrl, usdz_url, glbS3Key, usdzS3Key, status: 'done'|'failed', error? }
  Action: Update model record. If done: set status='review', send WhatsApp to owner "3D model ready for review".
          Admin must approve before going live.
  Response: { received: true }
```

---

### QR CODES MODULE `/api/qrcodes`

```
POST   /api/qrcodes/product/:productId
  Auth: Required
  Action: Generate unique slug (e.g. "butter-chicken-x7k2"). Generate QR image pointing to
          {WEBAR_BASE_URL}/dish/{slug}. Upload QR PNG + PDF to S3. Store in qr_codes table.
  Response: { qrCode: QrObject }

GET    /api/qrcodes
  Auth: Required
  Response: { qrCodes: QrObject[] }

GET    /api/qrcodes/:qrId/download
  Auth: Required
  Query: ?format=png|pdf
  Response: Redirect to S3 signed URL (valid 15 minutes)

DELETE /api/qrcodes/:qrId
  Auth: Required
  Action: Set is_active = false
  Response: { message: "QR code deactivated" }

-- PUBLIC: Called by WebAR browser when customer scans
GET    /api/public/ar/:slug
  Auth: None (public)
  Action: Fetch product + 3D model URLs + business info by slug. Log scan event.
  Body (optional): { deviceType, platform, visitorFingerprint, city }
  Response: {
    product: { name, description, priceInPaise, vegStatus, category },
    business: { businessName, city },
    model: { glbUrl, usdzUrl },
    otherProducts: ProductObject[] (other live products of same business, max 6)
  }

-- PUBLIC: Track AR view event (called from WebAR page)
POST   /api/public/ar/:slug/view
  Auth: None
  Body: { scanEventId?, viewDurationSeconds, rotated, resized, shared, clickedOrder }
  Response: { received: true }
```

---

### SHOOTS MODULE `/api/shoots`

```
POST   /api/shoots
  Auth: Required
  Body: {
    shootDate: string (ISO date, min 3 days from today),
    timeSlot: 'morning'|'afternoon'|'evening',
    address: string,
    specialInstructions?: string,
    productIds: uuid[] (products to shoot)
  }
  Validation: Check subscription includes shoot or paid separately
  Action: Create booking + shoot_items. Send WhatsApp confirmation to owner.
  Response: { shoot: ShootObject }

GET    /api/shoots
  Auth: Required
  Query: ?status=confirmed&page=1
  Response: { shoots: ShootObject[] }

GET    /api/shoots/:shootId
  Auth: Required
  Response: { shoot: ShootObject, items: ShootItemObject[], uploads: ShootUploadObject[] }

PUT    /api/shoots/:shootId/reschedule
  Auth: Required
  Body: { shootDate: string, timeSlot: string }
  Validation: Only allowed if shoot_date is > 24 hours away
  Response: { shoot: ShootObject }

DELETE /api/shoots/:shootId
  Auth: Required
  Action: Cancel booking. Send WhatsApp notification.
  Response: { message: "Shoot cancelled" }

-- Called by photographer via admin panel
POST   /api/shoots/:shootId/upload
  Auth: Admin or Photographer token
  Body: multipart/form-data { files: File[], productId: uuid, angleTypes: string[] }
  Action: Upload to S3 at: shoots/{shootId}/{productId}/{timestamp}_{angle}.jpg
          Auto-add to product_photos. If product now has >= 4 photos, submit for 3D processing.
  Response: { uploads: ShootUploadObject[] }
```

---

### SUBSCRIPTIONS MODULE `/api/subscriptions`

```
GET    /api/subscriptions/plans
  Auth: None (public)
  Response: { plans: PlanObject[] }

GET    /api/subscriptions/me
  Auth: Required
  Response: { subscription: SubscriptionObject, plan: PlanObject, daysRemaining: number }

POST   /api/subscriptions/create-order
  Auth: Required
  Body: { planId: uuid, billingCycle: 'monthly'|'yearly' }
  Action: Create Razorpay order. Store in payments table with status 'created'.
  Response: { orderId: string, amount: number, currency: string, razorpayKeyId: string }

POST   /api/subscriptions/verify-payment
  Auth: Required
  Body: { razorpayOrderId, razorpayPaymentId, razorpaySignature, planId, billingCycle }
  Action: Verify Razorpay signature (HMAC SHA256). Create/update subscription.
          Generate invoice PDF. Upload to S3. Update payment record.
          Send WhatsApp welcome/upgrade message.
  Response: { subscription: SubscriptionObject, invoiceUrl: string }

POST   /api/subscriptions/cancel
  Auth: Required
  Action: Set cancelled_at. Subscription remains active until end of period.
  Response: { message: "Subscription cancelled", activeUntil: date }

-- Razorpay webhook (for recurring payments)
POST   /api/payments/webhook/razorpay
  Auth: Razorpay signature header verification
  Action: Handle: payment.captured → extend subscription
                  payment.failed → mark past_due, send WhatsApp alert
                  subscription.cancelled → update status
  Response: { received: true }
```

---

### ANALYTICS MODULE `/api/analytics`

```
GET    /api/analytics/overview
  Auth: Required
  Query: ?range=7d (options: today, 7d, 30d, 90d)
  Response: {
    totalScans: number,
    uniqueScans: number,
    arViews: number,
    orderClicks: number,
    conversionRate: number,
    changeVsPrevious: { scans: number, views: number } (percentage)
  }

GET    /api/analytics/chart
  Auth: Required
  Query: ?range=7d&metric=scans
  Response: { labels: string[], values: number[] }

GET    /api/analytics/top-products
  Auth: Required
  Query: ?range=7d&limit=10
  Response: { products: [{ productId, name, scans, arViews, orderClicks, conversionRate }] }

GET    /api/analytics/export
  Auth: Required (Pro plan only)
  Query: ?range=30d&format=csv
  Response: CSV file download
```

---

### ADMIN MODULE `/api/admin`

All admin routes require `adminAuth` middleware (checks `users.is_admin = true`).

```
-- Dashboard
GET    /api/admin/dashboard
  Response: { totalBusinesses, activeBusinesses, pendingApprovals, totalRevenuePaise, arViewsToday, processingQueueCount }

-- Business management
GET    /api/admin/businesses
  Query: ?status=pending_approval&city=Hyderabad&type=restaurant&page=1
  Response: { businesses: BusinessObject[], total: number }

GET    /api/admin/businesses/:businessId
  Response: { business: BusinessObject, owner: UserObject, subscription: SubscriptionObject, kycDocuments: {}, stats: {} }

POST   /api/admin/businesses/:businessId/approve
  Body: { notes?: string }
  Action: Set status='active', approved_at=now, approved_by=adminId. Send WhatsApp to owner.
  Response: { business: BusinessObject }

POST   /api/admin/businesses/:businessId/reject
  Body: { reason: string }
  Action: Set status='rejected', rejection_reason. Send WhatsApp to owner.
  Response: { business: BusinessObject }

POST   /api/admin/businesses/:businessId/suspend
  Body: { reason: string }
  Response: { business: BusinessObject }

-- 3D model queue
GET    /api/admin/models/queue
  Query: ?status=review&page=1
  Response: { models: [{ model, product, business }] }

POST   /api/admin/models/:modelId/approve
  Action: Set status='approved'. Update product status='live'. Generate QR code if none exists. Send WhatsApp.
  Response: { model: Model3dObject }

POST   /api/admin/models/:modelId/reject
  Body: { reason: string }
  Action: Set status='rejected'. Update product status='rejected'. Send WhatsApp to owner with reason.
  Response: { model: Model3dObject }

-- Photography team
GET    /api/admin/photographers
  Response: { photographers: PhotographerObject[] }

POST   /api/admin/photographers
  Body: { fullName, mobileNumber, city }
  Response: { photographer: PhotographerObject }

GET    /api/admin/shoots
  Query: ?status=pending&city=Hyderabad&date=2025-06-01
  Response: { shoots: ShootObject[] }

POST   /api/admin/shoots/:shootId/assign
  Body: { photographerId: uuid }
  Action: Assign photographer. Update status='photographer_assigned'. Send WhatsApp to both owner and photographer.
  Response: { shoot: ShootObject }

POST   /api/admin/shoots/:shootId/status
  Body: { status: shoot_status_enum }
  Response: { shoot: ShootObject }

-- Payments
GET    /api/admin/payments
  Query: ?status=captured&page=1&from=2025-01-01&to=2025-12-31
  Response: { payments: PaymentObject[], totalRevenuePaise: number }

POST   /api/admin/payments/:paymentId/refund
  Body: { amountPaise: number, reason: string }
  Action: Trigger Razorpay refund API.
  Response: { refund: {} }

-- Notifications log
GET    /api/admin/notifications
  Query: ?businessId=uuid&type=model_ready&status=failed
  Response: { notifications: NotificationObject[] }
```

---

### NOTIFICATIONS SERVICE

Create `src/modules/notifications/notifications.service.ts`:

```typescript
// Send WhatsApp message via Interakt API
// Use template messages (pre-approved by WhatsApp)

interface WhatsAppPayload {
  to: string;           // e.g. "919876543210"
  templateName: string; // pre-approved template name
  params: string[];     // template variables
}

// Templates to implement:
// welcome            → "Namaste {{1}}! AR Smart Menu par aapka swagat hai..."
// model_ready        → "{{1}} ka 3D model taiyar hai! Ab live karein: {{2}}"
// model_rejected     → "{{1}} ka model reject hua. Wajah: {{2}}. Dobara upload karein."
// shoot_confirmed    → "Shoot confirm hua! Date: {{1}}, Time: {{2}}"
// shoot_assigned     → "Aapka photographer {{1}} aa raha hai. Contact: {{2}}"
// shoot_completed    → "Shoot complete! 3D models {{1}} ghante mein taiyar honge."
// payment_success    → "Payment successful! ₹{{1}} receive hua. Invoice: {{2}}"
// payment_failed     → "Payment fail hua. Plan renew karne ke liye: {{1}}"
// plan_expiring      → "Aapka {{1}} plan {{2}} din mein expire ho raha hai. Renew karein."
// kyc_approved       → "KYC verify ho gayi! Ab aap products add kar sakte hain."
// kyc_rejected       → "KYC reject hua. Wajah: {{1}}. Support ke liye WhatsApp karein."
```

---

### BACKGROUND JOBS

Create these cron jobs in `src/jobs/`:

```typescript
// resetSoldOut.ts — runs at midnight IST (18:30 UTC)
// UPDATE products SET sold_out_today = false WHERE sold_out_today = true AND sold_out_date < CURRENT_DATE

// aggregateAnalytics.ts — runs at 2am IST daily
// For each business+product combination, compute yesterday's totals from raw events
// INSERT INTO daily_aggregates ... ON CONFLICT (business_id, product_id, date) DO UPDATE

// expireSubscriptions.ts — runs every hour
// UPDATE subscriptions SET status = 'expired' WHERE ends_at < NOW() AND status = 'active'
// Then send WhatsApp notification to expired businesses
```

Use `node-cron` package for scheduling.

---

## MIDDLEWARE SPECIFICATIONS

### `auth.ts` — JWT middleware
```typescript
// Extract Bearer token from Authorization header
// Verify with JWT_SECRET
// Attach decoded { userId, businessId } to req.user
// Return 401 if missing/invalid/expired
```

### `adminAuth.ts` — Admin middleware
```typescript
// First run auth.ts
// Then query: SELECT is_admin FROM users WHERE id = req.user.userId
// Return 403 if is_admin = false
```

### `validate.ts` — Zod validation
```typescript
// Takes a Zod schema, validates req.body
// Returns 400 with field-level errors if invalid
// Example: validate(z.object({ mobile: z.string().regex(/^[6-9]\d{9}$/) }))
```

### `upload.ts` — Multer
```typescript
// Memory storage (not disk) — pipe directly to S3
// Max file size: 10MB for product photos, 5MB for logos, 50MB for shoot videos
// Allowed types: image/jpeg, image/png, image/webp, video/mp4
```

### `errorHandler.ts` — Global error handler
```typescript
// Catch all unhandled errors
// Log with Winston
// Return { success: false, error: message, code: ERROR_CODE }
// Never expose stack traces in production
// Handle: ValidationError (400), AuthError (401), ForbiddenError (403), NotFoundError (404), ConflictError (409)
```

---

## BUSINESS LOGIC RULES

Implement these rules in service layer (not controllers):

1. **Product limit check**: Before creating a product, check `COUNT(products WHERE business_id = X AND status != 'draft') < plan.max_products`

2. **Subscription required**: All product operations require an active subscription (`subscriptions.status = 'active' AND ends_at > NOW()`)

3. **Auto-submit for 3D**: When a product gets its 4th photo, automatically set `status = 'submitted'` and insert into `models_3d` with `processing_status = 'queued'`

4. **QR auto-generate**: When admin approves a 3D model, if no QR code exists for the product, auto-generate one

5. **Shoot quota**: When booking a shoot, check `subscription.shoots_used < plan.shoots_per_year`. Increment `shoots_used` on shoot completion.

6. **Slug generation**: For QR codes: `{product-name-slug}-{4 random alphanumeric chars}`. Ensure uniqueness with retry loop.

7. **Razorpay signature verification**: Always verify `HMAC-SHA256(orderId + "|" + paymentId, razorpayKeySecret)` before updating payment status.

8. **Penny drop**: Use Razorpay Fund Account Validation API to verify bank account. Create contact → create fund account → trigger validation.

---

## SECURITY REQUIREMENTS

- All routes except `/api/public/*`, `/api/auth/*`, `/api/subscriptions/plans`, and webhook endpoints require JWT auth
- Rate limit OTP send: max 3 per mobile per 10 minutes (use express-rate-limit + store in PostgreSQL)
- Rate limit all API routes: 100 req/min per IP (express-rate-limit)
- Sanitize all user inputs (no raw SQL — use Knex parameterized queries only)
- Never log sensitive data (Aadhaar numbers, bank accounts, JWT tokens)
- S3 bucket: private (no public access). All file URLs served via CloudFront signed URLs (15 min expiry) or Razorpay-hosted URLs
- Webhook endpoints: verify signature headers before processing
- CORS: allow only `FRONTEND_URL` and `WEBAR_BASE_URL` origins
- Helmet.js for security headers

---

## PACKAGE.JSON DEPENDENCIES

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "knex": "^3.1.0",
    "pg": "^8.11.3",
    "zod": "^3.22.4",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "multer": "^1.4.5-lts.1",
    "@aws-sdk/client-s3": "^3.490.0",
    "@aws-sdk/s3-request-presigner": "^3.490.0",
    "razorpay": "^2.9.2",
    "qrcode": "^1.5.3",
    "axios": "^1.6.5",
    "node-cron": "^3.0.3",
    "winston": "^3.11.0",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.1.5",
    "dotenv": "^16.4.1",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/express": "^4.17.21",
    "@types/node": "^20.11.5",
    "@types/pg": "^8.10.9",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/multer": "^1.4.11",
    "@types/qrcode": "^1.5.5",
    "@types/cors": "^2.8.17",
    "@types/bcryptjs": "^2.4.6",
    "ts-node": "^10.9.2",
    "ts-node-dev": "^2.0.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.11",
    "supertest": "^6.3.4",
    "@types/supertest": "^6.0.2"
  },
  "scripts": {
    "dev": "ts-node-dev --respawn src/app.ts",
    "build": "tsc",
    "start": "node dist/app.js",
    "migrate": "knex migrate:latest",
    "migrate:rollback": "knex migrate:rollback",
    "seed": "knex seed:run",
    "test": "jest --runInBand"
  }
}
```

---

## START HERE — BUILD ORDER

Build in this exact order so each step is testable:

1. Project setup: `package.json`, `tsconfig.json`, `.env`, folder structure
2. `src/config/` — database, S3, Razorpay, env validation
3. All Knex migrations (run them, verify tables exist)
4. `src/middleware/` — errorHandler, validate, auth
5. `src/modules/auth/` — OTP send + verify + JWT (test with Postman)
6. `src/modules/businesses/` — create + KYC endpoints
7. `src/modules/subscriptions/` — plans list + Razorpay order + verify
8. `src/modules/products/` — CRUD + photo upload
9. `src/modules/qrcodes/` — generate + public AR endpoint
10. `src/modules/shoots/` — booking + upload
11. `src/modules/analytics/` — overview + chart
12. `src/modules/admin/` — all admin endpoints
13. `src/jobs/` — cron jobs
14. `src/modules/notifications/` — WhatsApp service

---

## NOTES FOR CURSOR

- Use TypeScript strict mode (`"strict": true` in tsconfig)
- Every service function must have proper TypeScript return types
- Use Knex transactions for any operation that touches multiple tables
- All database queries through Knex — no raw `pg.query()` except for complex aggregations
- Controllers are thin — only extract req params, call service, send response
- Services contain all business logic
- Create a `shared/types.ts` file with TypeScript interfaces for every table row
- Add JSDoc comments on all service functions explaining what they do
- Create a `README.md` with: setup steps, env var explanations, how to run migrations, how to run tests

---

*This is the complete backend specification for AR Smart Menu. Build all modules as described. Ask me if any endpoint behavior is unclear before implementing.*
