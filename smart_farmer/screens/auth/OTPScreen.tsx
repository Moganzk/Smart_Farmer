import React, { useState } from 'react';
import { View, Text, StyleSheet, ImageBackground, TextInput, TouchableOpacity, Alert } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { AuthStackParamList } from '../../navigation/AuthNavigator';
import { Backgrounds } from '../../utils/assetsRegistry';
import { logger } from '../../utils/logger';
import { useAuth } from '../../contexts/AuthContext';
import { supabase, isSupabaseConfigured } from '../../utils/supabase';

// Dev mode bypass - always true until Supabase is properly configured
const DEV_MODE = !isSupabaseConfigured || __DEV__ || true;
const DEV_OTP = '123456'; // Fixed OTP for development

type OTPScreenNavigationProp = StackNavigationProp<AuthStackParamList, 'OTP'>;
type OTPScreenRouteProp = RouteProp<AuthStackParamList, 'OTP'>;

interface Props {
  navigation: OTPScreenNavigationProp;
  route: OTPScreenRouteProp;
}

export default function OTPScreen({ navigation, route }: Props) {
  const [otp, setOtp] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const { phoneNumber, authMethod = 'phone' } = route.params;
  const { login } = useAuth();

  const handleVerify = async () => {
    if (otp.length !== 6) {
      logger.warn('OTP verification attempt with invalid length', { length: otp.length });
      Alert.alert('Invalid OTP', 'Please enter a 6-digit code');
      return;
    }

    setIsLoading(true);
    logger.info('OTP verification initiated', { phoneNumber, authMethod });

    if (DEV_MODE) {
      // Dev bypass: Accept fixed OTP "123456"
      if (otp === DEV_OTP) {
        logger.info('DEV MODE: OTP verified successfully');
        const userId = `user_${Date.now()}`;
        await login(phoneNumber, userId);
        navigation.navigate('ProfileSetup');
      } else {
        logger.warn('DEV MODE: Invalid OTP entered', { entered: otp, expected: DEV_OTP });
        Alert.alert('Invalid OTP', 'In dev mode, use OTP: 123456');
      }
    } else if (supabase) {
      // Production: Verify with Supabase
      try {
        const { data, error } = await supabase.auth.verifyOtp({
          phone: phoneNumber,
          token: otp,
          type: 'sms',
        });

        if (error) throw error;

        const userId = data.user?.id || `user_${Date.now()}`;
        await login(phoneNumber, userId);
        navigation.navigate('ProfileSetup');
        logger.info('OTP verified successfully', { userId });
      } catch (error: any) {
        logger.error('OTP verification failed', error);
        Alert.alert('Verification Failed', error.message || 'Invalid OTP. Please try again.');
      }
    } else {
      // Fallback if Supabase not configured
      Alert.alert('Configuration Error', 'Supabase not configured. Using dev mode.');
    }
    setIsLoading(false);
  };

  const handleResendOTP = async () => {
    if (DEV_MODE || !supabase) {
      Alert.alert('Dev Mode', 'OTP is always: 123456');
      return;
    }

    setIsLoading(true);
    try {
      const { error } = await supabase.auth.signInWithOtp({
        phone: phoneNumber,
      });
      if (error) throw error;
      Alert.alert('OTP Sent', 'A new OTP has been sent to your phone');
      logger.info('OTP resent successfully', { phoneNumber });
    } catch (error: any) {
      logger.error('Failed to resend OTP', error);
      Alert.alert('Error', error.message || 'Failed to resend OTP');
    }
    setIsLoading(false);
  };

  return (
    <ImageBackground
      source={Backgrounds.splash}
      style={styles.container}
      resizeMode="cover"
    >
      <View style={styles.content}>
        <Text style={styles.title}>Verify OTP</Text>
        <Text style={styles.subtitle}>
          Enter the 6-digit code sent to {phoneNumber}
        </Text>

        {DEV_MODE && (
          <View style={styles.devBanner}>
            <Text style={styles.devBannerText}>🔧 Dev Mode: Use OTP 123456</Text>
          </View>
        )}

        <View style={styles.form}>
          <TextInput
            style={styles.input}
            placeholder="Enter OTP"
            placeholderTextColor="#9E9E9E"
            value={otp}
            onChangeText={setOtp}
            keyboardType="number-pad"
            maxLength={6}
          />

          <TouchableOpacity
            style={[styles.button, isLoading && styles.buttonDisabled]}
            onPress={handleVerify}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>
              {isLoading ? 'Verifying...' : 'Verify'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity 
            style={styles.resendButton}
            onPress={handleResendOTP}
            disabled={isLoading}
          >
            <Text style={styles.resendText}>Resend OTP</Text>
          </TouchableOpacity>
        </View>
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#4CAF50',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
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
    marginBottom: 20,
    textAlign: 'center',
  },
  devBanner: {
    backgroundColor: 'rgba(255, 224, 130, 0.9)',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    marginBottom: 20,
  },
  devBannerText: {
    color: '#5D4037',
    fontSize: 14,
    fontWeight: '600',
  },
  form: {
    width: '100%',
    maxWidth: 400,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 15,
    fontSize: 24,
    marginBottom: 15,
    textAlign: 'center',
    letterSpacing: 10,
  },
  button: {
    backgroundColor: '#2E7D32',
    borderRadius: 8,
    padding: 15,
    alignItems: 'center',
    marginBottom: 15,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  resendButton: {
    padding: 10,
    alignItems: 'center',
  },
  resendText: {
    color: '#FFFFFF',
    fontSize: 14,
    textDecorationLine: 'underline',
  },
});
