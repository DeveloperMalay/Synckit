import { Hono } from 'hono'
import { prisma } from '../lib/prisma'
import { hashPassword, comparePassword, generateToken } from '../lib/auth'

const auth = new Hono()

auth.post('/register', async (c) => {
  try {
    const { email, password, name } = await c.req.json()
    
    if (!email || !password) {
      return c.json({ error: 'Email and password are required' }, 400)
    }
    
    const existingUser = await prisma.user.findUnique({
      where: { email }
    })
    
    if (existingUser) {
      return c.json({ error: 'User already exists' }, 400)
    }
    
    const hashedPassword = await hashPassword(password)
    
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name
      },
      select: {
        id: true,
        email: true,
        name: true
      }
    })
    
    const token = generateToken(user.id)
    
    return c.json({ token })
  } catch (error) {
    return c.json({ error: 'Failed to register user' }, 500)
  }
})

auth.post('/login', async (c) => {
  try {
    const { email, password } = await c.req.json()
    
    if (!email || !password) {
      return c.json({ error: 'Email and password are required' }, 400)
    }
    
    const user = await prisma.user.findUnique({
      where: { email }
    })
    
    if (!user) {
      return c.json({ error: 'Invalid credentials' }, 401)
    }
    
    const isValidPassword = await comparePassword(password, user.password)
    
    if (!isValidPassword) {
      return c.json({ error: 'Invalid credentials' }, 401)
    }
    
    const token = generateToken(user.id)
    
    return c.json({ token })
  } catch (error) {
    return c.json({ error: 'Failed to login' }, 500)
  }
})

export default auth