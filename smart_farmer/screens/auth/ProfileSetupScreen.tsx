import React, { useState } from 'react';
import { View, Text, StyleSheet, ImageBackground, TextInput, TouchableOpacity } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthStackParamList } from '../../navigation/AuthNavigator';
import { Backgrounds } from '../../utils/assetsRegistry';
import { logger } from '../../utils/logger';
import { useAuth } from '../../contexts/AuthContext';
import { getDatabase } from '../../db/database';
import { getDeviceId } from '../../utils/deviceId';

type ProfileSetupScreenNavigationProp = StackNavigationProp<AuthStackParamList, 'ProfileSetup'>;

interface Props {
  navigation: ProfileSetupScreenNavigationProp;
}

export default function ProfileSetupScreen({ navigation }: Props) {
  const [name, setName] = useState('');
  const [location, setLocation] = useState('');
  const { updateUser, user } = useAuth();

  const handleComplete = async () => {
    if (!name.trim() || !location.trim()) {
      logger.warn('Profile setup attempt with incomplete data');
      return;
    }

    try {
      logger.info('Profile setup initiated', { name, location });
      
      const db = await getDatabase();
      const deviceId = await getDeviceId();
      const localId = `user_${Date.now()}`;
      const now = new Date().toISOString();

      // Save to SQLite
      await db.runAsync(
        `INSERT INTO users (local_id, phone, name, location, device_id, sync_status, updated_at)
         VALUES (?, ?, ?, ?, ?, 'pending', ?)`,
        [localId, user?.phone || '', name, location, deviceId, now]
      );

      // Update auth context
      await updateUser({ id: localId, name, location, phone: user?.phone || '' });
      
      logger.info('Profile saved to SQLite', { localId });
    } catch (error) {
      logger.error('Failed to save profile', error);
    }
  };

  return (
    <ImageBackground
      source={Backgrounds.splash}
      style={styles.container}
      resizeMode="cover"
    >
      <View style={styles.content}>
        <Text style={styles.title}>Complete Your Profile</Text>
        <Text style={styles.subtitle}>Help us personalize your experience</Text>

        <View style={styles.form}>
          <TextInput
            style={styles.input}
            placeholder="Your name"
            placeholderTextColor="#9E9E9E"
            value={name}
            onChangeText={setName}
          />

          <TextInput
            style={styles.input}
            placeholder="Farm location"
            placeholderTextColor="#9E9E9E"
            value={location}
            onChangeText={setLocation}
          />

          <TouchableOpacity
            style={styles.button}
            onPress={handleComplete}
          >
            <Text style={styles.buttonText}>Get Started</Text>
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
    marginBottom: 40,
    textAlign: 'center',
  },
  form: {
    width: '100%',
    maxWidth: 400,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 15,
    fontSize: 16,
    marginBottom: 15,
  },
  button: {
    backgroundColor: '#2E7D32',
    borderRadius: 8,
    padding: 15,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
});
