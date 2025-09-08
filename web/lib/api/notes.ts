import { axiosClient } from './axios-client'
import type { Note, CreateNoteDto, UpdateNoteDto, SyncChange, SyncResponse } from '@/types/note'

export const notesApi = {
  // Get all notes
  getNotes: async (): Promise<Note[]> => {
    const { data } = await axiosClient.get('/notes')
    return data
  },

  // Get single note
  getNote: async (id: string): Promise<Note> => {
    const { data } = await axiosClient.get(`/notes/${id}`)
    return data
  },

  // Create note
  createNote: async (dto: CreateNoteDto): Promise<Note> => {
    const { data } = await axiosClient.post('/notes', dto)
    return data
  },

  // Update note
  updateNote: async (id: string, dto: UpdateNoteDto): Promise<Note> => {
    const { data } = await axiosClient.put(`/notes/${id}`, dto)
    return data
  },

  // Delete note
  deleteNote: async (id: string): Promise<void> => {
    await axiosClient.delete(`/notes/${id}`)
  },

  // Sync notes
  syncNotes: async (changes: SyncChange[]): Promise<SyncResponse> => {
    const { data } = await axiosClient.post('/notes/sync', { changes })
    return data
  },
}