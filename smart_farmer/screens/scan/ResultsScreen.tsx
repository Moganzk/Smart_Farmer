import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { ScanStackParamList } from '../../navigation/ScanNavigator';
import { getScanById, ScanWithDiagnosis } from '../../db/scanService';
import { logger } from '../../utils/logger';

type ResultsScreenNavigationProp = StackNavigationProp<ScanStackParamList, 'Results'>;
type ResultsScreenRouteProp = RouteProp<ScanStackParamList, 'Results'>;

interface Props {
  navigation: ResultsScreenNavigationProp;
  route: ResultsScreenRouteProp;
}

export default function ResultsScreen({ navigation, route }: Props) {
  const { scanId } = route.params;
  const [result, setResult] = useState<ScanWithDiagnosis | null>(null);
  const [recommendations, setRecommendations] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadScanResult();
  }, [scanId]);

  const loadScanResult = async () => {
    try {
      if (scanId === 'error') {
        setResult(null);
        setLoading(false);
        return;
      }

      // Use the scan service to get scan with diagnosis
      const scan = getScanById(scanId);
      
      if (scan) {
        setResult(scan);
        // Parse recommendations JSON
        try {
          const recs = JSON.parse(scan.recommendations);
          setRecommendations(Array.isArray(recs) ? recs : [scan.recommendations]);
        } catch {
          setRecommendations([scan.recommendations]);
        }
        logger.info('Scan result loaded from SQLite', { scanId });
      }
    } catch (error) {
      logger.error('Failed to load scan result', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDone = () => {
    navigation.navigate('Scan');
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <Text style={styles.loadingText}>Loading results...</Text>
      </View>
    );
  }

  if (!result) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Failed to load results</Text>
        <TouchableOpacity style={styles.doneButton} onPress={handleDone}>
          <Text style={styles.doneButtonText}>Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Diagnosis Results</Text>
      </View>

      <View style={styles.content}>
        <View style={styles.resultCard}>
          <Text style={styles.resultTitle}>✅ Analysis Complete</Text>
          <Text style={styles.resultText}>Scan ID: {scanId}</Text>
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Disease Detected</Text>
          <Text style={styles.cardText}>{result.disease_name}</Text>
          {result.severity && (
            <Text style={styles.severityText}>Severity: {result.severity}</Text>
          )}
          <View style={styles.confidenceBar}>
            <View style={[styles.confidenceBarFill, { width: `${result.confidence * 100}%` }]} />
          </View>
          <Text style={styles.confidenceText}>Confidence: {Math.round(result.confidence * 100)}%</Text>
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Recommendations</Text>
          {recommendations.map((rec, index) => (
            <View key={index} style={styles.recommendationItem}>
              <Text style={styles.bulletPoint}>•</Text>
              <Text style={styles.cardText}>{rec}</Text>
            </View>
          ))}
        </View>

        <TouchableOpacity style={styles.doneButton} onPress={handleDone}>
          <Text style={styles.doneButtonText}>Done</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 100,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    textAlign: 'center',
    marginTop: 100,
  },
  header: {
    backgroundColor: '#4CAF50',
    padding: 20,
    paddingTop: 60,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFF',
  },
  content: {
    padding: 20,
  },
  resultCard: {
    backgroundColor: '#E8F5E9',
    borderRadius: 12,
    padding: 20,
    marginBottom: 20,
    borderWidth: 2,
    borderColor: '#4CAF50',
  },
  resultTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#2E7D32',
    marginBottom: 10,
  },
  resultText: {
    fontSize: 14,
    color: '#666',
  },
  card: {
    backgroundColor: '#FFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 10,
  },
  cardText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    flex: 1,
  },
  severityText: {
    fontSize: 14,
    color: '#FF9800',
    fontWeight: '600',
    marginTop: 5,
  },
  recommendationItem: {
    flexDirection: 'row',
    marginBottom: 8,
    alignItems: 'flex-start',
  },
  bulletPoint: {
    fontSize: 14,
    color: '#4CAF50',
    marginRight: 8,
    fontWeight: 'bold',
  },
  confidenceBar: {
    height: 8,
    backgroundColor: '#E0E0E0',
    borderRadius: 4,
    marginVertical: 10,
    overflow: 'hidden',
  },
  confidenceBarFill: {
    height: '100%',
    backgroundColor: '#4CAF50',
  },
  confidenceText: {
    fontSize: 12,
    color: '#666',
  },
  doneButton: {
    backgroundColor: '#4CAF50',
    borderRadius: 12,
    padding: 15,
    alignItems: 'center',
    marginTop: 10,
  },
  doneButtonText: {
    color: '#FFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
});
