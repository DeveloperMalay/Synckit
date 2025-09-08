'use client'

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useRouter } from 'next/navigation'
import { useState, useCallback, useEffect } from 'react'
import { axiosClient, tokenManager, extractErrorMessage } from '@/lib/api/axios-client'
import type { LoginDto, RegisterDto, AuthResponse, User } from '@/types/auth'

// API functions
const authApi = {
  login: async (dto: LoginDto): Promise<AuthResponse> => {
    const { data } = await axiosClient.post<AuthResponse>('/auth/login', dto)
    return data
  },

  register: async (dto: RegisterDto): Promise<AuthResponse> => {
    const { data } = await axiosClient.post<AuthResponse>('/auth/register', dto)
    return data
  },

  logout: async (): Promise<void> => {
    // Optional: Call server logout endpoint if it exists
    try {
      await axiosClient.post('/auth/logout')
    } catch {
      // Continue with local logout even if server call fails
    }
  },

  getCurrentUser: async (): Promise<User | null> => {
    try {
      const { data } = await axiosClient.get<User>('/auth/me')
      return data
    } catch {
      return null
    }
  },
}

// Query keys
export const authKeys = {
  all: ['auth'] as const,
  user: () => [...authKeys.all, 'user'] as const,
  session: () => [...authKeys.all, 'session'] as const,
}

// Login hook
export function useLogin() {
  const router = useRouter()
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const mutation = useMutation({
    mutationFn: authApi.login,
    onSuccess: (data) => {
      // Save token
      tokenManager.setToken(data.token)
      
      // If refresh token is provided, save it
      if ('refreshToken' in data && data.refreshToken) {
        tokenManager.setRefreshToken(data.refreshToken as string)
      }

      // Clear all queries and set user data
      queryClient.clear()
      
      // Set user data if provided
      if (data.user) {
        queryClient.setQueryData(authKeys.user(), data.user)
      }

      // Clear error
      setError(null)

      // Redirect to dashboard
      router.push('/dashboard')
    },
    onError: (err) => {
      const message = extractErrorMessage(err)
      setError(message)
      console.error('Login error:', message)
    },
  })

  const login = useCallback(
    async (credentials: LoginDto) => {
      setError(null)
      return mutation.mutate(credentials)
    },
    [mutation]
  )

  return {
    login,
    isLoading: mutation.isPending,
    isSuccess: mutation.isSuccess,
    isError: mutation.isError,
    error,
    reset: () => {
      setError(null)
      mutation.reset()
    },
  }
}

// Register hook
export function useRegister() {
  const router = useRouter()
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const mutation = useMutation({
    mutationFn: authApi.register,
    onSuccess: (data) => {
      // Save token
      tokenManager.setToken(data.token)
      
      // If refresh token is provided, save it
      if ('refreshToken' in data && data.refreshToken) {
        tokenManager.setRefreshToken(data.refreshToken as string)
      }

      // Clear all queries and set user data
      queryClient.clear()
      
      // Set user data if provided
      if (data.user) {
        queryClient.setQueryData(authKeys.user(), data.user)
      }

      // Clear error
      setError(null)

      // Redirect to dashboard or onboarding
      router.push('/dashboard')
    },
    onError: (err) => {
      const message = extractErrorMessage(err)
      setError(message)
      console.error('Registration error:', message)
    },
  })

  const register = useCallback(
    async (userData: RegisterDto) => {
      setError(null)
      return mutation.mutate(userData)
    },
    [mutation]
  )

  return {
    register,
    isLoading: mutation.isPending,
    isSuccess: mutation.isSuccess,
    isError: mutation.isError,
    error,
    reset: () => {
      setError(null)
      mutation.reset()
    },
  }
}

// Logout hook
export function useLogout() {
  const router = useRouter()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: authApi.logout,
    onSuccess: () => {
      // Clear tokens
      tokenManager.clearAll()
      
      // Clear all cached data
      queryClient.clear()
      
      // Redirect to login
      router.push('/auth/login')
    },
    onError: (err) => {
      // Even if server logout fails, perform local logout
      tokenManager.clearAll()
      queryClient.clear()
      router.push('/auth/login')
      console.error('Logout error:', extractErrorMessage(err))
    },
  })

  return {
    logout: () => mutation.mutate(),
    isLoading: mutation.isPending,
  }
}

// Current user hook
export function useCurrentUser() {
  return useQuery({
    queryKey: authKeys.user(),
    queryFn: authApi.getCurrentUser,
    staleTime: 5 * 60 * 1000, // 5 minutes
    retry: false,
  })
}

// Auth state hook
export function useAuth() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const { data: user, isLoading: userLoading } = useCurrentUser()

  useEffect(() => {
    const token = tokenManager.getToken()
    setIsAuthenticated(!!token)
    setIsLoading(false)
  }, [])

  useEffect(() => {
    // Listen for storage events (logout from other tabs)
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'token') {
        setIsAuthenticated(!!e.newValue)
        if (!e.newValue) {
          // Token was removed, redirect to login
          window.location.href = '/auth/login'
        }
      }
    }

    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [])

  return {
    isAuthenticated,
    user,
    isLoading: isLoading || userLoading,
    token: tokenManager.getToken(),
  }
}

// Protected route hook
export function useRequireAuth(redirectTo = '/auth/login') {
  const router = useRouter()
  const { isAuthenticated, isLoading } = useAuth()

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push(redirectTo)
    }
  }, [isAuthenticated, isLoading, router, redirectTo])

  return { isAuthenticated, isLoading }
}