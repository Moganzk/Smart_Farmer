import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, ImageBackground } from 'react-native';
import { Backgrounds } from '../../utils/assetsRegistry';
import { getDatabase } from '../../db/database';
import { logger } from '../../utils/logger';
import { useFocusEffect } from '@react-navigation/native';

interface Tip {
  local_id: string;
  title: string;
  content: string;
  category: string;
}

export default function TipsScreen() {
  const [tips, setTips] = useState<Tip[]>([]);
  const [loading, setLoading] = useState(true);

  useFocusEffect(
    React.useCallback(() => {
      loadTips();
    }, [])
  );

  const loadTips = async () => {
    try {
      setLoading(true);
      const db = await getDatabase();
      const rows = await db.getAllAsync<Tip>(
        'SELECT local_id, title, content, category FROM tips WHERE deleted_at IS NULL ORDER BY updated_at DESC LIMIT 20'
      );
      setTips(rows || []);
      logger.info('Tips loaded', { count: rows?.length || 0 });
    } catch (error) {
      logger.error('Failed to load tips', error);
    } finally {
      setLoading(false);
    }
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Text style={styles.emptyIcon}>💡</Text>
      <Text style={styles.emptyText}>No tips available</Text>
      <Text style={styles.emptySubtext}>Check back later for farming tips</Text>
    </View>
  );

  return (
    <ImageBackground
      source={Backgrounds.tips}
      style={styles.container}
      resizeMode="cover"
    >
      <View style={styles.header}>
        <Text style={styles.title}>Farming Tips</Text>
      </View>

      <FlatList
        data={tips}
        keyExtractor={(item) => item.local_id}
        renderItem={({ item }) => (
          <View style={styles.tipCard}>
            <Text style={styles.tipCategory}>{item.category}</Text>
            <Text style={styles.tipTitle}>{item.title}</Text>
            <Text style={styles.tipContent}>{item.content}</Text>
          </View>
        )}
        ListEmptyComponent={renderEmptyState}
        contentContainerStyle={tips.length === 0 ? styles.emptyContainer : styles.listContent}
        refreshing={loading}
        onRefresh={loadTips}
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
  listContent: {
    padding: 20,
  },
  tipCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  tipCategory: {
    fontSize: 12,
    fontWeight: '600',
    color: '#4CAF50',
    marginBottom: 5,
    textTransform: 'uppercase',
  },
  tipTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2E7D32',
    marginBottom: 10,
  },
  tipContent: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
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
