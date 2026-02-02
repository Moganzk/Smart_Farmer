import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Image, View, TouchableOpacity, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { Icons } from '../utils/assetsRegistry';
import { Badge } from '../components/Badge';
import HomeScreen from '../screens/main/HomeScreen';
import HistoryScreen from '../screens/main/HistoryScreen';
import TipsScreen from '../screens/main/TipsScreen';
import SettingsScreen from '../screens/main/SettingsScreen';
import { RootStackParamList } from './RootNavigator';

// Mocked unread notification count (will be replaced with real data later)
const MOCK_UNREAD_COUNT = 3;

export type MainTabParamList = {
  Home: undefined;
  History: undefined;
  Scan: undefined;
  Tips: undefined;
  More: undefined;
};

const Tab = createBottomTabNavigator<MainTabParamList>();

// Placeholder for Scan tab (navigates to Scan stack)
function ScanPlaceholder() {
  return null;
}

// Custom tab bar button for the center Scan action
function ScanTabButton({ onPress }: { onPress?: () => void }) {
  const navigation = useNavigation<StackNavigationProp<RootStackParamList>>();
  
  const handlePress = () => {
    navigation.navigate('Scan');
  };

  return (
    <TouchableOpacity
      style={styles.scanButton}
      onPress={handlePress}
      activeOpacity={0.8}
    >
      <View style={styles.scanButtonInner}>
        <Image
          source={Icons.scan}
          style={styles.scanIcon}
          resizeMode="contain"
        />
      </View>
    </TouchableOpacity>
  );
}

// Notification icon with badge for Home header
function NotificationIcon() {
  return (
    <TouchableOpacity style={styles.notificationButton}>
      <Image
        source={Icons.notification}
        style={styles.notificationIcon}
      />
      <Badge count={MOCK_UNREAD_COUNT} />
    </TouchableOpacity>
  );
}

export default function MainNavigator() {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: '#4CAF50',
        tabBarInactiveTintColor: '#9E9E9E',
        tabBarStyle: styles.tabBar,
        tabBarLabelStyle: styles.tabBarLabel,
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{
          headerShown: true,
          headerTitle: 'Smart Farmer',
          headerStyle: styles.header,
          headerTitleStyle: styles.headerTitle,
          headerRight: () => <NotificationIcon />,
          tabBarIcon: ({ color, size }) => (
            <Image
              source={Icons.home}
              style={{ width: size, height: size, tintColor: color }}
            />
          ),
        }}
      />
      <Tab.Screen
        name="History"
        component={HistoryScreen}
        options={{
          headerShown: false,
          tabBarIcon: ({ color, size }) => (
            <Image
              source={Icons.history}
              style={{ width: size, height: size, tintColor: color }}
            />
          ),
        }}
      />
      <Tab.Screen
        name="Scan"
        component={ScanPlaceholder}
        options={{
          tabBarButton: (props) => <ScanTabButton {...props} />,
          tabBarLabel: () => null,
        }}
      />
      <Tab.Screen
        name="Tips"
        component={TipsScreen}
        options={{
          headerShown: false,
          tabBarIcon: ({ color, size }) => (
            <Image
              source={Icons.tips}
              style={{ width: size, height: size, tintColor: color }}
            />
          ),
        }}
      />
      <Tab.Screen
        name="More"
        component={SettingsScreen}
        options={{
          headerShown: false,
          tabBarIcon: ({ color, size }) => (
            <Image
              source={Icons.more}
              style={{ width: size, height: size, tintColor: color }}
            />
          ),
        }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    height: 60,
    paddingBottom: 8,
    paddingTop: 8,
    backgroundColor: '#FFFFFF',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  tabBarLabel: {
    fontSize: 11,
    fontWeight: '500',
  },
  header: {
    backgroundColor: '#4CAF50',
  },
  headerTitle: {
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  scanButton: {
    top: -20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  scanButtonInner: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#4CAF50',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 8,
  },
  scanIcon: {
    width: 28,
    height: 28,
    tintColor: '#FFFFFF',
  },
  notificationButton: {
    marginRight: 16,
    padding: 4,
  },
  notificationIcon: {
    width: 24,
    height: 24,
    tintColor: '#FFFFFF',
  },
});
