import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import type { User } from '@/types';
import { getSessionToken, setSessionToken, clearSessionToken } from '@/lib/storage';
import * as api from '@/lib/api';

type AuthState = {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  signIn: (token: string, user: User) => Promise<void>;
  signOut: () => Promise<void>;
  refreshSession: () => Promise<void>;
};

const AuthContext = createContext<AuthState>({
  user: null,
  isLoading: true,
  isAuthenticated: false,
  signIn: async () => {},
  signOut: async () => {},
  refreshSession: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshSession = useCallback(async () => {
    try {
      const token = await getSessionToken();
      if (!token) {
        setUser(null);
        return;
      }

      const data = await api.getSession();
      setUser(data.user as unknown as User);
    } catch {
      setUser(null);
      await clearSessionToken();
    }
  }, []);

  useEffect(() => {
    refreshSession().finally(() => setIsLoading(false));
  }, [refreshSession]);

  const signIn = useCallback(async (token: string, userData: User) => {
    await setSessionToken(token);
    setUser(userData);
  }, []);

  const signOut = useCallback(async () => {
    await clearSessionToken();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        signIn,
        signOut,
        refreshSession,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
