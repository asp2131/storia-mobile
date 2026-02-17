// Book types — matches web API responses

export type WordTimestamp = {
  word: string;
  start: number;
  end: number;
};

export type AudioAssignment = {
  id: string;
  audioUrl: string;
  audioType: 'narration' | 'soundscape';
  scope: string;
  rangeStart: number | null;
  rangeEnd: number | null;
  volume: number | null;
};

export type PageData = {
  id: string;
  pageNumber: number;
  textContent: string | null;
  imageUrl: string | null;
  narrationUrl: string | null;
  narrationTimestamps: WordTimestamp[] | null;
  assignments?: AudioAssignment[];
};

export type BookData = {
  id: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  description: string | null;
};

export type LibraryBook = {
  id: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  description: string | null;
  totalPages: number;
  metadata: Record<string, unknown> | null;
  hasSoundscape: boolean;
  currentPage?: number;
  progressPercent?: number;
  lastReadAt?: string;
};

export type LibraryResponse = {
  books: LibraryBook[];
  pagination: {
    page: number;
    perPage: number;
    total: number;
    totalPages: number;
  };
};

export type ReaderResponse = {
  book: BookData;
  pages: PageData[];
};

export type ReadingProgress = {
  currentPage: number;
  totalPages: number;
  lastReadAt: string;
  progressPercent: number;
};

export type SoundscapeMode = 'continuous' | 'intro-only';

export type ReaderPreferences = {
  soundscapeMode: SoundscapeMode;
  soundscapeEnabled: boolean;
  hasSeenNavigationHint: boolean;
};

export type User = {
  id: string;
  name: string | null;
  email: string;
  image: string | null;
  role: string;
};

export type Session = {
  token: string;
  user: User;
};
