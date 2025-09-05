import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import authRoutes from './routes/auth'
import notesRoutes from './routes/notes'

const app = new Hono().basePath('/api')

app.use('*', cors())
app.use('*', logger())

app.get('/', (c) => {
  return c.json({ message: 'Hono API Server' })
})

app.route('/auth', authRoutes)
app.route('/notes', notesRoutes)

export default {
  port: process.env.PORT || 3000,
  fetch: app.fetch,
}