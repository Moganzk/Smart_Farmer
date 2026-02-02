import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { ScanStackParamList } from '../../navigation/ScanNavigator';
import { logger } from '../../utils/logger';
import { performScan } from '../../db/scanService';
import { useAuth } from '../../contexts/AuthContext';

type ProcessingScreenNavigationProp = StackNavigationProp<ScanStackParamList, 'Processing'>;
type ProcessingScreenRouteProp = RouteProp<ScanStackParamList, 'Processing'>;

interface Props {
  navigation: ProcessingScreenNavigationProp;
  route: ProcessingScreenRouteProp;
}

export default function ProcessingScreen({ navigation, route }: Props) {
  const { imageUri } = route.params;
  const { user } = useAuth();
  const [status, setStatus] = useState('Analyzing image...');

  useEffect(() => {
    processImage();
  }, [imageUri]);

  const processImage = async () => {
    try {
      logger.info('Image processing started', { imageUri });
      
      // Simulate AI processing time (replace with actual ML model later)
      setStatus('Detecting diseases...');
      await new Promise(resolve => setTimeout(resolve, 1500));

      // Use the offline scan service to:
      // 1. Create scan record in SQLite
      // 2. Create diagnosis record with mock detection
      // No network calls - works in airplane mode
      setStatus('Saving results...');
      const scanLocalId = await performScan(
        user?.local_id || 'anonymous',
        imageUri,
        undefined // crop type - could be detected or selected
      );

      logger.info('Scan completed offline', { scanLocalId });
      navigation.replace('Results', { scanId: scanLocalId });
    } catch (error) {
      logger.error('Failed to process image', error);
      navigation.replace('Results', { scanId: 'error' });
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <ActivityIndicator size="large" color="#4CAF50" />
        <Text style={styles.title}>Analyzing Image</Text>
        <Text style={styles.subtitle}>{status}</Text>
        <Text style={styles.offlineNote}>Works offline ✓</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 20,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginTop: 10,
    textAlign: 'center',
  },
  offlineNote: {
    fontSize: 12,
    color: '#4CAF50',
    marginTop: 20,
    fontStyle: 'italic',
  },
});
