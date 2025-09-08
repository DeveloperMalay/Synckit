import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api'

// Create axios instance
export const axiosClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000,
})

// Token management
export const tokenManager = {
  getToken: (): string | null => {
    if (typeof window === 'undefined') return null
    return localStorage.getItem('token')
  },
  
  setToken: (token: string): void => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('token', token)
    }
  },
  
  removeToken: (): void => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token')
    }
  },
  
  getRefreshToken: (): string | null => {
    if (typeof window === 'undefined') return null
    return localStorage.getItem('refreshToken')
  },
  
  setRefreshToken: (token: string): void => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('refreshToken', token)
    }
  },
  
  removeRefreshToken: (): void => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('refreshToken')
    }
  },
  
  clearAll: (): void => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token')
      localStorage.removeItem('refreshToken')
    }
  }
}

// Request interceptor for auth token
axiosClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = tokenManager.getToken()
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    
    // Log request in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`🚀 ${config.method?.toUpperCase()} ${config.url}`, config.data)
    }
    
    return config
  },
  (error: AxiosError) => {
    console.error('❌ Request error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor for error handling and token refresh
let isRefreshing = false
let refreshSubscribers: ((token: string) => void)[] = []

const subscribeTokenRefresh = (cb: (token: string) => void) => {
  refreshSubscribers.push(cb)
}

const onTokenRefreshed = (token: string) => {
  refreshSubscribers.forEach((cb) => cb(token))
  refreshSubscribers = []
}

axiosClient.interceptors.response.use(
  (response) => {
    // Log response in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`✅ Response from ${response.config.url}:`, response.data)
    }
    return response
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean }
    
    // Log error in development
    if (process.env.NODE_ENV === 'development') {
      console.error(`❌ Response error from ${originalRequest?.url}:`, error.response?.data)
    }
    
    // Handle 401 Unauthorized errors
    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      if (isRefreshing) {
        // If already refreshing, queue this request
        return new Promise((resolve) => {
          subscribeTokenRefresh((token: string) => {
            originalRequest.headers.Authorization = `Bearer ${token}`
            resolve(axiosClient(originalRequest))
          })
        })
      }
      
      originalRequest._retry = true
      isRefreshing = true
      
      const refreshToken = tokenManager.getRefreshToken()
      
      if (refreshToken) {
        try {
          // Try to refresh the token
          const { data } = await axios.post(`${API_BASE_URL}/auth/refresh`, {
            refreshToken
          })
          
          const newToken = data.token
          tokenManager.setToken(newToken)
          
          if (data.refreshToken) {
            tokenManager.setRefreshToken(data.refreshToken)
          }
          
          isRefreshing = false
          onTokenRefreshed(newToken)
          
          // Retry original request with new token
          originalRequest.headers.Authorization = `Bearer ${newToken}`
          return axiosClient(originalRequest)
        } catch (refreshError) {
          isRefreshing = false
          tokenManager.clearAll()
          
          // Redirect to login
          if (typeof window !== 'undefined') {
            window.location.href = '/auth/login'
          }
          
          return Promise.reject(refreshError)
        }
      } else {
        // No refresh token, redirect to login
        tokenManager.clearAll()
        if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/auth')) {
          window.location.href = '/auth/login'
        }
      }
    }
    
    // Handle other errors
    if (error.response?.status === 403) {
      console.error('Forbidden: You do not have permission to access this resource')
    } else if (error.response?.status === 404) {
      console.error('Not found: The requested resource does not exist')
    } else if (error.response?.status === 500) {
      console.error('Server error: Something went wrong on the server')
    }
    
    return Promise.reject(error)
  }
)

// Helper function to extract error message
export const extractErrorMessage = (error: unknown): string => {
  if (axios.isAxiosError(error)) {
    // Check for server error message
    if (error.response?.data?.message) {
      return error.response.data.message
    }
    if (error.response?.data?.error) {
      return error.response.data.error
    }
    // Network or timeout errors
    if (error.code === 'ERR_NETWORK') {
      return 'Network error. Please check your connection.'
    }
    if (error.code === 'ECONNABORTED') {
      return 'Request timeout. Please try again.'
    }
  }
  
  if (error instanceof Error) {
    return error.message
  }
  
  return 'An unexpected error occurred'
}