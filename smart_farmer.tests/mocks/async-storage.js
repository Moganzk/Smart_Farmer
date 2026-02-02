// Mock for @react-native-async-storage/async-storage in tests
let mockStore = {};

const AsyncStorage = {
  getItem: jest.fn((key) => {
    return Promise.resolve(mockStore[key] || null);
  }),
  setItem: jest.fn((key, value) => {
    mockStore[key] = value;
    return Promise.resolve();
  }),
  removeItem: jest.fn((key) => {
    delete mockStore[key];
    return Promise.resolve();
  }),
  clear: jest.fn(() => {
    mockStore = {};
    return Promise.resolve();
  }),
  getAllKeys: jest.fn(() => {
    return Promise.resolve(Object.keys(mockStore));
  }),
  multiGet: jest.fn((keys) => {
    return Promise.resolve(keys.map((key) => [key, mockStore[key] || null]));
  }),
  multiSet: jest.fn((pairs) => {
    pairs.forEach(([key, value]) => {
      mockStore[key] = value;
    });
    return Promise.resolve();
  }),
  multiRemove: jest.fn((keys) => {
    keys.forEach((key) => {
      delete mockStore[key];
    });
    return Promise.resolve();
  }),
  // Helper to reset mock store between tests
  __resetStore: () => {
    mockStore = {};
  },
};

module.exports = AsyncStorage;
module.exports.default = AsyncStorage;
