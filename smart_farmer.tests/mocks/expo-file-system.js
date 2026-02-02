// Mock for expo-file-system in tests

const documentDirectory = '/mock/document/directory/';
const cacheDirectory = '/mock/cache/directory/';

const FileSystem = {
  documentDirectory,
  cacheDirectory,
  
  // File info
  getInfoAsync: jest.fn((fileUri) => {
    return Promise.resolve({
      exists: true,
      isDirectory: false,
      uri: fileUri,
      size: 1024,
      modificationTime: Date.now(),
    });
  }),

  // Read/Write operations
  readAsStringAsync: jest.fn((fileUri, options) => {
    return Promise.resolve('mock file content');
  }),

  writeAsStringAsync: jest.fn((fileUri, contents, options) => {
    return Promise.resolve();
  }),

  // Directory operations
  makeDirectoryAsync: jest.fn((dirUri, options) => {
    return Promise.resolve();
  }),

  readDirectoryAsync: jest.fn((dirUri) => {
    return Promise.resolve([]);
  }),

  // Delete operations
  deleteAsync: jest.fn((fileUri, options) => {
    return Promise.resolve();
  }),

  // Copy/Move operations
  copyAsync: jest.fn((options) => {
    return Promise.resolve();
  }),

  moveAsync: jest.fn((options) => {
    return Promise.resolve();
  }),

  // Download
  downloadAsync: jest.fn((uri, fileUri, options) => {
    return Promise.resolve({
      uri: fileUri,
      status: 200,
      headers: {},
    });
  }),

  // Upload
  uploadAsync: jest.fn((url, fileUri, options) => {
    return Promise.resolve({
      status: 200,
      headers: {},
      body: '{}',
    });
  }),

  // Encoding types
  EncodingType: {
    UTF8: 'utf8',
    Base64: 'base64',
  },
};

module.exports = FileSystem;
module.exports.default = FileSystem;
