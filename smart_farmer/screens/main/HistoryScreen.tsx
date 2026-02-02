import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, ImageBackground, TouchableOpacity } from 'react-native';
import { Backgrounds } from '../../utils/assetsRegistry';
import { getScanHistory, ScanWithDiagnosis } from '../../db/scanService';
import { logger } from '../../utils/logger';
import { useAuth } from '../../contexts/AuthContext';
import { useFocusEffect } from '@react-navigation/native';

export default function HistoryScreen() {
  const [scans, setScans] = useState<ScanWithDiagnosis[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  // Reload history every time screen comes into focus
  // This ensures new scans appear immediately without manual refresh
  useFocusEffect(
    React.useCallback(() => {
      loadHistory();
    }, [user?.local_id])
  );

  const loadHistory = () => {
    try {
      setLoading(true);
      // Use scan service to get scans with joined diagnoses
      // Reads directly from SQLite - works offline
      const rows = getScanHistory(user?.local_id || 'anonymous', 50);
      setScans(rows);
      logger.info('Scan history loaded from SQLite', { count: rows.length });
    } catch (error) {
      logger.error('Failed to load scan history', error);
      setScans([]);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (isoString: string): string => {
    const date = new Date(isoString);
    return date.toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getConfidenceColor = (confidence: number): string => {
    if (confidence >= 0.8) return '#4CAF50'; // High - green
    if (confidence >= 0.5) return '#FF9800'; // Medium - orange
    return '#F44336'; // Low - red
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Text style={styles.emptyIcon}>📋</Text>
      <Text style={styles.emptyText}>No scan history yet</Text>
      <Text style={styles.emptySubtext}>Start scanning plants to see your history</Text>
    </View>
  );

  const renderHistoryItem = ({ item }: { item: ScanWithDiagnosis }) => (
    <TouchableOpacity style={styles.historyItem}>
      <View style={styles.historyContent}>
        <View style={styles.historyHeader}>
          <Text style={styles.historyDisease}>{item.disease_name}</Text>
          {item.severity && (
            <View style={[styles.severityBadge, 
              item.severity === 'high' && styles.severityHigh,
              item.severity === 'medium' && styles.severityMedium,
              item.severity === 'low' && styles.severityLow,
            ]}>
              <Text style={styles.severityText}>{item.severity}</Text>
            </View>
          )}
        </View>
        {item.crop_type && (
          <Text style={styles.cropType}>🌱 {item.crop_type}</Text>
        )}
        <View style={styles.confidenceRow}>
          <View style={styles.confidenceBarBackground}>
            <View 
              style={[
                styles.confidenceBarFill, 
                { 
                  width: `${item.confidence * 100}%`,
                  backgroundColor: getConfidenceColor(item.confidence),
                }
              ]} 
            />
          </View>
          <Text style={[styles.confidenceText, { color: getConfidenceColor(item.confidence) }]}>
            {Math.round(item.confidence * 100)}%
          </Text>
        </View>
        <Text style={styles.historyDate}>{formatDate(item.scanned_at)}</Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <ImageBackground
      source={Backgrounds.history}
      style={styles.container}
      resizeMode="cover"
    >
      <View style={styles.header}>
        <Text style={styles.title}>Scan History</Text>
        <Text style={styles.subtitle}>
          {scans.length} {scans.length === 1 ? 'scan' : 'scans'} • Offline data
        </Text>
      </View>

      <FlatList
        data={scans}
        keyExtractor={(item) => item.local_id}
        renderItem={renderHistoryItem}
        ListEmptyComponent={renderEmptyState}
        contentContainerStyle={scans.length === 0 ? styles.emptyContainer : styles.listContent}
        refreshing={loading}
        onRefresh={loadHistory}
      />
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
  subtitle: {
    fontSize: 14,
    color: 'rgba(255, 255, 255, 0.8)',
    marginTop: 5,
  },
  listContent: {
    padding: 20,
  },
  historyItem: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 15,
    marginBottom: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  historyContent: {
    flex: 1,
  },
  historyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 5,
  },
  historyDisease: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    flex: 1,
  },
  severityBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
    marginLeft: 8,
  },
  severityHigh: {
    backgroundColor: '#FFEBEE',
  },
  severityMedium: {
    backgroundColor: '#FFF3E0',
  },
  severityLow: {
    backgroundColor: '#E8F5E9',
  },
  severityText: {
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'capitalize',
    color: '#666',
  },
  cropType: {
    fontSize: 13,
    color: '#666',
    marginBottom: 8,
  },
  confidenceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  confidenceBarBackground: {
    flex: 1,
    height: 6,
    backgroundColor: '#E0E0E0',
    borderRadius: 3,
    marginRight: 10,
    overflow: 'hidden',
  },
  confidenceBarFill: {
    height: '100%',
    borderRadius: 3,
  },
  confidenceText: {
    fontSize: 14,
    fontWeight: '600',
    width: 45,
    textAlign: 'right',
  },
  historyDate: {
    fontSize: 12,
    color: '#999',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyState: {
    alignItems: 'center',
    padding: 40,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 20,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 10,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
});
