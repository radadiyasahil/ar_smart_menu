import { Link } from 'react-router-dom'

/** Shown at / when no dish slug — not an error, just entry instructions. */
export function HomePage() {
  return (
    <div className="home-page">
      <h1 className="home-title">AR Smart Menu</h1>
      <p className="home-sub">
        Scan a table QR code or open a dish link shared by the restaurant.
      </p>
      <p className="home-hint">
        Dish links look like:{' '}
        <code className="home-code">/dish/your-dish-slug</code>
      </p>
      <Link to="/dish/pizza-0znr" className="home-demo-link">
        Try demo dish
      </Link>
      <p className="home-note">
        Make sure the backend API is running on port 5232.
      </p>
    </div>
  )
}
