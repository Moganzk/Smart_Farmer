// Mock for expo-camera in tests
const React = require('react');

// Mock CameraType enum
const CameraType = {
  front: 'front',
  back: 'back',
};

// Mock CameraView component
const CameraView = React.forwardRef((props, ref) => {
  return React.createElement('View', { ...props, ref, testID: 'mock-camera-view' }, props.children);
});
CameraView.displayName = 'CameraView';

// Mock useCameraPermissions hook
const useCameraPermissions = () => {
  const permission = {
    granted: true,
    canAskAgain: true,
    status: 'granted',
  };
  const requestPermission = jest.fn(() => Promise.resolve(permission));
  return [permission, requestPermission];
};

// Mock Camera class (legacy)
const Camera = React.forwardRef((props, ref) => {
  return React.createElement('View', { ...props, ref, testID: 'mock-camera' }, props.children);
});
Camera.displayName = 'Camera';
Camera.Constants = {
  Type: CameraType,
  FlashMode: { on: 'on', off: 'off', auto: 'auto' },
};
Camera.requestCameraPermissionsAsync = jest.fn(() => Promise.resolve({ status: 'granted' }));

module.exports = {
  CameraView,
  CameraType,
  useCameraPermissions,
  Camera,
  // Legacy exports
  Constants: Camera.Constants,
  requestCameraPermissionsAsync: Camera.requestCameraPermissionsAsync,
};
