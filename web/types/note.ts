export interface Note {
  id: string
  title: string
  content: string
  version: number
  updatedAt: string
  createdAt: string
}

export interface CreateNoteDto {
  title: string
  content: string
}

export interface UpdateNoteDto {
  title: string
  content: string
}

export interface SyncChange {
  id: string
  title: string
  content: string
  baseVersion: number
}

export interface SyncConflict {
  id: string
  reason: string
  clientVersion: number
  serverVersion: number
  serverData?: {
    title: string
    content: string
  }
}

export interface SyncResponse {
  applied: Note[]
  conflicts: SyncConflict[]
}