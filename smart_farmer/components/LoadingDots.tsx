/**
 * LoadingDots - Simple loading indicator with animated dots
 * 
 * Lightweight text-based loading indicator for splash/auth screens.
 * No heavy animation libraries required.
 */

import React, { useEffect, useState } from 'react';
import { Text, StyleSheet, View } from 'react-native';

interface LoadingDotsProps {
  /** Text to show before dots (default: 'Loading') */
  text?: string;
  /** Text color (default: white) */
  color?: string;
  /** Font size (default: 16) */
  size?: number;
}

export function LoadingDots({
  text = 'Loading',
  color = '#FFFFFF',
  size = 16,
}: LoadingDotsProps) {
  const [dots, setDots] = useState('');

  useEffect(() => {
    const interval = setInterval(() => {
      setDots((prev) => (prev.length >= 3 ? '' : prev + '.'));
    }, 500);

    return () => clearInterval(interval);
  }, []);

  return (
    <View style={styles.container}>
      <Text style={[styles.text, { color, fontSize: size }]}>
        {text}{dots}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    minWidth: 100,
    alignItems: 'center',
  },
  text: {
    fontWeight: '500',
  },
});

export default LoadingDots;
