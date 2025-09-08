'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { useNotes, useCreateNote, useUpdateNote, useDeleteNote, useSyncNotes } from '@/hooks/use-notes'
import { useAuth, useLogout } from '@/hooks/use-auth'
import type { Note } from '@/types/note'

export default function NotesPage() {
  const router = useRouter()
  const { isAuthenticated, isLoading: authLoading } = useAuth()
  const { logout } = useLogout()
  
  // Notes hooks
  const { notes, isLoading, error, searchQuery, setSearchQuery, isEmpty } = useNotes()
  const { createNote, isCreating } = useCreateNote()
  const { updateNote, isUpdating } = useUpdateNote()
  const { deleteNote, isDeleting } = useDeleteNote()
  const { 
    syncNotes, 
    isSyncing, 
    conflicts, 
    hasConflicts,
    resolveConflict,
    startAutoSync,
    stopAutoSync 
  } = useSyncNotes()

  // Local state
  const [selectedNotes, setSelectedNotes] = useState<Set<string>>(new Set())
  const [editingNote, setEditingNote] = useState<Note | null>(null)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [newNote, setNewNote] = useState({ title: '', content: '' })
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(false)

  // Check auth and redirect if needed
  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.push('/login')
    }
  }, [isAuthenticated, authLoading, router])

  // Auto-sync management
  useEffect(() => {
    if (autoSyncEnabled) {
      startAutoSync(30000) // Sync every 30 seconds
    } else {
      stopAutoSync()
    }
    
    return () => stopAutoSync()
  }, [autoSyncEnabled, startAutoSync, stopAutoSync])

  // Handle note selection
  const handleSelectNote = (noteId: string) => {
    const newSelection = new Set(selectedNotes)
    if (newSelection.has(noteId)) {
      newSelection.delete(noteId)
    } else {
      newSelection.add(noteId)
    }
    setSelectedNotes(newSelection)
  }

  const handleSelectAll = () => {
    if (selectedNotes.size === notes.length) {
      setSelectedNotes(new Set())
    } else {
      setSelectedNotes(new Set(notes.map(n => n.id)))
    }
  }

  // Create note
  const handleCreateNote = async () => {
    if (!newNote.title.trim() && !newNote.content.trim()) {
      return
    }

    await createNote({
      title: newNote.title.trim() || 'Untitled Note',
      content: newNote.content.trim(),
    })

    setNewNote({ title: '', content: '' })
    setShowCreateModal(false)
  }

  // Delete selected notes
  const handleDeleteSelected = async () => {
    if (selectedNotes.size === 0) return
    
    const confirmed = window.confirm(`Delete ${selectedNotes.size} note(s)?`)
    if (!confirmed) return

    for (const noteId of selectedNotes) {
      await deleteNote(noteId)
    }
    setSelectedNotes(new Set())
  }

  // Format date for display
  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diff = now.getTime() - date.getTime()
    const days = Math.floor(diff / (1000 * 60 * 60 * 24))
    
    if (days === 0) {
      const hours = Math.floor(diff / (1000 * 60 * 60))
      if (hours === 0) {
        const minutes = Math.floor(diff / (1000 * 60))
        return minutes <= 1 ? 'Just now' : `${minutes} minutes ago`
      }
      return hours === 1 ? '1 hour ago' : `${hours} hours ago`
    } else if (days === 1) {
      return 'Yesterday'
    } else if (days < 7) {
      return `${days} days ago`
    } else {
      return date.toLocaleDateString()
    }
  }

  if (authLoading || isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <svg className="animate-spin h-10 w-10 text-indigo-600 mx-auto" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
          <p className="mt-4 text-gray-600">Loading notes...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">My Notes</h1>
              <span className="ml-3 px-2 py-1 text-xs font-medium text-gray-500 bg-gray-100 rounded-full">
                {notes.length} notes
              </span>
            </div>
            
            <div className="flex items-center space-x-4">
              {/* Auto-sync toggle */}
              <label className="flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoSyncEnabled}
                  onChange={(e) => setAutoSyncEnabled(e.target.checked)}
                  className="sr-only"
                />
                <div className="relative">
                  <div className={`block w-10 h-6 rounded-full ${autoSyncEnabled ? 'bg-indigo-600' : 'bg-gray-300'}`}></div>
                  <div className={`absolute left-1 top-1 bg-white w-4 h-4 rounded-full transition-transform ${autoSyncEnabled ? 'translate-x-4' : ''}`}></div>
                </div>
                <span className="ml-2 text-sm text-gray-700">Auto-sync</span>
              </label>

              {/* Manual sync button */}
              <button
                onClick={() => syncNotes()}
                disabled={isSyncing}
                className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
              >
                {isSyncing ? (
                  <>
                    <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                    <span>Syncing...</span>
                  </>
                ) : (
                  <>
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    <span>Sync Now</span>
                  </>
                )}
              </button>

              {/* Logout button */}
              <button
                onClick={() => logout()}
                className="px-4 py-2 text-gray-700 hover:text-gray-900"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Conflicts Alert */}
      {hasConflicts && (
        <div className="bg-yellow-50 border-b border-yellow-200 px-4 py-3">
          <div className="max-w-7xl mx-auto flex items-center justify-between">
            <div className="flex items-center">
              <svg className="w-5 h-5 text-yellow-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <span className="text-sm text-yellow-800">
                {conflicts.length} sync conflict(s) detected
              </span>
            </div>
            <button
              onClick={() => {
                // Simple resolution: accept all server versions
                conflicts.forEach(c => resolveConflict(c.id, 'server'))
              }}
              className="text-sm text-yellow-800 hover:text-yellow-900 font-medium"
            >
              Resolve All (Accept Server)
            </button>
          </div>
        </div>
      )}

      {/* Search and Actions Bar */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex-1 max-w-lg">
            <div className="relative">
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search notes..."
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
              <svg
                className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
          </div>

          <div className="flex items-center space-x-3 ml-6">
            {selectedNotes.size > 0 && (
              <button
                onClick={handleDeleteSelected}
                className="px-4 py-2 text-red-600 hover:text-red-700 font-medium"
              >
                Delete ({selectedNotes.size})
              </button>
            )}
            
            <button
              onClick={() => setShowCreateModal(true)}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center space-x-2"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
              <span>New Note</span>
            </button>
          </div>
        </div>

        {/* Notes Table */}
        {isEmpty ? (
          <div className="bg-white rounded-lg shadow-sm border p-12 text-center">
            <svg className="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <h3 className="text-lg font-medium text-gray-900 mb-1">No notes found</h3>
            <p className="text-gray-500">
              {searchQuery ? 'Try adjusting your search' : 'Create your first note to get started'}
            </p>
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left">
                    <input
                      type="checkbox"
                      checked={selectedNotes.size === notes.length && notes.length > 0}
                      onChange={handleSelectAll}
                      className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                    />
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Title
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Version
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Updated
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {notes.map((note) => (
                  <tr key={note.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <input
                        type="checkbox"
                        checked={selectedNotes.has(note.id)}
                        onChange={() => handleSelectNote(note.id)}
                        className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                      />
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <div className="text-sm font-medium text-gray-900">
                          {note.title || 'Untitled Note'}
                        </div>
                        <div className="text-sm text-gray-500 truncate max-w-xs">
                          {note.content || 'No content'}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        note.version === 0 
                          ? 'bg-yellow-100 text-yellow-800' 
                          : 'bg-green-100 text-green-800'
                      }`}>
                        v{note.version}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {formatDate(note.updatedAt)}
                    </td>
                    <td className="px-6 py-4 text-right text-sm font-medium">
                      <button
                        onClick={() => setEditingNote(note)}
                        className="text-indigo-600 hover:text-indigo-900 mr-3"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => {
                          if (window.confirm('Delete this note?')) {
                            deleteNote(note.id)
                          }
                        }}
                        className="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Create/Edit Modal */}
      {(showCreateModal || editingNote) && (
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">
                {editingNote ? 'Edit Note' : 'Create Note'}
              </h2>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Title
                  </label>
                  <input
                    type="text"
                    value={editingNote ? editingNote.title : newNote.title}
                    onChange={(e) => {
                      if (editingNote) {
                        setEditingNote({ ...editingNote, title: e.target.value })
                      } else {
                        setNewNote({ ...newNote, title: e.target.value })
                      }
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    placeholder="Note title..."
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Content
                  </label>
                  <textarea
                    value={editingNote ? editingNote.content : newNote.content}
                    onChange={(e) => {
                      if (editingNote) {
                        setEditingNote({ ...editingNote, content: e.target.value })
                      } else {
                        setNewNote({ ...newNote, content: e.target.value })
                      }
                    }}
                    rows={8}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    placeholder="Write your note..."
                  />
                </div>
              </div>
              
              <div className="mt-6 flex justify-end space-x-3">
                <button
                  onClick={() => {
                    setShowCreateModal(false)
                    setEditingNote(null)
                    setNewNote({ title: '', content: '' })
                  }}
                  className="px-4 py-2 text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </button>
                <button
                  onClick={async () => {
                    if (editingNote) {
                      await updateNote({
                        id: editingNote.id,
                        title: editingNote.title,
                        content: editingNote.content,
                      })
                      setEditingNote(null)
                    } else {
                      await handleCreateNote()
                    }
                  }}
                  disabled={isCreating || isUpdating}
                  className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50"
                >
                  {isCreating || isUpdating ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}