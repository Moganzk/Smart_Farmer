import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import ScanScreen from '../screens/scan/ScanScreen';
import PreviewScreen from '../screens/scan/PreviewScreen';
import ProcessingScreen from '../screens/scan/ProcessingScreen';
import ResultsScreen from '../screens/scan/ResultsScreen';

export type ScanStackParamList = {
  Scan: undefined;
  Preview: { imageUri: string };
  Processing: { imageUri: string };
  Results: { scanId: string };
};

const Stack = createStackNavigator<ScanStackParamList>();

export default function ScanNavigator() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
      }}
    >
      <Stack.Screen name="Scan" component={ScanScreen} />
      <Stack.Screen name="Preview" component={PreviewScreen} />
      <Stack.Screen name="Processing" component={ProcessingScreen} />
      <Stack.Screen name="Results" component={ResultsScreen} />
    </Stack.Navigator>
  );
}
