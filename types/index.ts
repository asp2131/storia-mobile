// Book types — matches web API responses

export type WordTimestamp = {
  word: string;
  start: number;
  end: number;
};

// Text Overlay Types

export interface TextShadow {
  color: string;
  blur: number;
  x: number;
  y: number;
}

export interface TextBackground {
  color: string;
  padding?: number;
  borderRadius?: number;
}

export interface TextElement {
  id: string;
  text: string;
  x: number;
  y: number;
  width: number;
  fontFamily: string;
  fontSize: number;
  fontWeight: number;
  color: string;
  textAlign: 'left' | 'center' | 'right';
  rotation: number;
  shadow?: TextShadow;
  background?: TextBackground;
}

export interface TextOverlayConfig {
  version: number;
  elements: TextElement[];
}

// Deprecated: Use TextOverlayConfig instead
export type TextOverlayData = TextOverlayConfig;

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
  overlay: TextOverlayConfig | null;
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
