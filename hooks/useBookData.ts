import { useQuery, useInfiniteQuery } from '@tanstack/react-query';
import { fetchBooks, fetchReaderData } from '@/lib/api';
import type { LibraryResponse, ReaderResponse } from '@/types';

export function useLibraryBooks(params: {
  sort?: string;
  genre?: string;
  search?: string;
  userId?: string;
  perPage?: number;
}) {
  return useInfiniteQuery<LibraryResponse>({
    queryKey: ['library-books', params],
    queryFn: ({ pageParam }) =>
      fetchBooks({
        page: pageParam as number,
        perPage: params.perPage ?? 20,
        sort: params.sort,
        genre: params.genre,
        search: params.search,
        userId: params.userId,
      }),
    initialPageParam: 1,
    getNextPageParam: (lastPage) => {
      const { page, totalPages } = lastPage.pagination;
      return page < totalPages ? page + 1 : undefined;
    },
  });
}

export function useReaderData(bookId: string | null) {
  return useQuery<ReaderResponse>({
    queryKey: ['reader-data', bookId],
    queryFn: () => {
      if (!bookId) throw new Error('No book ID');
      return fetchReaderData(bookId);
    },
    enabled: !!bookId,
    staleTime: 60 * 1000,
  });
}
