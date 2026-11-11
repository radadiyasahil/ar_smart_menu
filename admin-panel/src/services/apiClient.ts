import axios from 'axios'

/** Base Axios client — ready for ASP.NET Core API integration. */
export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5232/api',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Attach auth token when real authentication is added
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Centralized error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('[API Error]', error.response?.data ?? error.message)
    return Promise.reject(error)
  },
)
