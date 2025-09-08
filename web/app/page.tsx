import Link from "next/link"

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50">
      <div className="container mx-auto px-4 py-16">
        <header className="text-center mb-16">
          <div className="flex justify-center mb-6">
            <div className="w-20 h-20 bg-indigo-600 rounded-full flex items-center justify-center">
              <svg
                className="w-12 h-12 text-white"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
            </div>
          </div>
          <h1 className="text-5xl font-bold text-gray-900 mb-4">
            Welcome to SyncKit
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            A real-time note synchronization platform built with Next.js, React Query, 
            and TypeScript. Sync your notes across devices seamlessly.
          </p>
        </header>

        <div className="grid md:grid-cols-3 gap-8 mb-16">
          <div className="bg-white rounded-lg shadow-lg p-6">
            <div className="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
              <svg
                className="w-6 h-6 text-indigo-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
                />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Real-time Sync</h3>
            <p className="text-gray-600">
              Automatically sync your notes across all devices with conflict resolution
            </p>
          </div>

          <div className="bg-white rounded-lg shadow-lg p-6">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
              <svg
                className="w-6 h-6 text-purple-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Secure Authentication</h3>
            <p className="text-gray-600">
              JWT-based authentication with secure token management
            </p>
          </div>

          <div className="bg-white rounded-lg shadow-lg p-6">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
              <svg
                className="w-6 h-6 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Optimistic Updates</h3>
            <p className="text-gray-600">
              Instant UI updates with React Query for the best user experience
            </p>
          </div>
        </div>

        <div className="text-center">
          <div className="inline-flex gap-4">
            <Link
              href="/auth/login"
              className="px-8 py-3 bg-indigo-600 text-white font-semibold rounded-lg hover:bg-indigo-700 transition-colors duration-200"
            >
              Login
            </Link>
            <Link
              href="/auth/register"
              className="px-8 py-3 bg-white text-indigo-600 font-semibold rounded-lg border-2 border-indigo-600 hover:bg-indigo-50 transition-colors duration-200"
            >
              Register
            </Link>
            <Link
              href="/dashboard"
              className="px-8 py-3 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors duration-200"
            >
              Demo Mode
            </Link>
          </div>
        </div>

        <div className="mt-16 text-center">
          <h2 className="text-3xl font-bold text-gray-900 mb-8">
            Technology Stack
          </h2>
          <div className="flex flex-wrap justify-center gap-4">
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              Next.js 14
            </span>
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              React Query (TanStack Query)
            </span>
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              TypeScript
            </span>
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              Axios
            </span>
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              Tailwind CSS
            </span>
            <span className="px-4 py-2 bg-gray-100 rounded-full text-sm font-medium">
              App Router
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}