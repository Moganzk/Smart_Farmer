import React, { useState } from 'react';
import { View, Text, StyleSheet, Image, TextInput, TouchableOpacity, KeyboardAvoidingView, Platform, Alert } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList } from '../../navigation/AuthNavigator';
import { ScreenBackground } from '../../components/ScreenBackground';
import { AuthBackgrounds, Logos } from '../../utils/assetsRegistry';
import { logger } from '../../utils/logger';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../utils/supabase';

// Dev mode bypass - set to false in production
const DEV_MODE = __DEV__ || true; // Always true for now until SMS is set up

type LoginScreenNavigationProp = StackNavigationProp<AuthStackParamList, 'Login'>;

interface Props {
  navigation: LoginScreenNavigationProp;
}

export default function LoginScreen({ navigation }: Props) {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [email, setEmail] = useState('');
  const [authMethod, setAuthMethod] = useState<'phone' | 'email'>('phone');
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();

  const handlePhoneLogin = async () => {
    if (!phoneNumber.trim()) {
      logger.warn('Login attempt with empty phone number');
      return;
    }

    setIsLoading(true);
    logger.info('Phone login initiated', { phoneNumber });

    if (DEV_MODE) {
      // Dev bypass: Skip SMS, use fixed OTP "123456"
      logger.info('DEV MODE: Skipping SMS, use OTP 123456');
      Alert.alert(
        'Dev Mode',
        'SMS disabled. Use OTP: 123456',
        [{ text: 'OK', onPress: () => navigation.navigate('OTP', { phoneNumber, authMethod: 'phone' }) }]
      );
    } else {
      // Production: Use Supabase phone auth (requires Twilio setup)
      try {
        const { error } = await supabase.auth.signInWithOtp({
          phone: phoneNumber,
        });
        if (error) throw error;
        navigation.navigate('OTP', { phoneNumber, authMethod: 'phone' });
      } catch (error: any) {
        logger.error('Failed to send OTP', error);
        Alert.alert('Error', error.message || 'Failed to send OTP');
      }
    }
    setIsLoading(false);
  };

  const handleEmailLogin = async () => {
    if (!email.trim() || !email.includes('@')) {
      logger.warn('Login attempt with invalid email');
      Alert.alert('Invalid Email', 'Please enter a valid email address');
      return;
    }

    setIsLoading(true);
    logger.info('Email login initiated', { email });

    try {
      const { error } = await supabase.auth.signInWithOtp({
        email: email,
        options: {
          emailRedirectTo: 'smartfarmer://auth/callback',
        },
      });
      
      if (error) throw error;
      
      Alert.alert(
        'Check Your Email',
        `We sent a magic link to ${email}. Click it to sign in!`,
        [{ text: 'OK' }]
      );
      logger.info('Magic link sent successfully', { email });
    } catch (error: any) {
      logger.error('Failed to send magic link', error);
      Alert.alert('Error', error.message || 'Failed to send magic link');
    }
    setIsLoading(false);
  };

  const handleLogin = () => {
    if (authMethod === 'phone') {
      handlePhoneLogin();
    } else {
      handleEmailLogin();
    }
  };

  return (
    <ScreenBackground source={AuthBackgrounds.login} statusBarStyle="light-content">
      <KeyboardAvoidingView
        style={styles.keyboardAvoid}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <View style={styles.content}>
          <View style={styles.header}>
            <Image
              source={Logos.primary}
              style={styles.logo}
              resizeMode="contain"
            />
            <Text style={styles.title}>Welcome to Smart Farmer</Text>
            <Text style={styles.subtitle}>Detect plant diseases with AI</Text>
          </View>

          {/* Auth Method Toggle */}
          <View style={styles.toggleContainer}>
            <TouchableOpacity
              style={[styles.toggleButton, authMethod === 'phone' && styles.toggleActive]}
              onPress={() => setAuthMethod('phone')}
            >
              <Text style={[styles.toggleText, authMethod === 'phone' && styles.toggleTextActive]}>
                Phone
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.toggleButton, authMethod === 'email' && styles.toggleActive]}
              onPress={() => setAuthMethod('email')}
            >
              <Text style={[styles.toggleText, authMethod === 'email' && styles.toggleTextActive]}>
                Email
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.form}>
            {authMethod === 'phone' ? (
              <TextInput
                style={styles.input}
                placeholder="Enter phone number (e.g. +254...)"
                placeholderTextColor="#9E9E9E"
                value={phoneNumber}
                onChangeText={setPhoneNumber}
                keyboardType="phone-pad"
                autoComplete="tel"
              />
            ) : (
              <TextInput
                style={styles.input}
                placeholder="Enter email address"
                placeholderTextColor="#9E9E9E"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoComplete="email"
                autoCapitalize="none"
              />
            )}

            <TouchableOpacity
              style={[
                styles.button, 
                (authMethod === 'phone' ? !phoneNumber.trim() : !email.trim()) && styles.buttonDisabled,
                isLoading && styles.buttonDisabled
              ]}
              onPress={handleLogin}
              activeOpacity={0.8}
              disabled={isLoading}
            >
              <Text style={styles.buttonText}>
                {isLoading ? 'Please wait...' : 'Continue'}
              </Text>
            </TouchableOpacity>

            {DEV_MODE && authMethod === 'phone' && (
              <Text style={styles.devNote}>
                🔧 Dev Mode: OTP is 123456
              </Text>
            )}
          </View>
        </View>
      </KeyboardAvoidingView>
    </ScreenBackground>
  );
}

const styles = StyleSheet.create({
  keyboardAvoid: {
    flex: 1,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 32,
  },
  logo: {
    width: 100,
    height: 100,
    marginBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 10,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#E8F5E9',
    textAlign: 'center',
  },
  toggleContainer: {
    flexDirection: 'row',
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 12,
    padding: 4,
    marginBottom: 24,
    alignSelf: 'center',
  },
  toggleButton: {
    paddingVertical: 10,
    paddingHorizontal: 32,
    borderRadius: 10,
  },
  toggleActive: {
    backgroundColor: '#FFFFFF',
  },
  toggleText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '500',
  },
  toggleTextActive: {
    color: '#2E7D32',
  },
  form: {
    width: '100%',
    maxWidth: 400,
    alignSelf: 'center',
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 16,
    marginBottom: 16,
  },
  button: {
    backgroundColor: '#2E7D32',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  devNote: {
    color: '#FFE082',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 16,
  },
});
