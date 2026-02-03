import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, ImageBackground, Alert, ActivityIndicator } from 'react-native';
import { Backgrounds, Icons } from '../../utils/assetsRegistry';
import { logger } from '../../utils/logger';
import { useAuth } from '../../contexts/AuthContext';
import { runPullOnce } from '../../db/pullSync';
import { runSync } from '../../db/syncWorker';
import { getDeviceId } from '../../utils/deviceId';

export default function SettingsScreen() {
  const { logout } = useAuth();
  const [isSyncing, setIsSyncing] = useState(false);

  const handleLogout = async () => {
    try {
      logger.info('User initiated logout');
      await logout();
    } catch (error) {
      logger.error('Logout failed', error);
    }
  };

  /**
   * DEV ONLY: Manual sync trigger
   * Long-press on "About" triggers full sync (push + pull)
   */
  const handleDevSync = async () => {
    if (!__DEV__) return;
    
    if (isSyncing) {
      Alert.alert('Sync in Progress', 'Please wait for current sync to complete.');
      return;
    }

    Alert.alert(
      'Dev Sync',
      'Trigger manual sync? (Push local changes, then pull server updates)',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Sync Now',
          onPress: async () => {
            setIsSyncing(true);
            try {
              logger.info('[DEV] Manual sync triggered');
              
              // Get device ID
              const deviceId = await getDeviceId();
              
              // 1. Push local changes to server
              logger.info('[DEV] Starting push sync...');
              const pushResult = await runSync();
              logger.info('[DEV] Push sync complete', pushResult);
              
              // 2. Pull server updates to local
              logger.info('[DEV] Starting pull sync...');
              const pullResult = await runPullOnce({ deviceId });
              logger.info('[DEV] Pull sync complete', pullResult);
              
              // Show results
              Alert.alert(
                'Sync Complete',
                `Push: ${pushResult.success ? 'Success' : 'Failed'}\n` +
                `Pull: ${pullResult.totalFetched} fetched, ${pullResult.totalInserted} inserted, ` +
                `${pullResult.totalUpdated} updated, ${pullResult.totalErrors} errors`
              );
            } catch (error) {
              logger.error('[DEV] Manual sync failed', error);
              Alert.alert('Sync Failed', error instanceof Error ? error.message : 'Unknown error');
            } finally {
              setIsSyncing(false);
            }
          },
        },
      ]
    );
  };

  return (
    <ImageBackground
      source={Backgrounds.settings}
      style={styles.container}
      resizeMode="cover"
    >
      <View style={styles.header}>
        <Text style={styles.title}>Settings</Text>
      </View>

      <ScrollView style={styles.content}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account</Text>
          
          <TouchableOpacity style={styles.menuItem}>
            <Text style={styles.menuText}>Profile</Text>
            <Text style={styles.menuArrow}>›</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.menuItem}>
            <Text style={styles.menuText}>Notifications</Text>
            <Text style={styles.menuArrow}>›</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>App</Text>
          
          <TouchableOpacity style={styles.menuItem}>
            <Text style={styles.menuText}>Language</Text>
            <Text style={styles.menuArrow}>›</Text>
          </TouchableOpacity>

          <TouchableOpacity 
            style={styles.menuItem}
            onLongPress={__DEV__ ? handleDevSync : undefined}
            delayLongPress={1000}
          >
            <View style={styles.menuItemContent}>
              <Text style={styles.menuText}>About</Text>
              {__DEV__ && isSyncing && (
                <ActivityIndicator size="small" color="#4CAF50" style={styles.syncIndicator} />
              )}
            </View>
            <Text style={styles.menuArrow}>›</Text>
          </TouchableOpacity>

          {/* DEV ONLY: Visible sync button for easier testing */}
          {__DEV__ && (
            <TouchableOpacity 
              style={[styles.menuItem, styles.devMenuItem]}
              onPress={handleDevSync}
              disabled={isSyncing}
            >
              <View style={styles.menuItemContent}>
                <Text style={[styles.menuText, styles.devMenuText]}>🔄 Dev: Manual Sync</Text>
                {isSyncing && (
                  <ActivityIndicator size="small" color="#FF9800" style={styles.syncIndicator} />
                )}
              </View>
              <Text style={styles.menuArrow}>›</Text>
            </TouchableOpacity>
          )}
        </View>

        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutText}>Logout</Text>
        </TouchableOpacity>
      </ScrollView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 20,
    paddingTop: 60,
    backgroundColor: 'rgba(76, 175, 80, 0.9)',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    marginBottom: 20,
    overflow: 'hidden',
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#666',
    padding: 15,
    paddingBottom: 10,
    backgroundColor: '#F5F5F5',
  },
  menuItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  menuItemContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  menuText: {
    fontSize: 16,
    color: '#333',
  },
  menuArrow: {
    fontSize: 24,
    color: '#999',
  },
  syncIndicator: {
    marginLeft: 10,
  },
  devMenuItem: {
    backgroundColor: '#FFF3E0',
  },
  devMenuText: {
    color: '#FF9800',
  },
  logoutButton: {
    backgroundColor: '#F44336',
    borderRadius: 12,
    padding: 15,
    alignItems: 'center',
    marginTop: 20,
  },
  logoutText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
});
