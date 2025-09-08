'use client'

import { useQuery, useMutation, useQueryClient, UseQueryOptions } from '@tanstack/react-query'
import { useState, useCallback, useRef, useEffect } from 'react'
import { axiosClient, extractErrorMessage } from '@/lib/api/axios-client'
import type { Note, CreateNoteDto, UpdateNoteDto, SyncChange, SyncResponse, SyncConflict } from '@/types/note'

// API functions
const notesApi = {
  // Get all notes
  getNotes: async (): Promise<Note[]> => {
    const { data } = await axiosClient.get<Note[]>('/notes')
    return data
  },

  // Get single note
  getNote: async (id: string): Promise<Note> => {
    const { data } = await axiosClient.get<Note>(`/notes/${id}`)
    return data
  },

  // Create note
  createNote: async (dto: CreateNoteDto): Promise<Note> => {
    const { data } = await axiosClient.post<Note>('/notes', dto)
    return data
  },

  // Update note
  updateNote: async ({ id, ...dto }: UpdateNoteDto & { id: string }): Promise<Note> => {
    const { data } = await axiosClient.put<Note>(`/notes/${id}`, dto)
    return data
  },

  // Delete note
  deleteNote: async (id: string): Promise<void> => {
    await axiosClient.delete(`/notes/${id}`)
  },

  // Sync notes
  syncNotes: async (changes: SyncChange[]): Promise<SyncResponse> => {
    const { data } = await axiosClient.post<SyncResponse>('/notes/sync', { changes })
    return data
  },
}

// Query keys factory
export const noteKeys = {
  all: ['notes'] as const,
  lists: () => [...noteKeys.all, 'list'] as const,
  list: (filters?: Record<string, any>) => 
    filters ? [...noteKeys.lists(), filters] : noteKeys.lists(),
  details: () => [...noteKeys.all, 'detail'] as const,
  detail: (id: string) => [...noteKeys.details(), id] as const,
}

// Get all notes hook
export function useNotes(options?: UseQueryOptions<Note[], Error>) {
  const [searchQuery, setSearchQuery] = useState('')

  const query = useQuery<Note[], Error>({
    queryKey: noteKeys.list({ search: searchQuery }),
    queryFn: notesApi.getNotes,
    staleTime: 30 * 1000, // 30 seconds
    ...options,
  })

  // Filter notes locally for instant search
  const filteredNotes = query.data?.filter((note) => {
    if (!searchQuery) return true
    const search = searchQuery.toLowerCase()
    return (
      note.title.toLowerCase().includes(search) ||
      note.content.toLowerCase().includes(search)
    )
  })

  return {
    ...query,
    notes: filteredNotes || [],
    searchQuery,
    setSearchQuery,
    isEmpty: !query.isLoading && (!filteredNotes || filteredNotes.length === 0),
  }
}

// Get single note hook
export function useNote(id: string, options?: UseQueryOptions<Note, Error>) {
  return useQuery<Note, Error>({
    queryKey: noteKeys.detail(id),
    queryFn: () => notesApi.getNote(id),
    enabled: !!id,
    staleTime: 60 * 1000, // 1 minute
    ...options,
  })
}

// Create note hook
export function useCreateNote() {
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const mutation = useMutation({
    mutationFn: notesApi.createNote,
    onMutate: async (newNote) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: noteKeys.lists() })

      // Snapshot previous value
      const previousNotes = queryClient.getQueryData<Note[]>(noteKeys.lists())

      // Optimistically update
      if (previousNotes) {
        const optimisticNote: Note = {
          id: `temp-${Date.now()}`,
          ...newNote,
          version: 0,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }
        queryClient.setQueryData<Note[]>(noteKeys.lists(), [optimisticNote, ...previousNotes])
      }

      return { previousNotes }
    },
    onError: (err, _, context) => {
      // Rollback on error
      if (context?.previousNotes) {
        queryClient.setQueryData(noteKeys.lists(), context.previousNotes)
      }
      const message = extractErrorMessage(err)
      setError(message)
      console.error('Create note error:', message)
    },
    onSuccess: (newNote) => {
      // Replace optimistic update with real data
      queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
        if (!old) return [newNote]
        // Remove temp note and add real one
        return [newNote, ...old.filter((n) => !n.id.startsWith('temp-'))]
      })
      setError(null)
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() })
    },
  })

  return {
    createNote: mutation.mutate,
    createNoteAsync: mutation.mutateAsync,
    isCreating: mutation.isPending,
    isSuccess: mutation.isSuccess,
    error,
    reset: () => {
      setError(null)
      mutation.reset()
    },
  }
}

// Update note hook
export function useUpdateNote() {
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const mutation = useMutation({
    mutationFn: notesApi.updateNote,
    onMutate: async (updatedNote) => {
      // Cancel queries
      await queryClient.cancelQueries({ queryKey: noteKeys.detail(updatedNote.id) })
      await queryClient.cancelQueries({ queryKey: noteKeys.lists() })

      // Snapshot previous values
      const previousNote = queryClient.getQueryData<Note>(noteKeys.detail(updatedNote.id))
      const previousNotes = queryClient.getQueryData<Note[]>(noteKeys.lists())

      // Optimistic update
      const optimisticNote = previousNote 
        ? { ...previousNote, ...updatedNote, updatedAt: new Date().toISOString() }
        : null

      if (optimisticNote) {
        queryClient.setQueryData(noteKeys.detail(updatedNote.id), optimisticNote)
        
        if (previousNotes) {
          queryClient.setQueryData<Note[]>(
            noteKeys.lists(),
            previousNotes.map((n) => n.id === updatedNote.id ? optimisticNote : n)
          )
        }
      }

      return { previousNote, previousNotes }
    },
    onError: (err, variables, context) => {
      // Rollback
      if (context?.previousNote) {
        queryClient.setQueryData(noteKeys.detail(variables.id), context.previousNote)
      }
      if (context?.previousNotes) {
        queryClient.setQueryData(noteKeys.lists(), context.previousNotes)
      }
      const message = extractErrorMessage(err)
      setError(message)
      console.error('Update note error:', message)
    },
    onSuccess: (updatedNote) => {
      // Update with server response
      queryClient.setQueryData(noteKeys.detail(updatedNote.id), updatedNote)
      queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
        if (!old) return [updatedNote]
        return old.map((n) => n.id === updatedNote.id ? updatedNote : n)
      })
      setError(null)
    },
    onSettled: (data) => {
      if (data) {
        queryClient.invalidateQueries({ queryKey: noteKeys.detail(data.id) })
      }
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() })
    },
  })

  return {
    updateNote: mutation.mutate,
    updateNoteAsync: mutation.mutateAsync,
    isUpdating: mutation.isPending,
    isSuccess: mutation.isSuccess,
    error,
    reset: () => {
      setError(null)
      mutation.reset()
    },
  }
}

// Delete note hook
export function useDeleteNote() {
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const mutation = useMutation({
    mutationFn: notesApi.deleteNote,
    onMutate: async (noteId) => {
      // Cancel queries
      await queryClient.cancelQueries({ queryKey: noteKeys.lists() })

      // Snapshot
      const previousNotes = queryClient.getQueryData<Note[]>(noteKeys.lists())

      // Optimistic update
      if (previousNotes) {
        queryClient.setQueryData<Note[]>(
          noteKeys.lists(),
          previousNotes.filter((n) => n.id !== noteId)
        )
      }

      return { previousNotes }
    },
    onError: (err, _, context) => {
      // Rollback
      if (context?.previousNotes) {
        queryClient.setQueryData(noteKeys.lists(), context.previousNotes)
      }
      const message = extractErrorMessage(err)
      setError(message)
      console.error('Delete note error:', message)
    },
    onSuccess: (_, noteId) => {
      // Remove from cache
      queryClient.removeQueries({ queryKey: noteKeys.detail(noteId) })
      setError(null)
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() })
    },
  })

  return {
    deleteNote: mutation.mutate,
    deleteNoteAsync: mutation.mutateAsync,
    isDeleting: mutation.isPending,
    isSuccess: mutation.isSuccess,
    error,
    reset: () => {
      setError(null)
      mutation.reset()
    },
  }
}

// Sync notes hook with conflict handling
export function useSyncNotes() {
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)
  const [conflicts, setConflicts] = useState<SyncConflict[]>([])
  const [isSyncing, setIsSyncing] = useState(false)
  const syncIntervalRef = useRef<NodeJS.Timeout>()

  const mutation = useMutation({
    mutationFn: async () => {
      // Get current notes from cache
      const notes = queryClient.getQueryData<Note[]>(noteKeys.lists()) || []
      
      // Prepare changes for sync
      const changes: SyncChange[] = notes.map((note) => ({
        id: note.id,
        title: note.title,
        content: note.content,
        baseVersion: note.version,
      }))

      return notesApi.syncNotes(changes)
    },
    onMutate: () => {
      setIsSyncing(true)
      setError(null)
    },
    onSuccess: (response) => {
      // Handle successful syncs
      if (response.applied.length > 0) {
        // Update local cache with synced notes
        queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
          if (!old) return response.applied
          
          // Merge applied notes with existing ones
          const appliedMap = new Map(response.applied.map((n) => [n.id, n]))
          return old.map((note) => appliedMap.get(note.id) || note)
        })
      }

      // Handle conflicts
      if (response.conflicts.length > 0) {
        setConflicts(response.conflicts)
        console.warn('Sync conflicts detected:', response.conflicts)
      } else {
        setConflicts([])
      }

      setIsSyncing(false)
      
      // Invalidate queries to ensure fresh data
      queryClient.invalidateQueries({ queryKey: noteKeys.all })
    },
    onError: (err) => {
      const message = extractErrorMessage(err)
      setError(message)
      setIsSyncing(false)
      console.error('Sync error:', message)
    },
  })

  // Manual sync function
  const syncNotes = useCallback(() => {
    if (!isSyncing) {
      mutation.mutate()
    }
  }, [isSyncing, mutation])

  // Auto-sync setup
  const startAutoSync = useCallback((intervalMs = 30000) => {
    stopAutoSync()
    syncIntervalRef.current = setInterval(() => {
      syncNotes()
    }, intervalMs)
  }, [syncNotes])

  const stopAutoSync = useCallback(() => {
    if (syncIntervalRef.current) {
      clearInterval(syncIntervalRef.current)
      syncIntervalRef.current = undefined
    }
  }, [])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      stopAutoSync()
    }
  }, [stopAutoSync])

  // Conflict resolution
  const resolveConflict = useCallback(
    async (conflictId: string, resolution: 'local' | 'server' | 'merge') => {
      const conflict = conflicts.find((c) => c.id === conflictId)
      if (!conflict) return

      try {
        if (resolution === 'server' && conflict.serverData) {
          // Accept server version
          await queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
            if (!old) return []
            return old.map((note) => {
              if (note.id === conflictId) {
                return {
                  ...note,
                  title: conflict.serverData!.title,
                  content: conflict.serverData!.content,
                  version: conflict.serverVersion,
                  updatedAt: new Date().toISOString(),
                }
              }
              return note
            })
          })
        } else if (resolution === 'local') {
          // Keep local version and retry sync
          await syncNotes()
        } else if (resolution === 'merge' && conflict.serverData) {
          // Merge both versions
          const localNote = queryClient.getQueryData<Note[]>(noteKeys.lists())
            ?.find((n) => n.id === conflictId)
          
          if (localNote) {
            const mergedContent = `${localNote.content}\n\n--- Server Version ---\n${conflict.serverData.content}`
            await queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
              if (!old) return []
              return old.map((note) => {
                if (note.id === conflictId) {
                  return {
                    ...note,
                    content: mergedContent,
                    version: conflict.serverVersion,
                    updatedAt: new Date().toISOString(),
                  }
                }
                return note
              })
            })
          }
        }

        // Remove resolved conflict
        setConflicts((prev) => prev.filter((c) => c.id !== conflictId))
      } catch (err) {
        console.error('Error resolving conflict:', err)
      }
    },
    [conflicts, queryClient, syncNotes]
  )

  return {
    syncNotes,
    startAutoSync,
    stopAutoSync,
    isSyncing,
    isSuccess: mutation.isSuccess,
    error,
    conflicts,
    hasConflicts: conflicts.length > 0,
    resolveConflict,
    reset: () => {
      setError(null)
      setConflicts([])
      mutation.reset()
    },
  }
}

// Batch operations hook
export function useNoteBatch() {
  const queryClient = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const deleteMultiple = useCallback(
    async (noteIds: string[]) => {
      try {
        await Promise.all(noteIds.map((id) => notesApi.deleteNote(id)))
        
        // Update cache
        queryClient.setQueryData<Note[]>(noteKeys.lists(), (old) => {
          if (!old) return []
          return old.filter((note) => !noteIds.includes(note.id))
        })
        
        // Remove individual queries
        noteIds.forEach((id) => {
          queryClient.removeQueries({ queryKey: noteKeys.detail(id) })
        })
        
        await queryClient.invalidateQueries({ queryKey: noteKeys.lists() })
      } catch (err) {
        const message = extractErrorMessage(err)
        setError(message)
        throw err
      }
    },
    [queryClient]
  )

  return {
    deleteMultiple,
    error,
  }
}