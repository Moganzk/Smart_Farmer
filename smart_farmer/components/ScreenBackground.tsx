/**
 * ScreenBackground - Shared full-screen background wrapper
 * 
 * Uses ImageBackground with SafeAreaView for proper safe area handling.
 * All background images MUST come from the asset registry.
 * 
 * @example
 * import { ScreenBackground } from '../components/ScreenBackground';
 * import { Backgrounds } from '../utils/assetsRegistry';
 * 
 * <ScreenBackground source={Backgrounds.splash}>
 *   <YourContent />
 * </ScreenBackground>
 */

import React, { ReactNode } from 'react';
import {
  ImageBackground,
  StyleSheet,
  StatusBar,
  ImageSourcePropType,
  ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

interface ScreenBackgroundProps {
  /** Background image from asset registry (required) */
  source: ImageSourcePropType;
  /** Content to render over the background */
  children: ReactNode;
  /** Additional style for the content container */
  contentStyle?: ViewStyle;
  /** Status bar style (default: 'light-content') */
  statusBarStyle?: 'light-content' | 'dark-content';
  /** Fallback background color if image fails */
  fallbackColor?: string;
}

export function ScreenBackground({
  source,
  children,
  contentStyle,
  statusBarStyle = 'light-content',
  fallbackColor = '#4CAF50',
}: ScreenBackgroundProps) {
  return (
    <ImageBackground
      source={source}
      style={[styles.background, { backgroundColor: fallbackColor }]}
      resizeMode="cover"
    >
      <StatusBar
        barStyle={statusBarStyle}
        backgroundColor="transparent"
        translucent
      />
      <SafeAreaView style={[styles.container, contentStyle]}>
        {children}
      </SafeAreaView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  container: {
    flex: 1,
  },
});

export default ScreenBackground;
