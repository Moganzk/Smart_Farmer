// Mock for react-native-safe-area-context in tests
const React = require('react');

const SafeAreaView = ({ children, style }) => {
  return React.createElement('View', { style }, children);
};

const SafeAreaProvider = ({ children }) => {
  return React.createElement('View', null, children);
};

const useSafeAreaInsets = () => ({
  top: 0,
  bottom: 0,
  left: 0,
  right: 0,
});

const useSafeAreaFrame = () => ({
  x: 0,
  y: 0,
  width: 375,
  height: 812,
});

module.exports = {
  SafeAreaView,
  SafeAreaProvider,
  useSafeAreaInsets,
  useSafeAreaFrame,
};
