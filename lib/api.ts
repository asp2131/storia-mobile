import type { LibraryResponse, ReaderResponse, ReadingProgress } from '@/types';

const API_BASE = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:3000';

type RequestOptions = Omit<RequestInit, 'headers'> & {
  params?: Record<string, string>;
};

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { params, ...fetchOptions } = options;

  let url = `${API_BASE}${path}`;
  if (params) {
    const searchParams = new URLSearchParams(params);
    url += `?${searchParams.toString()}`;
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  const response = await fetch(url, {
    ...fetchOptions,
    headers,
  });

  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload?.error || `Request failed: ${response.status}`);
  }

  return response.json() as Promise<T>;
}

// Library
export function fetchBooks(params: {
  page?: number;
  perPage?: number;
  sort?: string;
  genre?: string;
  search?: string;
  userId?: string;
}) {
  const queryParams: Record<string, string> = {};
  if (params.page) queryParams.page = String(params.page);
  if (params.perPage) queryParams.perPage = String(params.perPage);
  if (params.sort) queryParams.sort = params.sort;
  if (params.genre) queryParams.genre = params.genre;
  if (params.search) queryParams.search = params.search;
  if (params.userId) queryParams.userId = params.userId;

  return request<LibraryResponse>('/api/books', { params: queryParams });
}

// Reader
export function fetchReaderData(bookId: string) {
  return request<ReaderResponse>(`/api/books/${bookId}/reader`);
}

// Reading Progress
export function fetchReadingProgress(bookId: string) {
  return request<ReadingProgress>('/api/reading-progress', {
    params: { bookId },
  });
}

export function saveReadingProgress(data: {
  bookId: string;
  currentPage: number;
  totalPages: number;
}) {
  return request<ReadingProgress>('/api/reading-progress', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

// Feedback
export function submitFeedback(data: {
  rating: number;
  feedback?: string;
  bookId?: string;
}) {
  return request<{ success: boolean }>('/api/feedback', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

// Auth
export function sendOtp(email: string) {
  return request<{ success: boolean }>('/api/auth/email-otp/send-verification-otp', {
    method: 'POST',
    body: JSON.stringify({ email, type: 'sign-in' }),
  });
}

export function verifyOtp(email: string, otp: string) {
  return request<{ token: string; user: Record<string, unknown> }>(
    '/api/auth/sign-in/email-otp',
    {
      method: 'POST',
      body: JSON.stringify({ email, otp }),
    }
  );
}

export function getSession() {
  return request<{ session: { token: string }; user: Record<string, unknown> }>(
    '/api/auth/get-session'
  );
}
