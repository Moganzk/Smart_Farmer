import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { logger } from '../utils/logger';
import { initDb, getDatabase } from '../db/database';

const AUTH_KEY = '@smart_farmer_auth';
const USER_KEY = '@smart_farmer_user';

interface User {
  id: string;
  phone: string;
  name: string;
  location: string;
}

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  login: (phone: string, userId: string) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (userData: Partial<User>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    initializeAuth();
  }, []);

  const initializeAuth = async () => {
    try {
      // Initialize database
      await initDb();
      
      // Check for stored auth
      const authData = await AsyncStorage.getItem(AUTH_KEY);
      const userData = await AsyncStorage.getItem(USER_KEY);

      if (authData && userData) {
        setIsAuthenticated(true);
        setUser(JSON.parse(userData));
        logger.info('Auth restored from AsyncStorage', { userId: JSON.parse(userData).id });
      } else {
        logger.info('No stored auth found');
      }
    } catch (error) {
      logger.error('Failed to initialize auth', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (phone: string, userId: string) => {
    try {
      const authData = { phone, userId, timestamp: Date.now() };
      await AsyncStorage.setItem(AUTH_KEY, JSON.stringify(authData));
      
      setIsAuthenticated(true);
      logger.info('User logged in', { phone, userId });
    } catch (error) {
      logger.error('Login failed', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await AsyncStorage.multiRemove([AUTH_KEY, USER_KEY]);
      setIsAuthenticated(false);
      setUser(null);
      logger.info('User logged out');
    } catch (error) {
      logger.error('Logout failed', error);
      throw error;
    }
  };

  const updateUser = async (userData: Partial<User>) => {
    try {
      const updatedUser = { ...user, ...userData } as User;
      await AsyncStorage.setItem(USER_KEY, JSON.stringify(updatedUser));
      setUser(updatedUser);
      logger.info('User data updated', { userId: updatedUser.id });
    } catch (error) {
      logger.error('Failed to update user', error);
      throw error;
    }
  };

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isLoading,
        user,
        login,
        logout,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
