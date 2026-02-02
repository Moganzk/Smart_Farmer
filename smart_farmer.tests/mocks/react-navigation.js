// Mock for @react-navigation in tests
module.exports = {
  createStackNavigator: () => ({
    Navigator: 'Navigator',
    Screen: 'Screen',
  }),
  createBottomTabNavigator: () => ({
    Navigator: 'Navigator',
    Screen: 'Screen',
  }),
  NavigationContainer: 'NavigationContainer',
  useNavigation: () => ({}),
  useRoute: () => ({}),
};
