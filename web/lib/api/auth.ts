import { axiosClient } from './axios-client'
import type { LoginDto, RegisterDto, AuthResponse } from '@/types/auth'

export const authApi = {
  // Login
  login: async (dto: LoginDto): Promise<AuthResponse> => {
    const { data } = await axiosClient.post('/auth/login', dto)
    if (data.token) {
      localStorage.setItem('token', data.token)
    }
    return data
  },

  // Register
  register: async (dto: RegisterDto): Promise<AuthResponse> => {
    const { data } = await axiosClient.post('/auth/register', dto)
    if (data.token) {
      localStorage.setItem('token', data.token)
    }
    return data
  },

  // Logout
  logout: async (): Promise<void> => {
    localStorage.removeItem('token')
  },

  // Check if user is authenticated
  isAuthenticated: (): boolean => {
    if (typeof window === 'undefined') return false
    return !!localStorage.getItem('token')
  },

  // Get current token
  getToken: (): string | null => {
    if (typeof window === 'undefined') return null
    return localStorage.getItem('token')
  },
}