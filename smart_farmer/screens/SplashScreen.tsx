import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { ScreenBackground } from '../components/ScreenBackground';
import { LoadingDots } from '../components/LoadingDots';
import { Logos, Backgrounds } from '../utils/assetsRegistry';

export default function SplashScreen() {
  return (
    <ScreenBackground source={Backgrounds.splash} statusBarStyle="light-content">
      <View style={styles.content}>
        <Image
          source={Logos.primary}
          style={styles.logo}
          resizeMode="contain"
        />
        <Text style={styles.title}>Smart Farmer</Text>
        <Text style={styles.subtitle}>Plant Disease Detection</Text>
        
        <View style={styles.loadingContainer}>
          <LoadingDots text="Loading" color="#FFFFFF" size={14} />
        </View>
      </View>
    </ScreenBackground>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  logo: {
    width: 120,
    height: 120,
    marginBottom: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#E8F5E9',
  },
  loadingContainer: {
    position: 'absolute',
    bottom: 60,
  },
});
