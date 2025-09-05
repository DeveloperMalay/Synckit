import { Hono } from 'hono'
import { prisma } from '../lib/prisma'
import { authMiddleware } from '../middleware/auth'

const notes = new Hono()

notes.use('*', authMiddleware)

notes.get('/', async (c) => {
  try {
    const userId = c.get('userId')
    
    const userNotes = await prisma.note.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    })
    
    return c.json(userNotes)
  } catch (error) {
    return c.json({ error: 'Failed to fetch notes' }, 500)
  }
})

notes.get('/:id', async (c) => {
  try {
    const userId = c.get('userId')
    const id = c.req.param('id')
    
    const note = await prisma.note.findFirst({
      where: {
        id,
        userId
      }
    })
    
    if (!note) {
      return c.json({ error: 'Note not found' }, 404)
    }
    
    return c.json(note)
  } catch (error) {
    return c.json({ error: 'Failed to fetch note' }, 500)
  }
})

notes.post('/', async (c) => {
  try {
    const userId = c.get('userId')
    const { title, content } = await c.req.json()
    
    if (!title || !content) {
      return c.json({ error: 'Title and content are required' }, 400)
    }
    
    const note = await prisma.note.create({
      data: {
        title,
        content,
        userId
      }
    })
    
    return c.json(note)
  } catch (error) {
    return c.json({ error: 'Failed to create note' }, 500)
  }
})

notes.put('/:id', async (c) => {
  try {
    const userId = c.get('userId')
    const id = c.req.param('id')
    const { title, content } = await c.req.json()
    
    const existingNote = await prisma.note.findFirst({
      where: {
        id,
        userId
      }
    })
    
    if (!existingNote) {
      return c.json({ error: 'Note not found' }, 404)
    }
    
    const note = await prisma.note.update({
      where: { id },
      data: {
        title: title || existingNote.title,
        content: content || existingNote.content
      }
    })
    
    return c.json(note)
  } catch (error) {
    return c.json({ error: 'Failed to update note' }, 500)
  }
})

notes.delete('/:id', async (c) => {
  try {
    const userId = c.get('userId')
    const id = c.req.param('id')
    
    const existingNote = await prisma.note.findFirst({
      where: {
        id,
        userId
      }
    })
    
    if (!existingNote) {
      return c.json({ error: 'Note not found' }, 404)
    }
    
    await prisma.note.delete({
      where: { id }
    })
    
    return c.json({ message: 'Note deleted successfully' })
  } catch (error) {
    return c.json({ error: 'Failed to delete note' }, 500)
  }
})

notes.post('/sync', async (c) => {
  try {
    const userId = c.get('userId')
    const { changes } = await c.req.json()
    
    if (!changes || !Array.isArray(changes)) {
      return c.json({ error: 'Changes array is required' }, 400)
    }
    
    const applied = []
    const conflicts = []
    
    for (const change of changes) {
      const { id, title, content, baseVersion } = change
      
      if (!id || baseVersion === undefined) {
        conflicts.push({
          id,
          reason: 'Missing required fields',
          clientVersion: baseVersion,
          serverVersion: null
        })
        continue
      }
      
      const existingNote = await prisma.note.findFirst({
        where: {
          id,
          userId
        }
      })
      
      if (!existingNote) {
        const newNote = await prisma.note.create({
          data: {
            id,
            title: title || '',
            content: content || '',
            version: 1,
            userId
          }
        })
        applied.push({
          id: newNote.id,
          title: newNote.title,
          content: newNote.content,
          version: newNote.version
        })
      } else if (baseVersion === existingNote.version) {
        const updatedNote = await prisma.note.update({
          where: { id },
          data: {
            title: title !== undefined ? title : existingNote.title,
            content: content !== undefined ? content : existingNote.content,
            version: {
              increment: 1
            }
          }
        })
        applied.push({
          id: updatedNote.id,
          title: updatedNote.title,
          content: updatedNote.content,
          version: updatedNote.version
        })
      } else if (baseVersion < existingNote.version) {
        conflicts.push({
          id,
          reason: 'Version conflict',
          clientVersion: baseVersion,
          serverVersion: existingNote.version,
          serverData: {
            title: existingNote.title,
            content: existingNote.content
          }
        })
      } else {
        conflicts.push({
          id,
          reason: 'Client version ahead of server',
          clientVersion: baseVersion,
          serverVersion: existingNote.version
        })
      }
    }
    
    return c.json({ applied, conflicts })
  } catch (error) {
    return c.json({ error: 'Failed to sync notes' }, 500)
  }
})

export default notes