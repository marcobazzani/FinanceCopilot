const appVersion = '0.2.6';
const appCommit = String.fromEnvironment('COMMIT_SHA', defaultValue: 'dev');
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');
