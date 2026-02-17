import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Secure storage for auth tokens
const SESSION_TOKEN_KEY = 'storia_session_token';

export async function getSessionToken(): Promise<string | null> {
  try {
    return await SecureStore.getItemAsync(SESSION_TOKEN_KEY);
  } catch {
    return null;
  }
}

export async function setSessionToken(token: string): Promise<void> {
  await SecureStore.setItemAsync(SESSION_TOKEN_KEY, token);
}

export async function clearSessionToken(): Promise<void> {
  await SecureStore.deleteItemAsync(SESSION_TOKEN_KEY);
}

// AsyncStorage for preferences and local progress
const PREFERENCES_KEY = 'storia-reader-preferences';

export async function getPreferences<T>(key: string = PREFERENCES_KEY): Promise<T | null> {
  try {
    const stored = await AsyncStorage.getItem(key);
    if (!stored) return null;
    return JSON.parse(stored) as T;
  } catch {
    return null;
  }
}

export async function setPreferences<T>(value: T, key: string = PREFERENCES_KEY): Promise<void> {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Silently fail
  }
}

// Reading progress local storage
export async function getLocalProgress(bookId: string) {
  return getPreferences<{ currentPage: number; totalPages: number; lastReadAt: string }>(
    `reading_progress_${bookId}`
  );
}

export async function setLocalProgress(
  bookId: string,
  progress: { currentPage: number; totalPages: number }
) {
  await setPreferences(
    { ...progress, lastReadAt: new Date().toISOString() },
    `reading_progress_${bookId}`
  );
}
