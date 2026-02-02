// Mock for react-native in tests
module.exports = {
  View: 'View',
  Text: 'Text',
  Image: 'Image',
  TouchableOpacity: 'TouchableOpacity',
  TextInput: 'TextInput',
  ScrollView: 'ScrollView',
  FlatList: 'FlatList',
  ImageBackground: 'ImageBackground',
  ActivityIndicator: 'ActivityIndicator',
  StyleSheet: {
    create: (styles) => styles,
    absoluteFillObject: {},
  },
  Platform: {
    OS: 'ios',
    select: (obj) => obj.ios || obj.default,
  },
};
